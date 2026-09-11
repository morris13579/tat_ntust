import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/service/cookie_bridge.dart';
import 'package:flutter_app/src/service/ssoam2_login.dart';
import 'package:flutter_app/src/enum/ntust_login_status.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/connector/ntust_connector.dart';
import 'package:flutter_app/ui/components/page/loading_page.dart';
import 'package:flutter_app/ui/components/toast/tat_toast.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

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
  final cookieManager = CookieManager.instance();
  final cookieJar = DioConnector.instance.cookiesManager;
  final WebUri ntustLoginUri = WebUri(NTUSTConnector.ntustLoginUrl);
  late InAppWebViewController webView;
  bool showDialog = true;
  // getter：欄位初始化式只跑一次，會把進度框的文字凍在 State 建立時的語言。
  Widget get dialog =>
      LoadingPage(isLoading: true, message: R.current.loginNTUST);

  /// 這個頁面只能結束一次。
  ///
  /// onLoadStop 每次載入完成都會觸發，登入成功後的 client-side 導向會讓它在
  /// 同一次登入裡再觸發一遍；不擋住的話第二個 Get.back 會把這頁**底下那一頁**
  /// 也 pop 掉。
  bool _finished = false;

  /// 送出次數上限，見 onLoadStop。
  int _submits = 0;
  static const int _maxSubmits = 2;

  void _finish(Map<String, dynamic> result) {
    if (_finished) return;
    _finished = true;
    Get.back(result: result);
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
              initialUrlRequest: URLRequest(url: ntustLoginUri),
              onWebViewCreated: (InAppWebViewController controller) {
                webView = controller;
              },
              onLoadStop: (InAppWebViewController controller, Uri? url) async {
                if (_finished) return;
                // 錯誤檢查在最前面，而且不分網址：登入失敗後站台是把登入頁
                // 連同錯誤訊息重新吐回來，網址仍是登入頁，放在 else 分支裡
                // 就永遠讀不到，而且會拿同一組錯帳密一直重送。
                final error = await Ssoam2Login.credentialError(webView);
                if (error != null) {
                  _finish({
                    "status": NTUSTLoginStatus.fail,
                    "message": error.replaceAll("\n", ""),
                  });
                  return;
                }

                if (url == ntustLoginUri) {
                  // 認不出錯誤時的第二道保險，理由同 LoginMoodlePage。
                  if (_submits >= _maxSubmits) {
                    if (mounted) {
                      setState(() => showDialog = false);
                      TatToast.show(R.current.needValidateCaptcha,
                          kind: TatToastKind.info);
                    }
                    return;
                  }
                  _submits++;
                  await webView.evaluateJavascript(
                      source:
                          'document.getElementsByName("UserName")[0].value = ${jsonEncode(widget.username)};');
                  await webView.evaluateJavascript(
                      source:
                          'document.getElementsByName("Username")[0].value = ${jsonEncode(widget.username)};');
                  await webView.evaluateJavascript(
                      source:
                          'document.getElementsByName("Password")[0].value = ${jsonEncode(widget.password)};');
                  await webView.evaluateJavascript(
                      source: 'document.getElementById("btnLogIn").click();');
                  await webView.evaluateJavascript(
                      source:
                          'document.getElementById("loginButton").click();');
                  await Future.delayed(const Duration(seconds: 5));
                  if (mounted) {
                    setState(() {
                      showDialog = false;
                    });
                    TatToast.show(R.current.needValidateCaptcha,
                        kind: TatToastKind.info);
                  }
                } else {
                  // 這裡不可以先清 Dio jar：清空由 CookieBridge 在寫入前做，
                  // 且只有真的拿到 cookie 才清，否則登入失敗會把還能用的舊
                  // session 一起清掉，變成完全登出。
                  //
                  // 錯誤判斷已在最上面做完，這裡只剩「離開登入頁＝成功」。
                  // 不要在這裡自己再 parse 一次判準：比對不到就會掉進鏡射
                  // 分支，而 cookie 一定搬得到幾顆，變成密碼錯卻回報成功。
                  //
                  // 鏡射邏輯只有 CookieBridge 一份，headless 路徑共用。
                  final moved = await CookieBridge.mirrorToDio(
                    url: ntustLoginUri,
                    jar: cookieJar,
                    manager: cookieManager,
                  );
                  _finish({
                    "status": moved > 0
                        ? NTUSTLoginStatus.success
                        : NTUSTLoginStatus.fail
                  });
                }
              },
            ),
            if (showDialog) dialog
          ],
        ),
      ),
    );
  }
}
