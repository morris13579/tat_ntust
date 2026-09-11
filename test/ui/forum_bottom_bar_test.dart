import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/forum_bottom_bar.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_l10n.dart';

/// 「這裡不能回覆」那條底列的版面規格。
///
/// 這一組全部是**窄螢幕加放大字級**：把句子與兩顆按鈕排在同一條 Row 裡時，
/// 那兩顆鈕在 360dp 上就吃掉 270dp，句子被 `Expanded` 壓成一條十幾行的窄柱，
/// 字級再放大整條列會長到佔掉三分之一個螢幕，最後直接 overflow。800px 寬的
/// 一般 widget 測試看不到這件事，所以這裡自己把視窗調窄。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadTestL10n();
  });

  /// 360×640 是主流手機的邏輯尺寸。
  Future<void> pump(
    WidgetTester tester,
    Widget bar, {
    double textScale = 1.0,
    double width = 360,
  }) async {
    tester.view.physicalSize = Size(width, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(body: const SizedBox.shrink(), bottomNavigationBar: bar),
    ));
    await tester.pumpAndSettle();
  }

  /// 最寬的一種：一句長話加兩顆鈕。
  Widget widest() => ForumNoticeBar(
        message: R.current.forumThreadLocked,
        onOpenWeb: () {},
        onRetry: () {},
      );

  for (final scale in [1.0, 1.3, 1.5, 2.0]) {
    testWidgets('360dp、字級 x$scale：兩顆鈕的那一種不 overflow', (tester) async {
      await pump(tester, widest(), textScale: scale);

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('320dp、字級 x1.5 也不 overflow——最小的螢幕加放大字級', (tester) async {
    await pump(tester, widest(), textScale: 1.5, width: 320);

    expect(tester.takeException(), isNull);
  });

  testWidgets('句子佔滿整條列的寬度，不是被兩顆鈕擠出來的一條窄柱', (tester) async {
    await pump(tester, widest());

    final text = tester.getSize(find.text(R.current.forumThreadLocked));
    // 左右各 16 的 padding，其餘都是句子的。
    expect(text.width, greaterThan(300));
  });

  testWidgets('沒有出口時就只有一句話——不掛一顆按不出結果的鈕', (tester) async {
    await pump(tester, ForumNoticeBar(message: R.current.forumThreadLocked));

    expect(find.byType(TextButton), findsNothing);
    expect(find.text(R.current.forumThreadLocked), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
