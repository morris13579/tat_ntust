import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/store/extra_table_store.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/pages/course_table/modal/table_switcher_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

/// 課表切換器：三個來源各一區，空的那一區不出現。
void main() {
  setUpAll(() async {
    await R.load(const Locale('zh', 'TW'));
  });

  CourseTableJson tableOf(String studentId, String year, String semester) =>
      CourseTableJson(
        courseSemester: SemesterJson(year: year, semester: semester),
        studentId: studentId,
      );

  ExtraTable extraOf(String id, String label) => ExtraTable(
        id: id,
        label: label,
        table: tableOf('B10000000', '115', '1'),
        savedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  Future<TableChoice?> open(
    WidgetTester tester, {
    List<CourseTableJson> mine = const [],
    List<ExtraTable> shared = const [],
    List<ExtraTable> drafts = const [],
    String? currentLabel,
  }) async {
    TableChoice? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showTableSwitcherSheet(
              context: context,
              myTables: mine,
              shared: shared,
              drafts: drafts,
              currentLabel: currentLabel,
              labelOf: (t) => '${t.studentId} ${t.courseSemester.year}-'
                  '${t.courseSemester.semester}',
              summaryOf: (_) => '6 門課 · 13 學分',
              importedAtOf: (_) => '115-1 · 9/7 匯入',
              draftSummaryOf: (_) => '3 門課 · 9 學分',
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('三區都有資料時各自出現，目前那一份打勾', (tester) async {
    await open(
      tester,
      mine: [
        tableOf('B11000001', '115', '1'),
        tableOf('B11000001', '114', '2')
      ],
      shared: [extraOf('s1', 'B10000000')],
      drafts: [extraOf('d1', '115-1 加退選草稿')],
      currentLabel: 'B11000001 115-1',
    );

    expect(find.text(R.current.tableSwitcherMine), findsOneWidget);
    expect(find.text(R.current.tableSwitcherShared), findsOneWidget);
    expect(find.text(R.current.tableSwitcherDrafts), findsOneWidget);
    expect(find.text('B11000001 115-1'), findsOneWidget);
    expect(find.text('B10000000'), findsOneWidget);
    expect(find.text('115-1 加退選草稿'), findsOneWidget);
    // 只有目前那一份打勾。
    expect(find.byIcon(LucideIcons.check), findsOneWidget);
  });

  testWidgets('沒有他人課表時那一區整個不出現', (tester) async {
    await open(tester, mine: [tableOf('B11000001', '115', '1')]);
    expect(find.text(R.current.tableSwitcherShared), findsNothing);
    // 模擬課表那一區永遠在——就算沒有草稿，也要有「新增模擬課表」。
    expect(find.text(R.current.tableSwitcherDrafts), findsOneWidget);
    expect(find.text(R.current.simulationNew), findsOneWidget);
  });

  /// 開起來、點一列、把回傳值交出來。回傳值是在按鈕的 onPressed 裡收的，
  /// 所以這裡不 await 那一段，只等畫面 settle 之後再點。
  Future<TableChoice?> openAndTap(
    WidgetTester tester,
    String rowText, {
    List<CourseTableJson> mine = const [],
    List<ExtraTable> shared = const [],
    List<ExtraTable> drafts = const [],
  }) async {
    TableChoice? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showTableSwitcherSheet(
              context: context,
              myTables: mine,
              shared: shared,
              drafts: drafts,
              labelOf: (t) => '${t.studentId} ${t.courseSemester.year}-'
                  '${t.courseSemester.semester}',
              summaryOf: (_) => '6 門課 · 13 學分',
              importedAtOf: (_) => '115-1 · 9/7 匯入',
              draftSummaryOf: (_) => '3 門課 · 9 學分',
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(rowText));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('點自己的課表回 MyTableChoice，而且帶著那一份', (tester) async {
    final choice = await openAndTap(tester, 'B11000001 115-1',
        mine: [tableOf('B11000001', '115', '1')]);
    expect(choice, isA<MyTableChoice>());
    expect((choice as MyTableChoice).table.studentId, 'B11000001');
  });

  testWidgets('點草稿回 DraftChoice，點他人課表回 SharedChoice', (tester) async {
    expect(
        await openAndTap(tester, '115-1 加退選草稿',
            drafts: [extraOf('d1', '115-1 加退選草稿')]),
        isA<DraftChoice>());
    expect(
        await openAndTap(tester, 'B10000000',
            shared: [extraOf('s1', 'B10000000')]),
        isA<SharedChoice>());
  });

  testWidgets('新增模擬課表與管理課表各自回自己的 choice', (tester) async {
    expect(await openAndTap(tester, R.current.simulationNew),
        isA<NewDraftChoice>());
    expect(await openAndTap(tester, R.current.manageTablesTitle),
        isA<ManageTablesChoice>());
  });
}
