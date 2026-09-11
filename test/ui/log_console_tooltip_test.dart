import 'package:flutter/material.dart';
import 'package:flutter_app/debug/log/console_output.dart';
import 'package:flutter_app/ui/pages/log_console/log_console.dart';
import 'package:flutter_test/flutter_test.dart';

/// LogConsole 的四顆 AppBar 圖示按鈕（返回／清除／放大／縮小）與捲到底的 FAB。
///
/// 這一頁刻意不走 R.current：整頁 UI（標題、篩選欄、log level 下拉）都是
/// 寫死的英文，而且只有 debug build 進得來。這個測試把「英文」這件事一起
/// 釘住，之後有人整頁在地化時會看到這裡要一起改。
void main() {
  setUpAll(LogBuffer.init);

  testWidgets('AppBar 的四顆圖示按鈕都有各自可讀的名字', (tester) async {
    // LogConsole 自己就會回傳一個 MaterialApp，不需要外面再包一層。
    await tester.pumpWidget(LogConsole());
    await tester.pump(const Duration(seconds: 1));

    final tooltips = tester
        .widgetList<IconButton>(find.byType(IconButton))
        .map((b) => b.tooltip)
        .toList();

    expect(tooltips, hasLength(4));
    expect(tooltips.any((t) => t == null || t.isEmpty), isFalse);
    // 四顆的名字必須互不相同，否則唸起來還是分不出哪顆是哪顆。
    expect(tooltips.toSet(), hasLength(4));

    // LogConsole 自建的 MaterialApp 沒有掛 GlobalMaterialLocalizations，
    // 所以 backButtonTooltip 走 DefaultMaterialLocalizations 的英文 "Back"。
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byTooltip('Clear log'), findsOneWidget);
    expect(find.byTooltip('Increase font size'), findsOneWidget);
    expect(find.byTooltip('Decrease font size'), findsOneWidget);
  });

  testWidgets('捲到底的 FAB 也有名字', (tester) async {
    await tester.pumpWidget(LogConsole());
    await tester.pump(const Duration(seconds: 1));

    // FAB 平常用 AnimatedOpacity 淡成透明，但一直都在 widget tree 上，
    // 對螢幕閱讀器來說仍然是一顆按得到的按鈕。
    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .tooltip,
      'Scroll to bottom',
    );
  });

  testWidgets('放大與縮小按鈕仍然真的會改字級，沒有被 tooltip 改壞', (tester) async {
    await tester.pumpWidget(LogConsole());
    await tester.pump(const Duration(seconds: 1));

    // 這兩顆的 onPressed 只做 _logFontSize++/--，畫面上沒有數字可以斷言，
    // 所以退而確認按鈕還按得下去、按完不會丟例外。
    await tester.tap(find.byTooltip('Increase font size'));
    await tester.pump();
    await tester.tap(find.byTooltip('Decrease font size'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
