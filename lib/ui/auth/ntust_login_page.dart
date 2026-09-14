import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/interactive_login_flow.dart';
import 'package:flutter_app/src/service/interactive_login_gateway.dart';
import 'package:flutter_app/src/service/web_view_session.dart';
import 'package:flutter_app/ui/components/page/loading_page.dart';
import 'package:flutter_app/ui/components/toast/tat_toast.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

/// 可見的 ssoam2 登入頁。流程在 [NtustLoginFlow]，原生版用的是同一份。
class LoginNTUSTPage extends StatefulWidget {
  final String username;
  final String password;

  const LoginNTUSTPage({
    required this.username,
    required this.password,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _LoginNTUSTPageState();
}

class _LoginNTUSTPageState extends State<LoginNTUSTPage> {
  late final _flow =
      NtustLoginFlow(account: widget.username, password: widget.password);
  bool showDialog = true;
  // getter：欄位初始化式只跑一次，會把進度框的文字凍在 State 建立時的語言。
  Widget get dialog =>
      LoadingPage(isLoading: true, message: R.current.loginNTUST);

  Future<void> _onLoadStop(
      InAppWebViewController controller, WebUri? url) async {
    final step = await _flow.onLoadStop(
        InAppWebViewDriver(controller), url?.toString());
    if (!mounted) return;
    switch (step) {
      case LoginContinue():
        break;
      case LoginNeedsHuman():
        setState(() => showDialog = false);
        TatToast.show(R.current.needValidateCaptcha, kind: TatToastKind.info);
      case LoginFinished(:final result):
        Get.back<NtustInteractiveLoginResult>(result: result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${R.current.login}..."),
      ),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            InAppWebView(
              initialUrlRequest:
                  URLRequest(url: WebUri(NtustLoginFlow.startUrl)),
              onLoadStop: _onLoadStop,
            ),
            if (showDialog) dialog
          ],
        ),
      ),
    );
  }
}
