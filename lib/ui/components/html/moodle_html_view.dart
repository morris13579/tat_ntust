import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/util/web_view_url_policy.dart';
import 'package:flutter_app/ui/components/html/no_embedded_web_view_factory.dart';
import 'package:flutter_app/ui/components/page/web_view_opener.dart';
import 'package:flutter_app/ui/service/file_download.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:flutter_app/ui/other/lucide_icons.dart';

/// 給 [HtmlWidget.factoryBuilder] 的具名 tear-off，理由同 course_html_page。
/// 深色模式換另一個：教材寫死的顏色要中和掉。
WidgetFactory _moodleHtmlWidgetFactory() => NoEmbeddedWebViewFactory();

WidgetFactory _moodleHtmlWidgetFactoryDark() =>
    NoEmbeddedWebViewFactory(neutralizeColors: true);

/// Moodle 原文 HTML 的算繪：關掉內嵌 WebView、自家 pluginfile 連結直接下載、
/// 自家 pluginfile 的 `<img>` 帶 token，其餘連結過 [WebViewUrlPolicy]。
class MoodleHtmlView extends StatelessWidget {
  const MoodleHtmlView({
    super.key,
    required this.html,
    required this.title,
    required this.dirName,
    required this.openWebView,
  });

  final String html;

  /// 只給 WebView 標題與下載用，不算繪。
  final String title;

  /// 下載目錄名（課程名）。
  final String dirName;

  final WebViewOpener openWebView;

  @override
  Widget build(BuildContext context) {
    return HtmlWidget(
      html,
      renderMode: RenderMode.column,
      textStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
          height: 1.5, color: Theme.of(context).colorScheme.onSurface),
      factoryBuilder: Theme.of(context).brightness == Brightness.dark
          ? _moodleHtmlWidgetFactoryDark
          : _moodleHtmlWidgetFactory,
      onTapUrl: (url) => _onTapUrl(context, url),
      customWidgetBuilder: _imageBuilder,
    );
  }

  /// 自家 pluginfile 連結直接下載，其餘（含別人站台的 pluginfile.php）過
  /// [WebViewUrlPolicy]，判斷與底下的 `<img>` 一致。
  bool _onTapUrl(BuildContext context, String url) {
    if (MoodleWebApiConnector.isOwnPluginFileUrl(url)) {
      unawaited(FileDownload.download(
        context,
        MoodleWebApiConnector.fileUrlWithToken(url),
        dirName,
        name: downloadNameOf(url),
      ));
      return true;
    }
    return WebViewUrlPolicy.handleTap(
      url,
      openInWebView: (u) => unawaited(openWebView(title, u)),
    );
  }

  /// 網址最後一段當檔名。`pathSegments` 是解碼過的，`..` 或帶分隔符的一段接進
  /// 儲存路徑會寫到下載目錄外面，這種一律回空字串改讓伺服器的標頭決定。
  static String downloadNameOf(String url) {
    final segments = Uri.tryParse(url)?.pathSegments ?? const <String>[];
    final name = segments.isEmpty ? "" : segments.last;
    const unsafe = ['/', r'\', '\u0000'];
    if (name == '.' || name == '..' || unsafe.any(name.contains)) return "";
    return name;
  }

  /// 只接手自家 pluginfile 的 `<img>`（那種圖要帶 token）；其餘回 null 交回
  /// 預設 factory，用 `Image.network` 去載 `data:` 只會得到破圖。
  Widget? _imageBuilder(dom.Element element) {
    if (element.localName != 'img') return null;
    final src = element.attributes['src'] ?? '';
    if (!MoodleWebApiConnector.isOwnPluginFileUrl(src)) return null;
    return Image.network(
      MoodleWebApiConnector.fileUrlWithToken(src),
      width: _pxAttribute(element, 'width'),
      height: _pxAttribute(element, 'height'),
      errorBuilder: (_, __, ___) => const Icon(LucideIcons.imageOff),
    );
  }

  /// `width="300"` 這種純數字（編輯器寫的就是這種）；`100%` 或帶單位的不理。
  static double? _pxAttribute(dom.Element element, String name) =>
      double.tryParse(element.attributes[name] ?? '');
}
