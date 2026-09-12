import 'package:flutter/material.dart';
import 'package:flutter_app/ui/components/tat_progress.dart';
import 'package:flutter_app/ui/pages/mail/mail_detail_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;

/// 信件內文的圖片載入指示。
///
/// 守著兩件事：全 App 只有一種轉圈（[TatProgress]），以及內嵌圖片不該為了解碼
/// 閃一下轉圈。不接管的話 `flutter_widget_from_html` 會畫它自己的
/// `CircularProgressIndicator.adaptive`——Material 預設的 4.0 粗線，跟 App 其他
/// 地方明顯不同，畫面上就會先後出現兩種長得不一樣的轉圈。
void main() {
  Future<Widget?> loadingFor(WidgetTester tester, String src) async {
    Widget? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        final element = dom.Element.tag('img')..attributes['src'] = src;
        result = MailDetailPage.imageLoadingBuilder(context, element, null);
        return result ?? const SizedBox.shrink();
      }),
    ));
    return result;
  }

  testWidgets('data: 與 cid: 的圖片不畫轉圈', (tester) async {
    // 已經在記憶體裡，解碼是一瞬間的事，轉圈只會閃一下變成雜訊。
    await loadingFor(tester, 'data:image/png;base64,AAAA');
    expect(find.byType(TatProgress), findsNothing);

    await loadingFor(tester, 'cid:img1@example');
    expect(find.byType(TatProgress), findsNothing);
  });

  testWidgets('遠端圖片給指示，而且用的是 App 共用的轉圈', (tester) async {
    final widget = await loadingFor(tester, 'https://example.com/a.png');

    expect(widget, isNotNull);
    expect(find.byType(TatProgress), findsOneWidget);
  });

  testWidgets('沒有 src 的 img 當成遠端處理，不要當作已在記憶體', (tester) async {
    // 保守：認不出來源時寧可多畫一個指示，也不要讓使用者盯著空白。
    await loadingFor(tester, '');

    expect(find.byType(TatProgress), findsOneWidget);
  });
}
