import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course/course_query_filter.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/ui/pages/course_table/simulation/course_search_page.dart';
import 'package:flutter_app/ui/pages/course_table/simulation/simulation_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// 搜尋頁一進來不能是空白的。
///
/// 預設帶使用者自己的系所（課號前兩碼），不是空條件——`searchCourse` 對空條件
/// 直接回空陣列，全校一學期又有 4282 門，兩邊都不是使用者要的。
void main() {
  setUpAll(() async {
    await R.load(const Locale('zh', 'TW'));
  });

  CourseMainInfoJson courseOf(String id, String name) => CourseMainInfoJson(
        course: CourseMainJson(
          id: id,
          name: name,
          credits: '3',
          time: {for (final day in Day.values) day: ''},
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

  /// 回傳送進 search 的條件，沒被呼叫就是 null。
  Future<List<CourseQueryFilter>> pump(
    WidgetTester tester, {
    required CourseTableJson table,
    List<CourseMainInfoJson> results = const [],
  }) async {
    final calls = <CourseQueryFilter>[];
    await tester.pumpWidget(GetMaterialApp(
      home: CourseSearchPage(
        editor: SimulationEditor(
          draft: table,
          base: null,
          semester: SemesterJson(year: '115', semester: '1'),
          add: (_) {},
          remove: (_) {},
          contains: (_) => false,
        ),
        search: (filter) async {
          calls.add(filter);
          return results;
        },
        loadColleges: () async => [],
        loadDepartments: (_) async => [],
      ),
    ));
    await tester.pumpAndSettle();
    return calls;
  }

  testWidgets('一進來就用自己的系所查，不用先打字', (tester) async {
    final calls = await pump(
      tester,
      table: tableOf([
        courseOf('CS1234', '資料結構'),
        courseOf('CS5678', '演算法'),
        courseOf('GE0001', '通識'),
      ]),
      results: [courseOf('CS9999', '編譯器設計')],
    );

    expect(calls, hasLength(1), reason: '沒有自動查詢');
    expect(calls.single.courseNo, 'CS', reason: '眾數是 CS，不該用別的前綴');
    expect(find.text('編譯器設計'), findsOneWidget);
  });

  testWidgets('關鍵字欄位會填上那兩碼，使用者知道要清掉什麼', (tester) async {
    await pump(tester, table: tableOf([courseOf('AE1000', '航太概論')]));

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller?.text, 'AE');
  });

  testWidgets('課表是空的就不自動查，維持原本的空狀態', (tester) async {
    final calls = await pump(tester, table: tableOf([]));

    expect(calls, isEmpty);
  });

  testWidgets('只有數字開頭的課號不算系所，不拿它去查', (tester) async {
    // 通識與共同科目的課號長這樣，拿它當系所會查出一批不相干的課。
    final calls = await pump(tester, table: tableOf([courseOf('1234567', '體育')]));

    expect(calls, isEmpty);
  });
}
