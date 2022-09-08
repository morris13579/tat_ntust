import 'dart:async';
import 'dart:io' as io;

import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/model/ntust/ap_tree_json.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';

enum NTUSTLoginStatus { success, fail }

class NTUSTConnector {
  static const String host = "https://i.ntust.edu.tw";
  static const String ntustLoginUrl =
      "https://stuinfosys.ntust.edu.tw/NTUSTSSOServ/SSO/Login/CourseSelection";

  static const String subSystemTWUrl = "$host/student";
  static const String subSystemENUrl = "$host/EN/student";

  static Future<Map<String, dynamic>> login(
      String account, String password) async {
    bool loadStop = false;
    try {
      final Uri ntustLoginUri = Uri.parse(ntustLoginUrl);
      final cookieManager = CookieManager.instance();
      final cookieJar = DioConnector.instance.cookiesManager;
      var headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: ntustLoginUri),
        initialOptions: InAppWebViewGroupOptions(
          crossPlatform: InAppWebViewOptions(),
        ),
        onLoadStop: (InAppWebViewController controller, Uri? url) async {
          loadStop = true;
        },
      );
      var webView = headlessWebView.webViewController;
      await headlessWebView.run();
      int time = 0;
      while (true) {
        time += 1;
        await Future.delayed(const Duration(milliseconds: 100));
        if (time > 100) {
          break;
        }
        if (loadStop) {
          loadStop = false;
          if (await webView.getUrl() == ntustLoginUri) {
            await Future.delayed(const Duration(milliseconds: 100));
            await webView.evaluateJavascript(
                source:
                    'document.getElementsByName("UserName")[0].value = "$account";');
            await webView.evaluateJavascript(
                source:
                    'document.getElementsByName("Password")[0].value = "$password";');
            await webView.evaluateJavascript(
                source: 'document.getElementById("btnLogIn").click();');
            Future.delayed(const Duration(seconds: 5)).then((value) {});
            Log.d("wait 5 sec");
          } else {
            try {
              await cookieJar.deleteAll();
            } catch (e) {
              Log.d(e);
            }
            String? result = await webView.getHtml();
            var tagNode = parse(result);
            var nodes =
                tagNode.getElementsByClassName("validation-summary-errors");
            if (nodes.length == 1) {
              return {
                "status": NTUSTLoginStatus.fail,
                "message": nodes[0].text.replaceAll("\n", "")
              };
            } else {
              var cookies = await cookieManager.getCookies(url: ntustLoginUri);
              List<io.Cookie> ioCookies = [];
              bool add = false;
              for (var i in cookies) {
                if ([".ASPXAUTH", "ntustjwtsecret", "ntustsecret"]
                    .contains(i.name)) {
                  io.Cookie k = io.Cookie(i.name, i.value);
                  k.domain = ".ntust.edu.tw";
                  k.path = "/";
                  ioCookies.add(k);
                  add = true;
                }
              }
              if (add) {
                await cookieJar.saveFromResponse(ntustLoginUri, ioCookies);
                return {"status": NTUSTLoginStatus.success};
              } else {
                return {"status": NTUSTLoginStatus.fail};
              }
            }
          }
        }
      }
    } catch (e, stack) {
      Log.eWithStack(e, stack);
    }
    return {"status": NTUSTLoginStatus.fail};
  }

  static Future<APTreeJson?> getSubSystem() async {
    String result;
    Document tagNode;
    Element node;
    List<Element> nodes;
    try {
      String subSystemUrl = (LanguageUtils.getLangIndex() == LangEnum.zh)
          ? subSystemTWUrl
          : subSystemENUrl;
      ConnectorParameter parameter = ConnectorParameter(subSystemUrl);
      result = await Connector.getDataByGet(parameter);
      tagNode = parse(result);
      node = tagNode.getElementById("service")!;
      nodes = node.getElementsByTagName("a");
      List<APListJson> apList = [];
      for (var i in nodes) {
        if (i.text.contains("瀏覽器尚無使用記錄") ||
            i.text.contains("No browsing history")) {
          continue;
        }
        APListJson item =
            APListJson(name: i.text, url: i.attributes["href"]!, type: "link");
        apList.add(item);
      }
      APTreeJson apTreeJson = APTreeJson(apList);
      return apTreeJson;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, String>?> getCalendarUrl() async {
    String result;
    Document tagNode;
    Element node;
    List<Element> nodes;
    Map<String, String> selects = {};
    try {
      String host = "https://www.academic.ntust.edu.tw";
      String url = "$host/p/404-1048-78935.php?Lang=zh-tw";
      ConnectorParameter parameter = ConnectorParameter(url);
      result = await Connector.getDataByGet(parameter);
      tagNode = parse(result);
      nodes = tagNode.getElementsByClassName("meditor");
      node = nodes[1].getElementsByTagName("ul").last;
      for (var i in node.getElementsByTagName("li")) {
        String url = i.getElementsByTagName("a").first.attributes["href"]!;
        if (i.text.contains("google")) {
          continue;
        }
        String key = i.text.split("(").first;
        selects[key] = "$host/$url";
      }
      return selects;
    } catch (e) {
      return null;
    }
  }
}
