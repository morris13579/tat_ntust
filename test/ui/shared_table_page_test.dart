import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/course_config.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/store/extra_table_store.dart';
import 'package:flutter_app/src/store/key_value_store.dart';
import 'package:flutter_app/src/util/course_table_control.dart';
import 'package:flutter_app/ui/pages/course_table/share/shared_table_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// 他人課表的格線要跟自己的課表一樣填滿頁面：以前每一列寫死 56，節數少的課表底下空一大截。
void main() {
  setUpAll(() async {
    await R.load(const Locale('zh', 'TW'));
  });

  setUp(() {
    ExtraTableStore.instance = ExtraTableStore(InMemoryKeyValueStore());
  });

  testWidgets('列高照可用高度分成九節，跟課表頁一樣', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final table = CourseTableJson(
      courseSemester: SemesterJson(year: '115', semester: '1'),
      studentId: 'B11000001',
    );
    table.addCourseDetailByCourseInfo(CourseMainInfoJson(
      course: CourseMainJson(
        id: 'CS3039701',
        name: '資料結構',
        credits: '3',
        time: {for (final day in Day.values) day: day == Day.monday ? '34' : ''},
      ),
    ));

    await tester.pumpWidget(GetMaterialApp(
      home: SharedTablePage(
        shared: ExtraTable(
          id: 'shared-1',
          label: 'B11000001',
          table: table,
          savedAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      ),
    ));
    await tester.pump();

    final control = CourseTableControl()..set(table);
    final day = control.getDayString(control.getDayIntList.first);
    final section = control.getSectionString(control.getSectionIntList.first);
    final headerTop = tester
        .getTopLeft(
            find.ancestor(of: find.text(day), matching: find.byType(SizedBox)).first)
        .dy;
    final rowHeight = tester
        .getSize(find
            .ancestor(of: find.text(section), matching: find.byType(Container))
            .first)
        .height;

    expect(
        rowHeight,
        closeTo(
            (800 - headerTop - CourseConfig.dayHeight) /
                CourseConfig.showCourseTableNum,
            0.5));
    expect(rowHeight, greaterThan(56));
  });
}
