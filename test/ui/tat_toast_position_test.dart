import 'package:flutter/material.dart';
import 'package:flutter_app/ui/components/toast/tat_bottom_pill.dart';
import 'package:flutter_app/ui/components/toast/tat_toast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// toast 在畫面上的位置。這一組跑的是真的 `TatToast.show`，不是只量那顆膠囊
/// ——先前壞掉的正是中間那一層：toastification 把每一則塞進寫死 400 寬的
/// `BoxConstraints.tightFor`，膠囊被撐開，圖示與文字就貼在左邊。
void main() {
  Future<void> pumpApp(WidgetTester tester, Size size) async {
    // 失敗的那一條也要收乾淨：`toastification` 是 process 級單例，留下來的計時器
    // 會活到下一條測試，讓它拿到上一條的畫面。
    addTearDown(TatToast.resetForTest);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GetMaterialApp(
      home: Scaffold(body: SizedBox.expand()),
    ));
    await tester.pump();
  }

  /// 叫出一則 toast、量它的位置，然後收乾淨。
  ///
  /// **一定要收。** `toastification` 是 process 級的單例，自動關閉的計時器會
  /// 活過這一條測試——不收的話下一條會拿到上一條留下的狀態，而且測試框架會
  /// 抱怨「widget tree 都拆了還有 Timer 在跑」。
  Future<Rect> showAndMeasure(WidgetTester tester) async {
    TatToast.show('已標記為未讀');
    // toastification 是在 post-frame callback 裡插進 AnimatedList 的，
    // 要多推幾格才看得到。
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    final box = tester.renderObject<RenderBox>(find.byType(TatBottomPill));
    final rect = box.localToGlobal(Offset.zero) & box.size;

    TatToast.resetForTest();
    await tester.pump(const Duration(seconds: 3));
    return rect;
  }

  testWidgets('膠囊在畫面水平置中', (tester) async {
    await pumpApp(tester, const Size(411, 915));

    final rect = await showAndMeasure(tester);

    expect(rect.center.dx, closeTo(411 / 2, 1),
        reason: '膠囊中心要和畫面中心對齊，量到的是 $rect');
  });

  testWidgets('膠囊縮到自己的大小，不會被撐成 400 寬', (tester) async {
    // toastification 給的是 tightFor(width: 400)。沒有 Center 的話這裡會量到
    // 352（400 扣掉左右各 24 的內距）。
    await pumpApp(tester, const Size(411, 915));

    final rect = await showAndMeasure(tester);

    expect(rect.width, lessThan(300), reason: '「已標記為未讀」六個字不該撐出 $rect');
  });

  testWidgets('窄螢幕上也不會頂到邊緣', (tester) async {
    await pumpApp(tester, const Size(320, 640));

    final rect = await showAndMeasure(tester);

    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
    expect(rect.center.dx, closeTo(160, 1));
  });

  /// 等到膠囊真的出現。
  ///
  /// **舊的收掉、新的放上去，中間會有一格是空的**：toastification 把插入排在
  /// post-frame callback，而移除是當下就做。固定 pump 幾格很容易剛好量在那個
  /// 空檔上，所以這裡等到出現為止。
  Future<void> pumpUntilPill(WidgetTester tester, String text) async {
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 120));
      if (find.text(text).evaluate().isNotEmpty) {
        // 進場動畫跑完再回去。**要 pump 好幾格**：`tester.pump(Duration)` 不管
        // 給多長都只產生一格，而 toastification 是在 post-frame callback 裡把
        // 項目插進 `AnimatedList`，前後要好幾格才穩定。
        for (var j = 0; j < 4; j++) {
          await tester.pump(const Duration(milliseconds: 120));
        }
        return;
      }
    }
  }

  /// 收乾淨並把計時器跑完——留著的話測試框架會抱怨「widget tree 都拆了還有
  /// Timer 在跑」。
  Future<void> closeAll(WidgetTester tester) async {
    TatToast.resetForTest();
    await tester.pump(const Duration(seconds: 5));
  }

  group('同時只留一則', () {
    testWidgets('第二則直接蓋掉第一則，不會疊在一起', (tester) async {
      // 「檢查更新中」後面緊接著「已經是最新版本」：兩則疊著的話使用者要讀兩行
      // 才知道結論，而且第一句已經沒有意義了。
      await pumpApp(tester, const Size(411, 915));

      TatToast.show('檢查更新中');
      await pumpUntilPill(tester, '檢查更新中');
      expect(find.text('檢查更新中'), findsOneWidget);

      TatToast.show('已經是最新版本');
      await pumpUntilPill(tester, '已經是最新版本');

      expect(find.text('檢查更新中'), findsNothing, reason: '舊的那一則還在');
      expect(find.text('已經是最新版本'), findsOneWidget);
      expect(find.byType(TatBottomPill), findsOneWidget, reason: '畫面上不只一顆膠囊');

      await closeAll(tester);
    });

    testWidgets('進度膠囊不佔那個名額——它代表一件還沒做完的事', (tester) async {
      await pumpApp(tester, const Size(411, 915));

      final handle = TatToast.progress('取得課表中…');
      await pumpUntilPill(tester, '取得課表中…');
      TatToast.show('已複製');
      await pumpUntilPill(tester, '已複製');

      expect(find.text('取得課表中…'), findsOneWidget,
          reason: '一句「已複製」把還在跑的進度提示擠掉了');
      expect(find.text('已複製'), findsOneWidget);

      handle.dismiss();
      await closeAll(tester);
    });
  });
}
