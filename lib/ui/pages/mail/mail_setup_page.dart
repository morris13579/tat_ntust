import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/connector/mail_connector.dart';
import 'package:flutter_app/src/repository/mail_repository.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 第一次使用信箱：說明加輸入密碼。
///
/// **它是分頁的第一層，不是跳出來的表單。** 點進信箱那一格、還沒設定過的時候
/// 整格就是這一頁，所以沒有返回鍵、導覽列照樣在。設定完成後同一格換成信件
/// 清單，導覽列不動。
///
/// 順序是「先講能做什麼、最後才是欄位」：只講代價不講回報，使用者第一次看到
/// 會直接切走。
///
/// 副標只留一句「這一頁做完之後會怎樣」。先前那裡還接了一句「信箱有自己的
/// 密碼，不是登入 TAT 那組」——維護者看過實機後決定拿掉：那是在解釋系統的
/// 內部狀況，不是使用者在這一步需要知道的事。密碼打錯時 mailPasswordRejected
/// 會講。
///
/// 標題與副標的語氣跟著 App 其他說明走（`notificationEmptyHint`
/// 「…都會出現在這裡。」那種中性直述），不要寫成對話。
///
/// **存之前先驗。** 舊的對話框只檢查非空就存，使用者要等到下一次收信失敗才
/// 知道打錯。這裡拿去做一次真的 IMAP `LOGIN`，過了才寫進安全儲存區。
class MailSetupPage extends StatefulWidget {
  const MailSetupPage({super.key, required this.onDone});

  /// 密碼驗過並存好了。呼叫端負責換成信件清單。
  final VoidCallback onDone;

  @override
  State<StatefulWidget> createState() => _MailSetupPageState();
}

class _MailSetupPageState extends State<MailSetupPage> {
  final _password = TextEditingController();
  final _focus = FocusNode();
  bool _obscured = true;
  bool _verifying = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    // 主鈕在密碼是空的時候停用，所以每一個字都要重畫一次。
    _password.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() => setState(() {});

  @override
  void dispose() {
    _password.removeListener(_onPasswordChanged);
    // TextEditingController 會一路持有使用者剛剛輸入的信箱明文密碼，頁面關掉
    // 之後若不 dispose，它會跟著 State 一起留在記憶體裡；FocusNode 沒 dispose
    // 也會留在 focus tree 上並持續發通知。
    _password.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _password.text;
    // 空密碼由停用主鈕擋掉，不另外給一句錯誤——那句話會和欄位的提示字一字
    // 不差，等於同一件事在同一個畫面上說兩次。
    if (password.isEmpty) return;

    setState(() {
      _verifying = true;
      _error = '';
    });

    final outcome = await MailRepository.instance
        .verifyPassword(Model.instance.getAccount(), password);
    if (!mounted) return;

    switch (outcome) {
      case MailAuthOutcome.ok:
        Model.instance.setMailPassword(password);
        await Model.instance.saveUserData();
        if (!mounted) return;
        setState(() => _verifying = false);
        widget.onDone();
      // 密碼錯與連不上要分開講：前者留在這裡重打，後者重打幾次都一樣。
      case MailAuthOutcome.rejected:
        setState(() {
          _verifying = false;
          _error = R.current.mailPasswordRejected;
        });
      case MailAuthOutcome.unreachable:
        setState(() {
          _verifying = false;
          _error = R.current.mailPasswordUnreachable;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final text = context.text;
    return Scaffold(
      appBar: mainAppbar(title: R.current.mailTab),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            // 和登入頁同一顆、同一個尺寸與圓角。這一頁做的事跟那一頁一樣
            // ——填一組帳密把某個東西接起來——所以它該長得像它的同類。
            _logo(),
            const SizedBox(height: 24),
            Text(
              R.current.mailSetupTitle,
              style: text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                  color: scheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              R.current.mailSetupDesc,
              style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            // 三行都對應實際做得到的事，不寫做不到的。
            _benefit(LucideIcons.reply, R.current.mailSetupBenefitRead),
            _benefit(LucideIcons.search, R.current.mailSetupBenefitSearch),
            _benefit(
                LucideIcons.download, R.current.mailSetupBenefitAttachment),
            const SizedBox(height: 24),
            _fields(),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  _error,
                  style: text.bodySmall?.copyWith(color: scheme.error),
                ),
              ),
            ],
            const SizedBox(height: 14),
            _privacy(),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _verifying || _password.text.isEmpty
                  ? null
                  : () => unawaited(_submit()),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(TatTokens.heightButton),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(TatTokens.radiusButton),
                ),
              ),
              child: Text(R.current.mailLogin),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logo() => Align(
        alignment: Alignment.centerLeft,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(TatTokens.radiusDialog),
          child: Image.asset('assets/launcher/ios-icon.png',
              width: 64, height: 64, fit: BoxFit.cover),
        ),
      );

  Widget _benefit(IconData icon, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Icon(icon, size: 18, color: context.scheme.primary),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                label,
                style: context.text.bodyLarge
                    ?.copyWith(color: context.scheme.onSurface, height: 1.45),
              ),
            ),
          ],
        ),
      );

  /// 帳號與密碼一張卡兩列，標籤在左——和寫信頁的欄位群組同一個排法，不是
  /// 「填色框浮在灰底上」那種三層容器。
  ///
  /// 帳號帶入、不給編輯：學號從個人資料來，使用者能填的只有密碼；少一個欄位
  /// 就少一個出錯點，也少一次「我的信箱位址到底是哪個」的猶豫。
  Widget _fields() {
    final scheme = context.scheme;
    return Material(
      color: context.tokens.card,
      borderRadius: BorderRadius.circular(TatTokens.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _row(
            label: R.current.account,
            child: Text(
              MailConnector.accountToAddress(Model.instance.getAccount()),
              style: context.text.bodyLarge?.copyWith(color: scheme.onSurface),
            ),
          ),
          Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          _row(
            label: R.current.password,
            child: TextField(
              controller: _password,
              focusNode: _focus,
              obscureText: _obscured,
              enabled: !_verifying,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => unawaited(_submit()),
              style: context.text.bodyLarge,
              // 主題的 inputTheme 預設是填色圓角框，這裡在卡片裡面，關掉它
              // 才不會變成框中框。
              decoration: InputDecoration(
                filled: false,
                // **六個 border 都要關掉，不是只有 `border`。** 主題的
                // `inputTheme` 給的是 1.5px 的 `OutlineInputBorder`，而
                // `InputDecorator` 是依狀態挑 `enabledBorder` / `focusedBorder`
                // 的，只覆寫 `border` 的話那幾個仍是主題的描邊框；外框會替內容
                // 讓出水平內距，密碼的字因此比上面帳號那一列往右 4dp。
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isCollapsed: true,
                constraints: const BoxConstraints(),
                // 高度由 _row 給，欄位自己不要再撐——那正是兩列不等高的成因。
                contentPadding: EdgeInsets.zero,
                hintText: R.current.passwordNull,
                // 提示字沿用欄位本身的字級：主題的 hintStyle 是 bodyMedium，
                // 比 bodyLarge 小一號，沒填字時看起來會和帳號那一列不同大小。
                hintStyle: context.text.bodyLarge
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            // 純圖示按鈕沒有 tooltip 的話，螢幕閱讀器只唸得出「按鈕」。
            // 釘成 44x44（觸控下限）並清掉預設的 padding 與 constraints，
            // 否則 IconButton 預設的 48 會把這一列撐得比帳號那一列高。
            trailing: SizedBox(
              width: TatTokens.heightButton,
              height: TatTokens.heightButton,
              child: IconButton(
                tooltip:
                    _obscured ? R.current.showPassword : R.current.hidePassword,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(_obscured ? LucideIcons.eye : LucideIcons.eyeOff,
                    size: 20, color: scheme.onSurfaceVariant),
                onPressed: () => setState(() => _obscured = !_obscured),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 兩列共用的高度。帳號那一列是一段文字、密碼那一列是輸入框加一顆眼睛，
  /// 內容本來就不一樣高——高度交給這裡釘死，兩列才會一樣。
  static const double _rowHeight = 56;

  Widget _row({
    required String label,
    required Widget child,
    Widget? trailing,
  }) =>
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _rowHeight),
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 6, trailing == null ? 14 : 6, 6),
          child: Row(
            children: [
              SizedBox(
                // 和寫信頁的欄位群組同一個寬度，兩頁的標籤欄才對得齊。
                width: 68,
                child: Text(
                  label,
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.scheme.onSurfaceVariant),
                ),
              ),
              Expanded(child: child),
              if (trailing != null) trailing,
            ],
          ),
        ),
      );

  /// 隱私那一句逐字沿用登入頁的 `login_hint`。同一句話出現兩次比換句話說
  /// 更可信。
  Widget _privacy() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.shieldCheck,
              size: 16, color: context.scheme.onSurfaceVariant),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              R.current.login_hint,
              style: context.text.bodySmall
                  ?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
          ),
        ],
      );
}
