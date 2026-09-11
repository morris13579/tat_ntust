import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/store/extra_table_store.dart';
import 'package:flutter_app/src/store/key_value_store.dart';
import 'package:flutter_app/ui/pages/course_table/simulation/course_search_page.dart';
import 'package:flutter_app/ui/pages/course_table/simulation/simulation_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// 模擬排課的兩件事：草稿疊在實際課表上、以及搜尋頁看得到衝堂。
void main() {
  setUpAll(() async {
    await R.load(const Locale('zh', 'TW'));
  });

  setUp(() {
    ExtraTableStore.instance = ExtraTableStore(InMemoryKeyValueStore());
  });

  CourseMainInfoJson courseOf(String id, String name, Map<Day, String> time) =>
      CourseMainInfoJson(
        course: CourseMainJson(
          id: id,
          name: name,
          credits: '3',
          time: {for (final day in Day.values) day: time[day] ?? ''},
        ),
      );

  CourseTableJson tableOf(List<CourseMainInfoJson> courses) {
    final table = CourseTableJson(
      courseSemester: SemesterJson(year: '115', semester: '1'),
      studentId: 'B11000001',
    );
    for (final course in courses) {
      table.addCourseDetailByCourseInfo(course);
    }
    return table;
  }

  ExtraTable draftOf(CourseTableJson table) => ExtraTable(
        id: 'draft-1',
        label: '115-1 加退選草稿',
        table: table,
        savedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  Future<void> pumpSimulation(
    WidgetTester tester, {
    required CourseTableJson base,
    required CourseTableJson draft,
  }) async {
    await tester.pumpWidget(GetMaterialApp(
      home: SimulationPage(
        draft: draftOf(draft),
        base: base,
        openSearch: (_, __) async {},
      ),
    ));
    await tester.pump();
  }

  group('模擬課表', () {
    testWidgets('草稿是空的時候不出現衝堂橫幅，摘要寫 0 門', (tester) async {
      await pumpSimulation(
        tester,
        base: tableOf([
          courseOf('CS3003302', '離散數學', {Day.thursday: '3 4'})
        ]),
        draft: tableOf([]),
      );
      expect(find.textContaining('處衝堂'), findsNothing);
      expect(find.textContaining('草稿 0 門'), findsOneWidget);
      // 實際課表的課還是要畫出來，那是排課的底圖。
      expect(find.text('離散數學'), findsWidgets);
    });

    testWidgets('草稿撞到實際課表 → 橫幅寫幾處、寫在哪幾節', (tester) async {
      await pumpSimulation(
        tester,
        base: tableOf([
          courseOf('CS3003302', '離散數學', {Day.thursday: '3 4'})
        ]),
        draft: tableOf([
          courseOf('AC5012701', '矩陣理論', {Day.thursday: '3 4'})
        ]),
      );
      // 兩節都撞 → 2 處。橫幅與底部摘要各講一次，所以是 findsWidgets。
      expect(find.textContaining('2 處衝堂'), findsWidgets);
      expect(find.textContaining('四'), findsWidgets);
    });

    testWidgets('同一門課同時在實際課表與草稿裡不算衝堂', (tester) async {
      final course = courseOf('CS3003302', '離散數學', {Day.thursday: '3 4'});
      await pumpSimulation(
        tester,
        base: tableOf([course]),
        draft: tableOf([
          courseOf('CS3003302', '離散數學', {Day.thursday: '3 4'})
        ]),
      );
      expect(find.textContaining('處衝堂'), findsNothing);
    });

    testWidgets('沒有衝堂時摘要寫「沒有衝堂」', (tester) async {
      await pumpSimulation(
        tester,
        base: tableOf([
          courseOf('CS3003302', '離散數學', {Day.thursday: '3 4'})
        ]),
        draft: tableOf([
          courseOf('AC5012701', '矩陣理論', {Day.monday: '1 2'})
        ]),
      );
      expect(find.textContaining('處衝堂'), findsNothing);
      expect(find.textContaining('沒有衝堂'), findsOneWidget);
      expect(find.textContaining('草稿 1 門'), findsOneWidget);
    });
  });

  group('搜尋課程', () {
    Future<void> pumpSearch(
      WidgetTester tester, {
      required CourseTableJson base,
      required CourseTableJson draft,
      required List<CourseMainInfoJson> results,
    }) async {
      final added = <String>{};
      await tester.pumpWidget(GetMaterialApp(
        home: CourseSearchPage(
          editor: SimulationEditor(
            draft: draft,
            base: base,
            semester: SemesterJson(year: '115', semester: '1'),
            add: (course) => added.add(course.course.id),
            remove: added.remove,
            contains: added.contains,
          ),
          search: (_) async => results,
          loadColleges: () async => [],
          loadDepartments: (_) async => [],
        ),
      ));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'x');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
    }

    testWidgets('會撞到的課，卡片上寫是跟哪一門、哪一節撞', (tester) async {
      await pumpSearch(
        tester,
        base: tableOf([
          courseOf('CS3003302', '離散數學', {Day.thursday: '3 4'})
        ]),
        draft: tableOf([]),
        results: [
          courseOf('AC5012701', '矩陣理論', {Day.thursday: '3 4'})
        ],
      );
      // 預設是「只看不衝堂」，要先關掉才看得到會撞的那一門。
      await tester.tap(find.text(R.current.courseSearchHideConflict));
      await tester.pumpAndSettle();

      expect(find.textContaining('與 離散數學'), findsOneWidget);
      // 撞到的節次要全部列出來，只印第一節會讓人以為退一節就排得進去。
      expect(find.textContaining('四 3·4'), findsWidgets);
    });

    testWidgets('不會撞的課沒有紅字', (tester) async {
      await pumpSearch(
        tester,
        base: tableOf([
          courseOf('CS3003302', '離散數學', {Day.thursday: '3 4'})
        ]),
        draft: tableOf([]),
        results: [
          courseOf('AC5012701', '矩陣理論', {Day.monday: '1 2'})
        ],
      );
      // 「只看不衝堂」那顆籤本身就含「衝堂」，所以只找卡片上那一行紅字。
      expect(find.textContaining('與 '), findsNothing);
      expect(find.text('矩陣理論'), findsOneWidget);
    });

    testWidgets('「只看不衝堂」把會撞的那一門收起來', (tester) async {
      await pumpSearch(
        tester,
        base: tableOf([
          courseOf('CS3003302', '離散數學', {Day.thursday: '3 4'})
        ]),
        draft: tableOf([]),
        results: [
          courseOf('AC5012701', '矩陣理論', {Day.thursday: '3 4'}),
          courseOf('AC5313701', '嵌入式系統', {Day.monday: '1 2'}),
        ],
      );
      // 預設就是「只看不衝堂」，所以會撞的那一門一開始就不在。
      expect(find.text('矩陣理論'), findsNothing);
      expect(find.text('嵌入式系統'), findsOneWidget);

      await tester.tap(find.text(R.current.courseSearchHideConflict));
      await tester.pumpAndSettle();

      expect(find.text('矩陣理論'), findsOneWidget, reason: '關掉之後全部都要看得到');
      expect(find.text('嵌入式系統'), findsOneWidget);
    });

    testWidgets('節次印成「四 3·4」，不是內部格式的「四_34」', (tester) async {
      await pumpSearch(
        tester,
        base: tableOf([]),
        draft: tableOf([]),
        results: [
          courseOf('AC5012701', '矩陣理論', {Day.thursday: '3 4'})
        ],
      );
      expect(find.textContaining('四 3·4'), findsOneWidget);
      expect(find.textContaining('_'), findsNothing);
    });
    group('節次篩選', () {
      // querycourse 的節次篩選不在伺服器端，官方前端也是拿回結果自己比對的。
      // 這裡用「完全落在所選節次」的語意：勾 1、2 是因為那兩節有空。
      Future<void> pickSlots(WidgetTester tester, List<String> labels) async {
        await tester.tap(find.text(R.current.courseSearchSlot));
        await tester.pumpAndSettle();
        for (final l in labels) {
          await tester.tap(find.text(l).last);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text(R.current.courseSearchFilterApply));
        await tester.pumpAndSettle();
      }

      testWidgets('勾整排第 1 節，只留下完全落在第 1 節的課', (tester) async {
        await pumpSearch(
          tester,
          base: tableOf([]),
          draft: tableOf([]),
          results: [
            courseOf('AA0000001', '只有一節', {Day.monday: '1'}),
            courseOf('AA0000002', '跨到第二節', {Day.monday: '1 2'}),
            courseOf('AA0000003', '別的時間', {Day.tuesday: '5'}),
          ],
        );
        expect(find.text('只有一節'), findsOneWidget);
        expect(find.text('跨到第二節'), findsOneWidget);

        // 節次頁的列標頭「1」點下去＝整排第 1 節全選。
        await pickSlots(tester, ['1']);

        expect(find.text('只有一節'), findsOneWidget);
        expect(find.text('跨到第二節'), findsNothing, reason: '橫跨到沒勾的節次');
        expect(find.text('別的時間'), findsNothing);
      });

      testWidgets('沒有排定時間的課不算「在某幾節」', (tester) async {
        await pumpSearch(
          tester,
          base: tableOf([]),
          draft: tableOf([]),
          results: [courseOf('PE1003701', '體育校隊', {})],
        );
        expect(find.text('體育校隊'), findsOneWidget);

        await pickSlots(tester, ['1']);

        expect(find.text('體育校隊'), findsNothing);
      });

      testWidgets('一格都沒勾就是不篩', (tester) async {
        await pumpSearch(
          tester,
          base: tableOf([]),
          draft: tableOf([]),
          results: [courseOf('AA0000003', '別的時間', {Day.tuesday: '5'})],
        );

        await tester.tap(find.text(R.current.courseSearchSlot));
        await tester.pumpAndSettle();
        await tester.tap(find.text(R.current.courseSearchFilterApply));
        await tester.pumpAndSettle();

        expect(find.text('別的時間'), findsOneWidget);
      });
    });
  });

  group('草稿清單 sheet', () {
    // 課名在背後的格子裡也會出現（而且跨幾節就出現幾次），所以一律用課號認：
    // 只有 sheet 的副標會印課號。
    testWidgets('摘要那一列點下去，攤開目前選的課', (tester) async {
      final base = tableOf([courseOf('CS1001', '線性代數', {Day.monday: '3 4'})]);
      final draft = tableOf([
        courseOf('CS2002', '編譯器設計', {Day.wednesday: '6 7'}),
        courseOf('CS2003', '機器學習', {Day.thursday: '3'}),
      ]);
      await pumpSimulation(tester, base: base, draft: draft);

      expect(find.textContaining('CS2002'), findsNothing, reason: '還沒展開');

      await tester.tap(find.textContaining(RegExp(r'^草稿')));
      await tester.pumpAndSettle();

      expect(find.textContaining('CS2002'), findsOneWidget);
      expect(find.textContaining('CS2003'), findsOneWidget);
      expect(find.textContaining('CS1001'), findsNothing,
          reason: '實際課表的課不屬於草稿清單');
    });

    testWidgets('一門課跨好幾節只列一次', (tester) async {
      final draft =
          tableOf([courseOf('CS2002', '編譯器設計', {Day.wednesday: '6 7 8'})]);
      await pumpSimulation(tester, base: tableOf([]), draft: draft);

      await tester.tap(find.textContaining(RegExp(r'^草稿')));
      await tester.pumpAndSettle();

      expect(find.textContaining('CS2002'), findsOneWidget);
    });

    testWidgets('在清單裡移除，格子上那一門就跟著消失', (tester) async {
      final draft =
          tableOf([courseOf('CS2002', '編譯器設計', {Day.wednesday: '6 7'})]);
      await pumpSimulation(tester, base: tableOf([]), draft: draft);

      await tester.tap(find.textContaining(RegExp(r'^草稿')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(R.current.simulationRemoveCourse));
      await tester.pumpAndSettle();

      expect(find.textContaining('CS2002'), findsNothing, reason: 'sheet 裡先消失');

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('編譯器設計'), findsNothing, reason: '格子上也要沒有');
    });

    testWidgets('草稿是空的就顯示空狀態，不是一片空白', (tester) async {
      await pumpSimulation(tester, base: tableOf([]), draft: tableOf([]));

      await tester.tap(find.textContaining(RegExp(r'^草稿')));
      await tester.pumpAndSettle();

      expect(find.text(R.current.simulationEmptyHint), findsWidgets);
    });
  });

}
