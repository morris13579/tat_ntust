import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/connector/ntust_connector.dart';
import 'package:flutter_app/ui/other/my_progress_dialog.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:html/parser.dart';

class LoginNTUSTPage extends StatefulWidget {
  final String username;
  final String password;

  LoginNTUSTPage({this.username, this.password});

  @override
  _LoginNTUSTPageState createState() => _LoginNTUSTPageState();
}

class _LoginNTUSTPageState extends State<LoginNTUSTPage> {
  final cookieManager = CookieManager.instance();
  final cookieJar = DioConnector.instance.cookiesManager;
  final Uri NTUSTLoginUri = Uri.parse(NTUSTConnector.ntustLoginUrl);
  InAppWebViewController webView;
  Uri url = Uri();
  double progress = 0;
  bool showDialog = true;
  Widget dialog;

  @override
  void initState() {
    dialog = MyProgressDialog.dialog(R.current.loginNTUST);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(R.current.login + "..."),
      ),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            InAppWebView(
              initialUrlRequest: URLRequest(url: NTUSTLoginUri),
              initialOptions: InAppWebViewGroupOptions(
                crossPlatform: InAppWebViewOptions(),
              ),
              onWebViewCreated: (InAppWebViewController controller) {
                webView = controller;
              },
              onLoadStart: (InAppWebViewController controller, Uri url) {
                setState(() {
                  this.url = url;
                });
              },
              onLoadStop: (InAppWebViewController controller, Uri url) async {
                print(url);
                if (url == NTUSTLoginUri) {
                  await webView.evaluateJavascript(
                      source:
                          'document.getElementsByName("UserName")[0].value = "${widget.username}";');
                  await webView.evaluateJavascript(
                      source:
                          'document.getElementsByName("Password")[0].value = "${widget.password}";');
                  await webView.evaluateJavascript(
                      source: 'document.getElementById("btnLogIn").click();');
                  Future.delayed(Duration(seconds: 5)).then((value) {
                    setState(() {
                      showDialog = false;
                    });
                    MyToast.show(R.current.needValidateCaptcha);
                  });
                } else {
                  try {
                    await cookieJar.deleteAll();
                  } catch (e) {}
                  String result = await webView.getHtml();
                  var tagNode = parse(result);
                  var nodes = tagNode
                      .getElementsByClassName("validation-summary-errors");
                  if (nodes.length == 1) {
                    Get.back(result: {
                      "status": NTUSTLoginStatus.Fail,
                      "message": nodes[0].text.replaceAll("\n", "")
                    });
                  } else {
                    var cookies =
                        await cookieManager.getCookies(url: NTUSTLoginUri);
                    List<io.Cookie> ioCookies = [];
                    bool add = false;
                    for (var i in cookies) {
                      io.Cookie k = io.Cookie(i.name, i.value);
                      k.domain = ".ntust.edu.tw";
                      k.path = "/";
                      ioCookies.add(k);
                      add = true;
                    }
                    if (add) {
                      await cookieJar.saveFromResponse(
                          NTUSTLoginUri, ioCookies);
                      Get.back(result: {"status": NTUSTLoginStatus.Success});
                    } else {
                      Get.back(result: {"status": NTUSTLoginStatus.Fail});
                    }
                  }
                }
              },
              onProgressChanged:
                  (InAppWebViewController controller, int progress) {
                setState(
                  () {
                    this.progress = progress / 100;
                  },
                );
              },
            ),
            if (showDialog) dialog
          ],
        ),
      ),
    );
  }
}
