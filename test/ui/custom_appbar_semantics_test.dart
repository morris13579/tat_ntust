import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_colors.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/config/app_styles.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_test/flutter_test.dart';

/// baseAppbar 的返回鍵出現在每一個子頁面上，必須有可讀的名字，
/// 否則螢幕閱讀器唸出來就只有「按鈕」。名字取自 GlobalMaterialLocalizations
/// 的 backButtonTooltip，不必為此新增 l10n key。
void main() {
  testWidgets('baseAppbar 的返回鍵有可讀的名字', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(appBar: baseAppbar(title: '測試頁')),
      ),
    );

    final buttons = tester.widgetList<IconButton>(find.byType(IconButton));
    expect(buttons, hasLength(1));
    expect(buttons.first.tooltip, isNotNull);
    expect(buttons.first.tooltip, isNotEmpty);

    // MaterialApp 沒有指定 delegate 時走 DefaultMaterialLocalizations（en）。
    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('返回鍵仍然掛在 leading 上且可以按，沒有被 Builder 包壞', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(appBar: baseAppbar(title: '測試頁')),
      ),
    );

    // 按鈕要還在 AppBar 裡、還有 onPressed，而且畫得出來（有面積可點）。
    // 這裡不真的 tap：Get.back() 在沒有 GetMaterialApp 的環境會抱怨
    // contextless navigation，那是 GetX 的事，不是這個 appbar 的事。
    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.onPressed, isNotNull);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(IconButton),
      ),
      findsOneWidget,
    );
    expect(tester.getSize(find.byType(IconButton)).isEmpty, isFalse);
  });

  testWidgets('mainAppbar 不顯示返回鍵時，不會留下沒有名字的圖示按鈕', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(appBar: mainAppbar(title: '測試頁')),
      ),
    );

    expect(find.byType(IconButton), findsNothing);
  });

  group('底色與狀態列交給 AppBarTheme', () {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.fallbackSeed);
    final tokens = TatTokens.from(scheme);
    final theme = ThemeData(
      colorScheme: scheme,
      appBarTheme: AppStyles.appBarTheme(scheme, tokens),
    );

    /// 這兩顆以前一個寫死 `Colors.transparent`、一個什麼都不寫，同一個 app 裡
    /// 兩條 bar 長得不一樣；動態取色下透明那條等於把層級整個關掉。
    for (final (name, build) in [
      ('mainAppbar', mainAppbar),
      ('baseAppbar', baseAppbar),
    ]) {
      testWidgets('$name 不自己指定底色', (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(appBar: build(title: '測試頁')),
        ));

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.backgroundColor, isNull, reason: '底色只能有一個出處：AppBarTheme');
        // systemOverlayStyle 也不自己算：AppBar 會從實際底色推狀態列圖示明暗，
        // 自己算的那份是拿全域 Get.theme 猜的，第一幀一定猜錯。
        expect(appBar.systemOverlayStyle, isNull);

        final material = tester.widget<Material>(find
            .descendant(
                of: find.byType(AppBar), matching: find.byType(Material))
            .first);
        // 兩條 bar 都吃 AppBarTheme 的底色，也就是頁面底色那一階。
        expect(material.color, tokens.page);
      });
    }
  });
}
