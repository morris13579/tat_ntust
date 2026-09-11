import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/service/ssoam2_login.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_token_entity.dart';
import 'package:flutter_app/ui/components/page/loading_page.dart';
import 'package:flutter_app/ui/components/toast/tat_toast.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

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
  final _launch = MoodleWebApiConnector.buildLoginLaunch();
  late final WebUri moodleLoginUri = WebUri(_launch.url);
  bool showDialog = true;
  // getter：欄位初始化式只跑一次，會把進度框的文字凍在 State 建立時的語言。
  Widget get dialog =>
      LoadingPage(isLoading: true, message: R.current.loginMoodle);

  /// 這個頁面只能結束一次：同一次登入可能觸發兩次回呼，第二個 `Get.back`
  /// pop 掉的會是這一頁底下那一頁。
  bool _finished = false;

  /// 送出次數上限，見 onLoadStop。
  int _submits = 0;
  static const int _maxSubmits = 2;

  void _finish(MoodleTokenEntity? result) {
    if (_finished) return;
    _finished = true;
    Get.back(result: result);
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
              initialUrlRequest: URLRequest(url: moodleLoginUri),
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final uri = navigationAction.request.url;
                if (uri != null && uri.scheme == "moodlemobile") {
                  // parseMoodleToken 不能拋例外：從 shouldOverrideUrlLoading
                  // 逸出的例外沒有人接住，頁面與進度框會永遠卡在畫面上。
                  _finish(parseMoodleToken(uri.rawValue,
                      passport: _launch.passport));
                  return NavigationActionPolicy.CANCEL;
                }

                return NavigationActionPolicy.ALLOW;
              },
              onLoadStop:
                  (InAppWebViewController controller, WebUri? url) async {
                if (_finished) return;
                if (Ssoam2Login.isLoginPage(url)) {
                  // 先問有沒有錯誤再決定要不要送出：密碼錯時站台是把登入頁
                  // 連同錯誤訊息重新吐回來，網址仍是登入頁，先送出就會變成
                  // 拿同一組錯帳密無限重送。
                  final error = await Ssoam2Login.credentialError(controller);
                  if (error != null) {
                    TatToast.show(error, kind: TatToastKind.info);
                    _finish(null);
                    return;
                  }
                  // 認不出錯誤時的第二道保險：最多送出兩次。
                  if (_submits >= _maxSubmits) {
                    if (mounted) setState(() => showDialog = false);
                    TatToast.show(R.current.needValidateCaptcha,
                        kind: TatToastKind.info);
                    return;
                  }
                  _submits++;
                  final outcome = await Ssoam2Login.submit(
                    controller,
                    account: widget.username,
                    password: widget.password,
                  );
                  // 找不到表單與 Turnstile 逾時在畫面上是同一件事：收起進度框
                  // 讓使用者自己操作。分成兩個 outcome 值是給 headless 路徑用的
                  // ——只有 turnstileTimeout 值得升級成可見頁面。
                  if (outcome != Ssoam2LoginOutcome.submitted) {
                    setState(() {
                      showDialog = false;
                    });
                    TatToast.show(R.current.needValidateCaptcha,
                        kind: TatToastKind.info);
                  }
                }
              },
            ),
            Visibility(visible: showDialog, child: dialog)
          ],
        ),
      ),
    );
  }
}

/// 解析 `moodlemobile://token=<base64>` 的回傳。失敗一律回 null，不拋例外。
///
/// base64 解開之後是 `signature:::token:::privatetoken`。要用 base64.normalize
/// 補 padding，Dart 的解碼器少了 padding 會丟 FormatException。
///
/// **signature 不相符一律拒收（fail-closed）。** 伺服器算的是
/// `md5($CFG->wwwroot . $passport)`（純字串相接、沒有分隔符，見
/// `admin/tool/mobile/launch.php`）；驗證它才能確定 token 來自我們剛發出的
/// 那一次 launch，而不是別人塞進來的。
///
/// 學校若改了 wwwroot（換網域、加路徑、或前面擺了改寫 scheme 的反向代理），
/// 這裡會開始擋掉**合法的** token，症狀是登入頁一直重來。先看 log 裡的
/// `signature mismatch`，用裡面的值反推站台實際的 wwwroot，再更新
/// [MoodleWebApiConnector.host]——不要把這道檢查關掉。
MoodleTokenEntity? parseMoodleToken(String rawUrl, {String? passport}) {
  try {
    final marker = rawUrl.indexOf("token=");
    if (marker < 0) return null;
    final encoded = rawUrl.substring(marker + "token=".length);
    if (encoded.isEmpty) return null;

    final decoded = utf8.decode(base64.decode(base64.normalize(encoded)));
    final parts = decoded.split(":::");
    if (parts.length < 2 || parts[1].isEmpty) return null;

    if (passport != null &&
        !MoodleWebApiConnector.verifyLoginSignature(parts[0], passport)) {
      Log.e("moodle login signature mismatch: got ${parts[0]}");
      return null;
    }

    return MoodleTokenEntity(
      parts[0],
      parts[1],
      parts.length >= 3 ? parts[2] : "",
    );
  } catch (e, stack) {
    Log.eWithStack("moodle token parse failed: $e", stack);
    return null;
  }
}
