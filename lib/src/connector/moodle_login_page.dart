
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/entity/moodle_token_entity.dart';
import 'package:flutter_app/src/util/web_view_utils.dart';
import 'package:flutter_app/ui/other/my_progress_dialog.dart';
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
  final WebUri moodleLoginUri = WebUri(MoodleWebApiConnector.moodleLoginUrl);
  final String loginPageUri = "https://ssoam2.ntust.edu.tw/account/login";
  late InAppWebViewController webView;
  double progress = 0;
  Widget dialog = MyProgressDialog.dialog(R.current.loginMoodle);


  @override
  void initState() {
    super.initState();
  }

  Future<void> moodleTokenCallback(InAppWebViewController controller, WebUri? url) async {
    if(url.toString().startsWith("moodlemobile://") && url?.host.startsWith("token=") == true) {
      final base64Token = url?.rawValue.split("token=")[1] ?? "";
      final decodeToken = utf8.decode(base64Url.decode(base64Token)).split(":::");
      Get.back(result: MoodleTokenEntity(
          decodeToken[0],
          decodeToken[1],
          decodeToken.length == 3 ? decodeToken[2] : ""
      ));
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
              initialUrlRequest: URLRequest(url: moodleLoginUri),
              onWebViewCreated: (InAppWebViewController controller) {
                webView = controller;
              },
              onLoadStart: (InAppWebViewController controller, WebUri? url) async {
                await moodleTokenCallback(controller, url);
              },
              onReceivedError: (InAppWebViewController controller, request, error) async {
                await moodleTokenCallback(controller, request.url);
              },
              onLoadStop: (InAppWebViewController controller, WebUri? url) async {
                if (url.toString().startsWith(loginPageUri)) {
                  if(await controller.waitForElement(condition: 'document.getElementById("Username") != null')) {
                    await controller.evaluateJavascript(source: 'document.getElementById("Username").value = "${widget.username}";');
                    await controller.evaluateJavascript(source: 'document.getElementById("Password").value = "${widget.password}";');
                  }

                  // 等待 Cloudflare Turnstile 驗證
                  if(await controller.waitForElement(condition: 'document.querySelector(\'[name="cf-turnstile-response"]\') != null && document.querySelector(\'[name="cf-turnstile-response"]\').value !== ""')) {
                    await controller.evaluateJavascript(source: 'document.getElementById("loginButton").click();');
                  }
                }

                await moodleTokenCallback(controller, url);
              },
              onProgressChanged:
                  (InAppWebViewController controller, int progress) {
                setState(() {
                  this.progress = progress / 100;
                });
              },
            ),

            dialog
          ],
        ),
      ),
    );
  }
}
