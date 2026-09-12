import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/model/mail/mail_contact.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 收件者欄。位址變成一顆一顆可以按掉的籤，不是一串自己打逗號的字。
///
/// **為什麼不沿用純文字欄**：先前要使用者自己在位址之間打逗號，漏打就整串被
/// 當成一個位址寄不出去，而且打錯一個字要把整串讀過一遍才找得到。分成籤之後
/// 錯的那一顆自己會變紅，刪掉也只要按一下。
///
/// **還在打的那一截留在 [controller] 裡**，不會自動變成籤。打到逗號、分號、
/// 按送出、或焦點離開才收成一顆——空白不算，手機鍵盤的自動完成很愛在字尾補
/// 一個空白，那樣會把還沒打完的位址切斷。
///
/// 建議清單畫在欄位底下而不是浮在上面：這一頁整個是可捲動的，浮層要自己算位置
/// 還得跟著鍵盤與捲動一起動，畫在原地就沒有那些問題。
/// 欄位列的排版常數。**主旨那一列也要照這一組排**——先前收件者用
/// `CrossAxisAlignment.start` 加固定偏移、主旨用預設的置中，同一張卡裡兩套
/// 排法，四個標籤的基線就對不齊，看起來整片是歪的。
const double kMailFieldLabelWidth = 68;
const double kMailFieldLabelGap = 10;
const double kMailFieldPadH = 14;
const double kMailFieldPadV = 6;
const double kMailFieldInputPadV = 8;

/// 內容欄的左緣。建議清單要對齊到這裡，不要另外寫死一個數字。
const double kMailFieldContentLeft =
    kMailFieldPadH + kMailFieldLabelWidth + kMailFieldLabelGap;

/// 標籤的樣式。字級比內容小一階，但**行高跟著內容欄走**——同一個字型下行高
/// 一樣，基線就落在同一條線上，不必去算 ascent 差多少。
TextStyle? mailFieldLabelStyle(BuildContext context) {
  final label = context.text.bodyMedium;
  final input = context.text.bodyLarge;
  if (label == null) return null;
  final line = (input?.fontSize ?? 15) * (input?.height ?? 1);
  return label.copyWith(
    color: context.scheme.onSurfaceVariant,
    height: line / (label.fontSize ?? 14),
  );
}

class MailRecipientField extends StatefulWidget {
  const MailRecipientField({
    super.key,
    required this.label,
    required this.controller,
    required this.addresses,
    required this.onChanged,
    required this.isValid,
    this.focusNode,
    this.enabled = true,
    this.trailing,
    this.suggest,
  });

  final String label;

  /// 還在打的那一截。和舊版同一個 controller，所以「有沒有草稿」的判斷照舊。
  final TextEditingController controller;

  /// 已經收成籤的位址。
  final List<String> addresses;

  final ValueChanged<List<String>> onChanged;

  /// 哪些位址畫成正常的籤、哪些畫成紅的。驗證規則在寫信頁，這裡只負責畫。
  final bool Function(String address) isValid;

  final FocusNode? focusNode;
  final bool enabled;

  /// 「副本」那顆文字鈕。
  final Widget? trailing;

  /// 自動完成的來源。null 就不顯示建議。
  final Future<List<MailContact>> Function(String query)? suggest;

  @override
  State<MailRecipientField> createState() => _MailRecipientFieldState();
}

class _MailRecipientFieldState extends State<MailRecipientField> {
  /// 輸入框最小寬度。
  ///
  /// **不要調回 120。** 一顆 NTUST 位址的籤就有兩百多寬，配 120 的下限會超過
  /// 一列的寬度，游標被擠到下一行，整列變成兩倍高——那是「歪掉」的一部分。
  static const double _minInputWidth = 48;

  /// 打完字等多久才去查建議。查的是本機 SQLite，但每一鍵都查會讓快速輸入時
  /// 建議清單一直跳。
  static const Duration _debounce = Duration(milliseconds: 180);

  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  bool _ownsFocus = false;
  Timer? _suggestTimer;
  List<MailContact> _suggestions = const [];

  /// 這一次查建議對應的關鍵字。回來的時候若使用者已經打了別的字就丟掉，
  /// 避免慢的那一趟蓋掉快的那一趟。
  String _suggestQuery = '';

  @override
  void initState() {
    super.initState();
    _ownsFocus = widget.focusNode == null;
    widget.controller.addListener(_onTextChanged);
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _suggestTimer?.cancel();
    widget.controller.removeListener(_onTextChanged);
    _focus.removeListener(_onFocusChanged);
    if (_ownsFocus) _focus.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    // 離開欄位時把還在打的那一截收成籤。不收的話使用者會看到自己打的位址
    // 還在框裡，卻不知道按寄出時它算不算。
    if (!_focus.hasFocus) {
      _commit(widget.controller.text);
      if (mounted) setState(() => _suggestions = const []);
    }
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    // 分隔符一出現就收一顆。吃掉分隔符本身，不要留在下一顆的開頭。
    final cut = text.indexOf(RegExp(r'[,;\n]'));
    if (cut >= 0) {
      final head = text.substring(0, cut);
      final tail = text.substring(cut + 1);
      widget.controller.value = TextEditingValue(
        text: tail,
        selection: TextSelection.collapsed(offset: tail.length),
      );
      _commit(head);
      return;
    }
    // 量出來的寬度要跟著打的字走，不然框停在下限寬度、字在裡面橫捲。
    if (mounted) setState(() {});
    _scheduleSuggest(text);
  }

  void _scheduleSuggest(String query) {
    final suggest = widget.suggest;
    _suggestTimer?.cancel();
    if (suggest == null || query.trim().isEmpty) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = const []);
      return;
    }
    _suggestQuery = query;
    _suggestTimer = Timer(_debounce, () async {
      final hits = await suggest(query);
      if (!mounted || _suggestQuery != query) return;
      // 已經收成籤的人不要再建議一次。
      final taken = widget.addresses.map((a) => a.toLowerCase()).toSet();
      setState(() => _suggestions =
          hits.where((c) => !taken.contains(c.email.toLowerCase())).toList());
    });
  }

  /// 把一段字收成籤。重複的位址不再加一次——同一個人寄兩份的結果是伺服器退信。
  void _commit(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return;
    final exists =
        widget.addresses.any((a) => a.toLowerCase() == value.toLowerCase());
    widget.controller.clear();
    _suggestTimer?.cancel();
    if (mounted) setState(() => _suggestions = const []);
    if (exists) return;
    widget.onChanged([...widget.addresses, value]);
  }

  void _remove(int index) {
    final next = [...widget.addresses]..removeAt(index);
    widget.onChanged(next);
  }

  /// 空的輸入框按退格 → 把最後一顆籤拿掉。沒有這一條的話刪掉打錯的那一顆
  /// 要先瞄準一個 16 寬的小叉。
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.backspace) {
      return KeyEventResult.ignored;
    }
    if (widget.controller.text.isNotEmpty || widget.addresses.isEmpty) {
      return KeyEventResult.ignored;
    }
    _remove(widget.addresses.length - 1);
    return KeyEventResult.handled;
  }

  /// 輸入框要多寬。`TextField` 放進 `Wrap` 會直接吃掉整個 maxWidth，所以
  /// 自己量一次目前的字有多寬，讓游標可以停在最後一顆籤的右邊。
  double _inputWidth(double available) {
    if (available <= 0) return 0;
    final painter = TextPainter(
      text:
          TextSpan(text: widget.controller.text, style: context.text.bodyLarge),
      textDirection: Directionality.of(context),
    )..layout();
    // 下限也要跟著可用寬度收：`clamp` 的下限大於上限會直接擲例外。
    final low = math.min(_minInputWidth, available);
    return (painter.width + 24).clamp(low, available);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // **右緣一律 14。** 先前有「副本」鈕的那一列收成 6，收件者的籤就比
          // 副本、密件副本兩列早三十幾 px 折行，四列看起來參差不齊。
          padding: const EdgeInsets.fromLTRB(
              kMailFieldPadH, kMailFieldPadV, kMailFieldPadH, kMailFieldPadV),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 和輸入框的 contentPadding 同一個數字；行高已經在
              // [mailFieldLabelStyle] 對齊過，這裡不必再補基線差。
              Padding(
                padding: const EdgeInsets.only(top: kMailFieldInputPadV),
                child: SizedBox(
                  width: kMailFieldLabelWidth,
                  child: Text(
                    widget.label,
                    style: mailFieldLabelStyle(context),
                  ),
                ),
              ),
              const SizedBox(width: kMailFieldLabelGap),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, area) => GestureDetector(
                    // 點空白處也要進得去，不用瞄準那一小截輸入框。
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.enabled ? _focus.requestFocus : null,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (var i = 0; i < widget.addresses.length; i++)
                          _chip(widget.addresses[i], i),
                        SizedBox(
                          width: _inputWidth(area.maxWidth),
                          child: _input(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.trailing != null)
                // 對齊輸入框那一格的中線。先前是 `top: 2`，在
                // `CrossAxisAlignment.start` 底下讓那顆鈕比欄位裡的字高了十
                // 幾 px——那是最顯眼的一處歪。
                SizedBox(
                  height: _inputRowHeight(context),
                  child: Center(widthFactor: 1, child: widget.trailing),
                ),
            ],
          ),
        ),
        if (_suggestions.isNotEmpty) _suggestionList(),
      ],
    );
  }

  /// 輸入框那一格的高度：一行內容加上下的 contentPadding。
  static double _inputRowHeight(BuildContext context) {
    final input = context.text.bodyLarge;
    return (input?.fontSize ?? 15) * (input?.height ?? 1) +
        kMailFieldInputPadV * 2;
  }

  Widget _input() => Focus(
        onKeyEvent: _onKey,
        child: TextField(
          controller: widget.controller,
          focusNode: _focus,
          enabled: widget.enabled,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          // 位址不該被自動大寫，`Prof@` 和 `prof@` 看起來就像兩個人。
          textCapitalization: TextCapitalization.none,
          textInputAction: TextInputAction.next,
          onSubmitted: _commit,
          style: context.text.bodyLarge,
          decoration: const InputDecoration(
            filled: false,
            border: InputBorder.none,
            isDense: true,
            constraints: BoxConstraints(),
            contentPadding: EdgeInsets.symmetric(vertical: kMailFieldInputPadV),
          ),
        ),
      );

  Widget _chip(String address, int index) {
    final ok = widget.isValid(address);
    final scheme = context.scheme;
    // 格式不對的那一顆當場變紅，不用等按了寄出才知道。
    final background =
        ok ? scheme.surfaceContainerHighest : scheme.errorContainer;
    final foreground = ok ? scheme.onSurface : scheme.onErrorContainer;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(TatTokens.radiusButton),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 5, 4, 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              // 長位址截斷，但不要窄到只剩兩個字。
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(color: foreground),
              ),
            ),
            const SizedBox(width: 2),
            Semantics(
              button: true,
              label: '${R.current.remove} $address',
              child: InkWell(
                onTap: widget.enabled ? () => _remove(index) : null,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Icon(LucideIcons.x, size: 14, color: foreground),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionList() => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          children: [
            for (final c in _suggestions)
              InkWell(
                onTap: () => _commit(c.email),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      kMailFieldContentLeft, 8, kMailFieldPadH, 8),
                  child: Row(
                    children: [
                      Icon(LucideIcons.user,
                          size: 16, color: context.scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          c.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}

/// 收件者欄吃逗號與分號分隔。空白項直接丟掉，讓「a@b.c, 」不會變成一個空位址。
///
/// 住在這裡而不是寫信頁：籤化之後貼上一整串位址也要走同一套切法。
List<String> parseMailAddresses(String raw) => raw
    .split(RegExp(r'[,;\s]+'))
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();

/// 只擋明顯不是位址的輸入。**不做嚴格的 RFC 5322 驗證**：那個文法允許的東西
/// 遠比任何正規表達式寫得出來的多，擋過頭會讓合法位址寄不出去。
bool looksLikeMailAddress(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
