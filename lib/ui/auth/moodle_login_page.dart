import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/interactive_login_flow.dart';
import 'package:flutter_app/src/model/moodle_token_entity.dart';
import 'package:flutter_app/src/service/web_view_session.dart';
import 'package:flutter_app/ui/components/page/loading_page.dart';
import 'package:flutter_app/ui/components/toast/tat_toast.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

/// 可見的 Moodle 登入頁。流程在 [MoodleLoginFlow]，原生版用的是同一份。
class LoginMoodlePage extends StatefulWidget {
  final String username;
  final String password;

  const LoginMoodlePage({
    required this.username,
    required this.password,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _LoginMoodlePageState();
}

class _LoginMoodlePageState extends State<LoginMoodlePage> {
  late final _flow =
      MoodleLoginFlow(account: widget.username, password: widget.password);
  bool showDialog = true;
  // getter：欄位初始化式只跑一次，會把進度框的文字凍在 State 建立時的語言。
  Widget get dialog =>
      LoadingPage(isLoading: true, message: R.current.loginMoodle);

  void _apply(LoginStep<MoodleTokenEntity?> step) {
    if (!mounted) return;
    switch (step) {
      case LoginContinue():
        break;
      case LoginNeedsHuman():
        setState(() => showDialog = false);
        TatToast.show(R.current.needValidateCaptcha, kind: TatToastKind.info);
      case LoginFinished(:final result, :final notice):
        if (notice != null) TatToast.show(notice, kind: TatToastKind.info);
        Get.back<MoodleTokenEntity>(result: result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${R.current.loginMoodle}..."),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_flow.startUrl)),
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final uri = navigationAction.request.url;
                if (uri == null ||
                    uri.scheme != MoodleLoginFlow.callbackScheme) {
                  return NavigationActionPolicy.ALLOW;
                }
                _apply(_flow.onCallback(uri.rawValue));
                return NavigationActionPolicy.CANCEL;
              },
              onLoadStop: (controller, url) async => _apply(await _flow
                  .onLoadStop(InAppWebViewDriver(controller), url?.toString())),
            ),
            Visibility(visible: showDialog, child: dialog)
          ],
        ),
      ),
    );
  }
}
