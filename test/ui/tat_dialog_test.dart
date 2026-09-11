import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/ui/other/error_dialog.dart';
import 'package:flutter_app/ui/other/tat_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../helpers/test_l10n.dart';

/// 對話框在等一個決定，所以點遮罩不關；但系統返回鍵關得掉，那條路徑拿不到
/// 按鈕的回傳值，只能退回呼叫端指定的 cancelResult。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => loadTestL10n());

  Widget host() => const GetMaterialApp(home: Scaffold(body: SizedBox()));

  /// 標題前那顆語意圓點。
  Color dotColor(WidgetTester tester) {
    final dot = tester.widget<Container>(find.descendant(
      of: find.byType(TatDialog),
      matching: find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).shape == BoxShape.circle),
    ));
    return (dot.decoration! as BoxDecoration).color!;
  }

  testWidgets('點遮罩不會關掉對話框', (tester) async {
    await tester.pumpWidget(host());

    final result = ErrorDialog(ErrorDialogParameter(desc: '請確認網路連接狀態')).show();
    await tester.pumpAndSettle();
    expect(find.text('請確認網路連接狀態'), findsOneWidget);

    // 對話框置中，左上角一定是遮罩。
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.text('請確認網路連接狀態'), findsOneWidget);

    await tester.tap(find.text(R.current.cancel));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });

  testWidgets('系統返回鍵關掉時回傳 cancelResult 而不是 false', (tester) async {
    await tester.pumpWidget(host());

    // 只有一顆按鈕的對話框會把 okResult 設成 false，所以 `?? false` 會讓
    // 「被關掉」與「按了確定」變成同一個答案。
    final result = ErrorDialog(ErrorDialogParameter(
      desc: '登入 Moodle 失敗',
      okResult: false,
      cancelResult: true,
    )).show();
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(await result, isTrue);
  });

  test('兩顆按鈕都關掉會 assert', () {
    // 點外面不關，兩顆都沒有等於把畫面鎖死。
    expect(
      () => ErrorDialogParameter(desc: 'x', offOkBtn: true, offCancelBtn: true),
      throwsA(isA<AssertionError>()),
    );
  });

  testWidgets('四種 kind 只差標題前的圓點顏色', (tester) async {
    final colors = <Color>[];

    for (final kind in TatDialogKind.values) {
      await tester.pumpWidget(MaterialApp(
        home: TatDialog(
          title: '標題',
          body: '內文',
          kind: kind,
          primary: TatDialogAction(label: '確定', onPressed: () {}),
        ),
      ));
      await tester.pumpAndSettle();

      // 版面完全一樣：沒有插圖、沒有不同的內容。
      expect(find.text('標題'), findsOneWidget);
      expect(find.text('內文'), findsOneWidget);
      expect(find.text('確定'), findsOneWidget);
      expect(find.byType(Image), findsNothing);

      colors.add(dotColor(tester));
    }

    expect(colors.toSet().length, TatDialogKind.values.length);
  });
}
