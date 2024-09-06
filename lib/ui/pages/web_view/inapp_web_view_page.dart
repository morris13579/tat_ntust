import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/connector/ntust_connector.dart';
import 'package:flutter_app/src/file/file_download.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/open_utils.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

class InAppWebViewPage extends StatefulWidget {
  final WebUri url;
  final String title;
  final bool openWithExternalWebView;
  final Function(Uri)? onWebViewDownload;
  final Function(InAppWebViewController) loadDone;

  const InAppWebViewPage({
    required this.title,
    required this.url,
    this.openWithExternalWebView = false,
    this.onWebViewDownload,
    required this.loadDone,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _InAppWebViewPageState();
}

class _InAppWebViewPageState extends State<InAppWebViewPage> {
  final cookieManager = CookieManager.instance();
  final cookieJar = DioConnector.instance.cookiesManager;
  InAppWebViewController? webView;
  Uri url = Uri();
  double progress = 0;
  int onLoadStopTime = -1;
  Uri? lastLoadUri;
  final String ntustLoginUri = "https://ssoam.ntust.edu.tw/nidp/app/login";
  final String moodleLoginUri = "https://moodle2.ntust.edu.tw/login";

  @override
  void initState() {
    super.initState();
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

  bool firstLoad = true;

  Future<bool> setCookies() async {
    if (!firstLoad) return true;
    firstLoad = false;
    final cookies = await cookieJar.loadForRequest(widget.url);
    await cookieManager.deleteAllCookies();
    var existCookies = await cookieManager.getCookies(url: widget.url);
    final cookiesName = existCookies.map((e) => e.name).toList();
    for (var cookie in cookies) {
      if (!cookiesName.contains(cookie.name)) {
        cookiesName.add(cookie.name);
        await cookieManager.setCookie(
          url: widget.url,
          name: cookie.name,
          value: cookie.value,
          domain: cookie.domain,
          path: cookie.path ?? "/",
          maxAge: cookie.maxAge,
          isSecure: cookie.secure,
          isHttpOnly: cookie.httpOnly,
        );
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: baseAppbar(title: widget.title, action: actionList),
      body: FutureBuilder<bool>(
        future: setCookies(),
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          if (snapshot.hasData) {
            return SafeArea(
              child: Column(
                children: <Widget>[
                  Container(
                    child: progress < 1.0
                        ? LinearProgressIndicator(value: progress)
                        : Container(),
                  ),
                  Expanded(
                    child: InAppWebView(
                      initialUrlRequest: URLRequest(url: widget.url),
                      initialSettings: InAppWebViewSettings(
                          useHybridComposition: true, useOnDownloadStart: true),
                      onWebViewCreated: (InAppWebViewController controller) {
                        webView = controller;
                      },
                      onLoadStart:
                          (InAppWebViewController controller, Uri? url) {
                        setState(() {
                          if (lastLoadUri != url) {
                            onLoadStopTime++;
                          }
                          lastLoadUri = url;
                          this.url = url!;
                        });
                      },
                      onLoadStop:
                          (InAppWebViewController controller, Uri? url) async {
                        if (url?.toString().startsWith(ntustLoginUri) == true) {
                          await controller.evaluateJavascript(
                              source:
                                  'document.getElementsByName("Ecom_User_ID")[0].value = "${Model.instance.getAccount()}";');
                          await controller.evaluateJavascript(
                              source:
                                  'document.getElementsByName("Ecom_Password")[0].value = "${Model.instance.getPassword()}";');
                          await controller.evaluateJavascript(
                              source:
                                  'document.getElementById("loginButton2").click();');
                        } else if (url.toString().startsWith(moodleLoginUri)) {
                          await controller.evaluateJavascript(
                              source:
                                  'document.getElementsByName("username")[0].value = "${Model.instance.getAccount()}";');
                          await controller.evaluateJavascript(
                              source:
                                  'document.getElementsByName("password")[0].value = "${Model.instance.getPassword()}";');
                        }
                        widget.loadDone(controller);
                        setState(
                          () {
                            this.url = url!;
                          },
                        );
                      },
                      onProgressChanged:
                          (InAppWebViewController controller, int progress) {
                        setState(
                          () {
                            this.progress = progress / 100;
                          },
                        );
                      },
                      onDownloadStartRequest:
                          (InAppWebViewController controller,
                              DownloadStartRequest downloadStartRequest) {
                        var url = downloadStartRequest.url;
                        Log.d("WebView download ${url.toString()}");
                        if (widget.onWebViewDownload != null) {
                          widget.onWebViewDownload!(url);
                        } else {
                          String dirName = "WebView";
                          FileDownload.download(
                              context, url.toString(), dirName);
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
    );
  }

  List<Widget> get actionList {
    return [
      IconButton(
          splashRadius: 16,
          onPressed: () async {
            if (webView != null) {
              await webView?.goBack();
            }
          },
          icon: const Icon(
            CupertinoIcons.left_chevron,
            size: 18,
          )),
      IconButton(
          splashRadius: 16,
          onPressed: () async {
            if (webView != null) {
              await webView?.goForward();
            }
          },
          icon: const Icon(
            CupertinoIcons.right_chevron,
            size: 18,
          )),
      IconButton(
          splashRadius: 16,
          onPressed: () async {
            if (webView != null) {
              await webView?.reload();
            }
          },
          icon: const Icon(CupertinoIcons.refresh, size: 18)),
      Visibility(
          visible: widget.openWithExternalWebView,
          child: IconButton(
            splashRadius: 16,
            onPressed: () async {
              OpenUtils.launchURL(url.toString());
            },
            icon: SvgPicture.asset(
              "assets/image/img_external_link.svg",
              color: Get.iconColor,
              height: 20,
            ),
          ))
    ];
  }
}
