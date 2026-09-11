import 'package:flutter/material.dart';
import 'package:flutter_app/ui/components/sheet/tat_bottom_sheet.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_test/flutter_test.dart';

/// 選單沒有「預設答案」：關掉就是沒選，所以一律回 null，呼叫端不會把誤觸當成
/// 一個決定。這與對話框相反，因此點遮罩是可以關的。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 把選單掛在一顆按鈕後面，並記錄它的回傳值。
  Future<void> pumpOpener(
    WidgetTester tester,
    Future<String?> Function(BuildContext context) open,
    List<String?> results,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(await open(context)),
            child: const Text('開'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('開'));
    await tester.pumpAndSettle();
  }

  /// 選單貼在畫面底部，最上面一定是遮罩。
  Future<void> tapBarrier(WidgetTester tester) async {
    await tester.tapAt(const Offset(400, 8));
    await tester.pumpAndSettle();
  }

  testWidgets('動作清單：點了回傳值，點遮罩回傳 null', (tester) async {
    final results = <String?>[];
    Future<String?> open(BuildContext context) => showTatActionSheet<String>(
          context: context,
          items: const [
            TatSheetItem(
                icon: LucideIcons.camera, label: '拍照', value: 'camera'),
            TatSheetItem(
                icon: LucideIcons.trash2,
                label: '移除頭貼',
                value: 'remove',
                destructive: true),
          ],
        );

    await pumpOpener(tester, open, results);
    await tester.tap(find.text('拍照'));
    await tester.pumpAndSettle();
    expect(results, ['camera']);

    await tester.tap(find.text('開'));
    await tester.pumpAndSettle();
    await tapBarrier(tester);
    expect(results, ['camera', null]);
  });

  testWidgets('單選清單：選中的那一列有 check，關掉回傳 null', (tester) async {
    final results = <String?>[];
    Future<String?> open(BuildContext context) =>
        showTatSingleSelectSheet<String>(
          context: context,
          title: '語言設定',
          options: const [
            TatSheetOption(label: '繁體中文', value: 'zh'),
            TatSheetOption(label: 'English', value: 'en'),
          ],
          selected: 'zh',
        );

    await pumpOpener(tester, open, results);
    expect(find.text('語言設定'), findsOneWidget);
    expect(find.byIcon(LucideIcons.check), findsOneWidget);

    await tapBarrier(tester);
    expect(results, [null]);

    await tester.tap(find.text('開'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(results, [null, 'en']);
  });

  testWidgets('內容型：關掉回傳 null', (tester) async {
    final results = <String?>[];
    Future<String?> open(BuildContext context) => showTatContentSheet<String>(
          context: context,
          title: '微積分（一）',
          showClose: true,
          builder: (context) => const SizedBox(height: 80, child: Text('詳細內容')),
        );

    await pumpOpener(tester, open, results);
    expect(find.text('詳細內容'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pumpAndSettle();
    expect(results, [null]);
  });
}
