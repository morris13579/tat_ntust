import 'package:flutter/material.dart';
import 'package:flutter_app/ui/components/toast/tat_bottom_pill.dart';
import 'package:flutter_test/flutter_test.dart';

/// 底部膠囊。這一組釘的是「進度提示與 toast 長得一樣」——它們曾經是兩個各自
/// 手寫的東西，圓角、內距、離導覽列多遠全都不同，而它們會在同一個位置先後
/// 出現，使用者一眼就看得出來。
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Center(child: child))),
      );

  Container containerOf(WidgetTester tester) => tester.widget<Container>(find
      .descendant(
          of: find.byType(TatBottomPill), matching: find.byType(Container))
      .first);

  testWidgets('整顆膠囊：圓角就是高度的一半', (tester) async {
    await pump(
      tester,
      const TatBottomPill(leading: Icon(Icons.info), message: '已標記為未讀'),
    );

    final decoration = containerOf(tester).decoration! as BoxDecoration;
    expect(decoration.borderRadius,
        BorderRadius.circular(TatBottomPill.height / 2));
  });

  testWidgets('高度至少 48——一行字的時候就是 48', (tester) async {
    await pump(
      tester,
      const TatBottomPill(leading: Icon(Icons.info), message: '已複製'),
    );

    final box = tester.renderObject<RenderBox>(find.byType(TatBottomPill));
    expect(box.size.height, TatBottomPill.height);
  });

  testWidgets('訊息長的時候截成兩行，不會把膠囊撐成一整頁', (tester) async {
    await pump(
      tester,
      const TatBottomPill(
        leading: Icon(Icons.info),
        message: '這是一句很長很長的錯誤訊息，長到足以把一顆底部膠囊撐成好幾行，'
            '而那會蓋住半個畫面，所以它必須被截斷。',
      ),
    );

    final text = tester.widget<Text>(find.byType(Text));
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('有動作鈕時右邊的內距收窄，沒有的時候不佔位置', (tester) async {
    // 「收回」那顆鈕自己有內距，外面再留 20 的話按鈕會離邊緣太遠。
    await pump(
      tester,
      const TatBottomPill(leading: Icon(Icons.send), message: '寄送中'),
    );
    final without = containerOf(tester).padding! as EdgeInsets;

    await pump(
      tester,
      TatBottomPill(
        leading: const Icon(Icons.send),
        message: '寄送中',
        trailing: TextButton(onPressed: () {}, child: const Text('收回')),
      ),
    );
    final withAction = containerOf(tester).padding! as EdgeInsets;

    expect(without.right, 20);
    expect(withAction.right, 8);
    expect(withAction.left, without.left);
    expect(find.text('收回'), findsOneWidget);
  });

  testWidgets('進度膠囊與提示膠囊是同一個 widget，不是兩份長得像的程式', (tester) async {
    // 這一條是回歸測試：它們先前是兩份各自手寫的膠囊。
    await pump(
      tester,
      const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TatBottomPill(leading: Icon(Icons.info), message: '已標記為未讀'),
          TatBottomPill(
              leading: SizedBox(width: 16, height: 16), message: '取得課表中…'),
        ],
      ),
    );

    final decorations = tester
        .widgetList<Container>(find.descendant(
            of: find.byType(TatBottomPill), matching: find.byType(Container)))
        .map((c) => c.decoration! as BoxDecoration)
        .toList();
    expect(decorations, hasLength(2));
    expect(decorations[0].borderRadius, decorations[1].borderRadius);
    expect(decorations[0].color, decorations[1].color);
  });

  test('有導覽列時要讓開它，沒有的時候只留呼吸空間', () {
    // 沒有 navigator 的情況（測試環境）當成主畫面：讓開導覽列比蓋住它安全。
    expect(tatBottomPillInset(), 64 + 24);
  });
}
