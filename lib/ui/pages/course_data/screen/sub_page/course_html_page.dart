import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/util/web_view_url_policy.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/html/no_embedded_web_view_factory.dart';
import 'package:flutter_app/ui/components/page/error_page.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:flutter_app/ui/routes/route_utils.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

/// 具名 tear-off 而非匿名 closure：`factoryBuilder` 每次 rebuild 拿到的身分
/// 才穩定，測試也能不啟動整個頁面就驗證 `webView` 是關的。
WidgetFactory courseHtmlWidgetFactory() => NoEmbeddedWebViewFactory();

/// 顯示 Moodle 上的 HTML 教材。輸入等同不可信，兩道防線不要拿掉：
/// [NoEmbeddedWebViewFactory] 擋 iframe、[WebViewUrlPolicy.handleTap] 擋非 http(s)。
class CourseHtmlPage extends StatefulWidget {
  const CourseHtmlPage({super.key, required this.ap});

  final Modules ap;

  @override
  State<CourseHtmlPage> createState() => _CourseHtmlPageState();
}

class _CourseHtmlPageState extends State<CourseHtmlPage> {
  /// 只取一次：future 寫在 build 裡的話每次 rebuild 都會重打網路請求。
  late final Future<String> _pageData = _getPageData();

  /// [HtmlWidget.baseUrl]：少了它相對連結會變成沒有 scheme 的殘缺字串。刻意用
  /// 沒有 token 的原始 fileurl，避免 `?token=` 被帶進教材解析出來的網址。
  late final Uri? _baseUrl = widget.ap.contents.isEmpty
      ? null
      : Uri.tryParse(widget.ap.contents.first.fileurl);

  Future<String> _getPageData() async {
    // contents 為空時拋的 StateError 會被收進 Future，由 FutureBuilder 接。
    final params = MoodleWebApiConnector.fileUrlWithToken(
        widget.ap.contents.first.fileurl);
    final html =
        await DioConnector.instance.getDataByGet(ConnectorParameter(params));
    return html;
  }

  void _openInWebView(String url) {
    // fire-and-forget：這個 Future 要等使用者從 WebView 返回才完成。
    unawaited(RouteUtils.toWebViewPage(widget.ap.name, url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: baseAppbar(title: widget.ap.name),
      body: FutureBuilder<String>(
        future: _pageData,
        builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Text("");
          }
          final html = snapshot.data;
          if (html == null) {
            return const ErrorPage();
          }
          return Padding(
            padding: const EdgeInsets.all(10.0),
            child: HtmlWidget(
              html,
              baseUrl: _baseUrl,
              factoryBuilder: courseHtmlWidgetFactory,
              textStyle: context.text.bodyLarge,
              renderMode: RenderMode.column,
              onTapUrl: (String url) => WebViewUrlPolicy.handleTap(
                url,
                openInWebView: _openInWebView,
              ),
            ),
          );
        },
      ),
    );
  }
}
