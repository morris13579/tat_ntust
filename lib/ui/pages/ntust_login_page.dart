import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

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
  InAppWebViewController webView;
  Uri url = Uri();
  double progress = 0;
  final Uri NTUST_LOGIN_URL = Uri.parse(
      "https://stuinfosys.ntust.edu.tw/NTUSTSSOServ/SSO/Login/CourseSelection");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(R.current.login + "..."),
      ),
      body: SafeArea(
        child: Container(
          child: Column(
            children: <Widget>[
              Container(
                child: progress < 1.0
                    ? LinearProgressIndicator(value: progress)
                    : Container(),
              ),
              Expanded(
                child: Container(
                  child: InAppWebView(
                    initialUrlRequest: URLRequest(url: NTUST_LOGIN_URL),
                    initialOptions: InAppWebViewGroupOptions(
                      crossPlatform: InAppWebViewOptions(),
                    ),
                    onWebViewCreated: (InAppWebViewController controller) {
                      webView = controller;
                      //Get.back(result: true);
                    },
                    onLoadStart: (InAppWebViewController controller, Uri url) {
                      setState(() {
                        this.url = url;
                      });
                    },
                    onLoadStop:
                        (InAppWebViewController controller, Uri url) async {
                      if (url == NTUST_LOGIN_URL) {
                        await webView.evaluateJavascript(
                            source:
                                'document.getElementsByName("UserName")[0].value = "${widget.username}";');
                        await webView.evaluateJavascript(
                            source:
                                'document.getElementsByName("Password")[0].value = "${widget.password}";');
                        await webView.evaluateJavascript(
                            source:
                                'document.getElementById("btnLogIn").click();');
                      } else {
                        var cookies = await cookieManager.getCookies(
                            url: NTUST_LOGIN_URL);
                        List<io.Cookie> ioCookies = [];
                        for (var i in cookies) {
                          if (i.name == ".ASPXAUTH" ||
                              i.name == "ntustjwtsecret" ||
                              i.name == "ntustsecret") {
                            io.Cookie k = io.Cookie(i.name, i.value);
                            k.domain = ".ntust.edu.tw";
                            k.path = "/";
                            ioCookies.add(k);
                          }
                        }
                        await cookieJar.deleteAll();
                        await cookieJar.saveFromResponse(
                            NTUST_LOGIN_URL, ioCookies);
                        Get.back(result: true);
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
