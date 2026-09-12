import 'package:flutter/material.dart';
import 'package:flutter_app/ui/pages/mail/components/mail_swipe_action.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';

/// 滑動選單的按鈕。
///
/// **這一組跑的是真的 `Slidable` 並且真的拖開它**，不是只把按鈕單獨畫出來——
/// 壞掉的正是中間那一層：`ActionPane` 把 children 交給 motion 的 Flex 排，沒有
/// 包 `Expanded` 的子項會拿到零寬度，整排按鈕變成一片空白。單獨畫按鈕不會重現。
const double _extent = 0.56;

/// 頁面用的那個比例：門檻是「露出寬度的六成二」，不是「整列的六成二」。
const double _openFraction = 0.62;

ActionPane _pane(
        double extent, List<String> labels, void Function(String)? onPressed) =>
    ActionPane(
      motion: const DrawerMotion(),
      extentRatio: extent,
      openThreshold: extent * _openFraction,
      children: [
        for (final label in labels)
          MailSwipeAction(
            onPressed: () => onPressed?.call(label),
            background: Colors.blue,
            foreground: Colors.white,
            icon: Icons.archive,
            label: label,
            extentRatio: extent,
          ),
      ],
    );

Future<void> pumpRow(
  WidgetTester tester, {
  required List<String> labels,
  void Function(String)? onPressed,
  List<String> startLabels = const [],
  double extent = _extent,
  double startExtent = 0.19,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ListView(
        children: [
          Slidable(
            key: const ValueKey('row'),
            startActionPane: startLabels.isEmpty
                ? null
                : _pane(startExtent, startLabels, onPressed),
            endActionPane: _pane(extent, labels, onPressed),
            child: const SizedBox(height: 72, child: Text('一封信')),
          ),
        ],
      ),
    ),
  ));
  await tester.pump();
}

/// 慢慢拖過去再放開——不是甩。
///
/// `tester.drag` 一步到位會被速度追蹤器當成快速甩動，走的是
/// `OpeningGesture` 那條路；使用者真正的動作多半是拖到定位停一下再放手，那是
/// `StillGesture`，判斷式完全不同（要比 `position >= openThreshold`）。左邊
/// 那一排固定不住就是只在這條路上壞掉。
Future<void> dragAndRelease(WidgetTester tester, double dx) async {
  final gesture = await tester.startGesture(tester.getCenter(find.text('一封信')));
  for (var i = 0; i < 6; i++) {
    await gesture.moveBy(Offset(dx / 6, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  // 停住：讓速度歸零，放開時才是 StillGesture。
  await tester.pump(const Duration(milliseconds: 300));
  await gesture.up();
  await tester.pumpAndSettle();
}

double ratioOf(WidgetTester tester) =>
    Slidable.of(tester.element(find.byType(MailSwipeAction).first))?.ratio ?? 0;

/// 往左拖開整排選單。
Future<void> openEndPane(WidgetTester tester) async {
  await tester.drag(find.text('一封信'), const Offset(-600, 0));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('拉開之後按鈕真的有寬度，不是一片空白', (tester) async {
    await pumpRow(tester, labels: ['更多', '封存', '刪除']);

    await openEndPane(tester);

    for (final label in ['更多', '封存', '刪除']) {
      expect(find.text(label), findsOneWidget, reason: '$label 不見了');
      final box = tester.renderObject<RenderBox>(
          find.byType(MailSwipeAction).at(['更多', '封存', '刪除'].indexOf(label)));
      expect(box.size.width, greaterThan(0), reason: '$label 拿到零寬度');
      expect(box.size.height, greaterThan(0));
    }
  });

  testWidgets('三顆按鈕平分那一排的寬度', (tester) async {
    await pumpRow(tester, labels: ['更多', '封存', '刪除']);
    await openEndPane(tester);

    final widths = [
      for (var i = 0; i < 3; i++)
        tester
            .renderObject<RenderBox>(find.byType(MailSwipeAction).at(i))
            .size
            .width
    ];

    expect(widths.first, greaterThan(0));
    for (final w in widths) {
      expect(w, closeTo(widths.first, 1), reason: '寬度不平均：$widths');
    }
  });

  testWidgets('按下去會回報，而且那一列自己收起來', (tester) async {
    final pressed = <String>[];
    await pumpRow(tester, labels: ['更多', '封存'], onPressed: pressed.add);
    await openEndPane(tester);

    // **點圓鈕，不是點底下那行字。** 可按的範圍就是那顆圓——字在圓外面，是
    // 說明不是按鈕，這一點和 iOS 信件一樣。
    await tester.tap(find.byIcon(Icons.archive).at(1));
    await tester.pumpAndSettle();

    expect(pressed, ['封存']);
    // 按完那一列自己收回去：動作已經發生，選單留著沒有意義。
    expect(find.byType(MailSwipeAction), findsNothing);
  });

  testWidgets('沒拉開的時候整排根本沒有掛上去', (tester) async {
    // `Slidable` 要等 `actionPaneType` 變了才掛 pane，所以關著的時候按鈕不在
    // 樹上——不必擔心它從縫裡透出來，也代表那幾顆圓鈕不會白白算繪。
    await pumpRow(tester, labels: ['更多']);

    expect(find.byType(MailSwipeAction), findsNothing);
  });

  group('放開之後要固定住', () {
    testWidgets('左邊那一排拖開放手，會停在原地', (tester) async {
      // **這一條先前是紅的。** `openThreshold` 比的是「佔整列的比例」而不是
      // 「佔這一排的比例」；先前兩排都填 0.62，露出寬度只有 0.19 的左邊那一排
      // 永遠到不了門檻（位置被 `normalizeRatio` 夾在 0.19 以內），放開就彈回去。
      await pumpRow(tester, labels: ['封存'], startLabels: ['已讀']);

      // 往右拖超過門檻（0.19 × 0.62 ≈ 0.12 的整列寬度）。
      await dragAndRelease(tester, 120);

      expect(ratioOf(tester), greaterThan(0), reason: '左邊那一排彈回去了');
      expect(find.text('已讀'), findsOneWidget);
    });

    testWidgets('右邊那一排一樣', (tester) async {
      await pumpRow(tester, labels: ['更多', '封存', '刪除']);

      await dragAndRelease(tester, -260);

      expect(ratioOf(tester), lessThan(0));
      expect(find.text('刪除'), findsOneWidget);
    });

    testWidgets('沒拉過門檻就彈回去，不會半開著卡在那裡', (tester) async {
      await pumpRow(tester, labels: ['封存'], startLabels: ['已讀']);

      // 只拖一點點，遠不到門檻。
      await dragAndRelease(tester, 20);

      // 收回去之後整排就從樹上拿掉了（`actionPaneType` 回到 none），所以
      // 「找不到按鈕」就是「關好了」。
      expect(find.byType(MailSwipeAction), findsNothing);
    });
  });
}
