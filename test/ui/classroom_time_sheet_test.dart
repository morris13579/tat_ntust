import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/section_time.dart';
import 'package:flutter_app/ui/pages/classroom/classroom_time_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_l10n.dart';

/// 改時段選單。
///
/// 這一份會被 pump 起來本身就是重點：選單原本只有真機開得到，`Material`
/// 同時收到 `shape` 與 `borderRadius` 的斷言失敗因此一路漏到裝置上才炸。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadTestL10n();
    // 日期籤走 DateFormat.E()／Md()，沒有這一段會丟 LocaleDataException。
    await initializeDateFormatting();
  });

  Future<ClassroomTime?> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    ClassroomTime? picked;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                picked = await showClassroomTimeSheet(
                  context: context,
                  date: DateTime(2026, 9, 9),
                  section: 2,
                  now: DateTime(2026, 9, 9, 10, 36),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return picked;
  }

  testWidgets('開得起來，而且十四節全部畫得出來', (tester) async {
    await open(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('改時段'), findsOneWidget);
    // 借用系統是十四節，不是設計稿上那八節。
    for (final label in sectionLabels) {
      expect(find.text(label), findsWidgets, reason: '第 $label 節不見了');
    }
    expect(find.text('08:10'), findsOneWidget);
    expect(find.text('21:00'), findsOneWidget, reason: '最後一節也要在');
  });

  testWidgets('選了節次再按「查這一節」，回傳選到的那一格', (tester) async {
    ClassroomTime? picked;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                picked = await showClassroomTimeSheet(
                  context: context,
                  date: DateTime(2026, 9, 9),
                  section: 2,
                  now: DateTime(2026, 9, 9, 10, 36),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('13:20'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查這一節'));
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!.section, 5, reason: '13:20 是索引 5');
    expect(picked!.date, DateTime(2026, 9, 9));
  });

  testWidgets('「回到現在」回到今天與當下的節次', (tester) async {
    ClassroomTime? picked;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                picked = await showClassroomTimeSheet(
                  context: context,
                  date: DateTime(2026, 9, 20),
                  section: 9,
                  now: DateTime(2026, 9, 9, 10, 36),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('回到現在'));
    await tester.pumpAndSettle();

    expect(picked!.date, DateTime(2026, 9, 9));
    expect(picked!.section, 2, reason: '10:36 落在 10:20–11:10');
  });
}
