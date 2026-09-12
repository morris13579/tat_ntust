import 'package:flutter/material.dart';
import 'package:flutter_app/src/controller/mail/mail_watch_controller.dart';
import 'package:flutter_app/src/repository/mail_repository.dart';
import 'package:flutter_app/ui/pages/mail/mail_list_page.dart';
import 'package:flutter_app/ui/pages/mail/mail_setup_page.dart';

/// 信箱那一格導覽列的內容。
///
/// 還沒設定過信箱密碼時整格就是說明加輸入頁（[MailSetupPage]），不是先畫一個
/// 空的清單再彈對話框上來——那個做法要嘛在 `initState` 裡同步開對話框（會撞上
/// navigator 的 `_debugLocked`），要嘛讓使用者先看到一個什麼都沒有的畫面。
class MailPage extends StatefulWidget {
  const MailPage({super.key});

  @override
  State<StatefulWidget> createState() => _MailPageState();
}

class _MailPageState extends State<MailPage> {
  late bool _configured = MailRepository.instance.hasMailPassword;

  @override
  Widget build(BuildContext context) =>
      _configured ? const MailListPage() : MailSetupPage(onDone: _onConfigured);

  /// 剛設定完密碼。**這裡要自己啟動盯信**：MainScreen 在 App 啟動時叫過一次
  /// start()，但那時候還沒有密碼、它直接收工了；不補這一下，要等 App 進背景
  /// 再回前景才會開始盯。
  void _onConfigured() {
    setState(() => _configured = true);
    MailWatchController.instance.start();
  }
}
