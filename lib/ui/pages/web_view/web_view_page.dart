import 'dart:async';
import 'dart:io';

import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/util/open_utils.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewPage extends StatefulWidget {
  late final String url;
  final String title;
  final bool openWithExternalWebView;
  final Function(Uri)? onWebViewDownload;

  WebViewPage(
      {required this.title,
      required Uri url,
      this.openWithExternalWebView = false,
      this.onWebViewDownload}) {
    this.url = url.toString();
  }

  @override
  _WebViewPageState createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  final cookieManager = CookieManager();
  final cookieJar = DioConnector.instance.cookiesManager;
  WebViewController? webView;
  String url = "";
  String? lastLoadUri;
  double progress = 0;
  int onLoadStopTime = -1;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) WebView.platform = AndroidWebView();
    BackButtonInterceptor.add(myInterceptor);
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(myInterceptor);
    super.dispose();
  }

  bool myInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    if (onLoadStopTime >= 1) {
      webView!.goBack();
      onLoadStopTime -= 2;
      return true;
    }
    return false;
  }

  Future<bool> setCookies() async {
    var uri = Uri.parse(widget.url);
    final cookies = await cookieJar.loadForRequest(uri);
    await cookieManager.clearCookies();
    for (var cookie in cookies) {
      await cookieManager.setCookie(WebViewCookie(
          name: cookie.name,
          value: cookie.value,
          domain: cookie.domain!,
          path: cookie.path!));
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          Container(
            width: 50,
            child: InkWell(
              onTap: () async {
                if (webView != null) {
                  await webView!.goBack();
                }
              },
              child: Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          Container(
            width: 50,
            child: InkWell(
              onTap: () async {
                if (webView != null) {
                  await webView!.goForward();
                }
              },
              child: Icon(Icons.arrow_forward, color: Colors.white),
            ),
          ),
          Container(
            width: 50,
            child: InkWell(
              onTap: () async {
                if (webView != null) {
                  await webView!.reload();
                }
              },
              child: Icon(Icons.refresh, color: Colors.white),
            ),
          ),
          if (widget.openWithExternalWebView)
            Container(
              width: 50,
              child: InkWell(
                onTap: () async {
                  OpenUtils.launchURL(this.url.toString());
                },
                child: Icon(Icons.open_in_new, color: Colors.white),
              ),
            ),
        ],
      ),
      body: FutureBuilder<bool>(
        future: setCookies(),
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          if (snapshot.hasData) {
            return SafeArea(
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
                        child: WebView(
                          javascriptMode: JavascriptMode.unrestricted,
                          initialUrl: widget.url.toString(),
                          onWebViewCreated:
                              (WebViewController webViewController) {
                            webView = webViewController;
                          },
                          onPageFinished: (String url) {
                            setState(() {
                              if (lastLoadUri != url) {
                                onLoadStopTime++;
                              }
                              lastLoadUri = url;
                              this.url = url;
                            });
                          },
                          onProgress: (int progress) {
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
            );
          } else {
            return Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
    );
  }
}
