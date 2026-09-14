import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/controller/course_table/course_model.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/native/widget_bridge.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 小工具拿到的課表。extension 裡跑不了核心，這一份錯了桌面上就一直是錯的，沒有重新整理可以按。
CourseMainInfoJson course(String id, String name, Map<Day, String> time) {
  final full = {for (final d in Day.values) d: ''}..addAll(time);
  return CourseMainInfoJson(
    course: CourseMainJson(id: id, name: name, credits: '3', time: full),
  );
}

CourseTableJson table(List<CourseMainInfoJson> courses,
    {String studentId = 'B11230223', String semester = '115-1'}) {
  final parts = semester.split('-');
  final t = CourseTableJson(
    courseSemester: SemesterJson(year: parts[0], semester: parts[1]),
    studentId: studentId,
  );
  for (final c in courses) {
    expect(t.addCourseDetailByCourseInfo(c), isTrue);
  }
  return t;
}

void main() {
  setUpAll(() async {
    await loadTestL10n();
  });

  setUp(() {
    resetAppStatics();
    AuthSession.instance = FakeAuthSession();
    Model.instance.setAccount('B11230223');
  });

  test('沒登入或還沒有自己的課表時是空的', () async {
    expect(WidgetBridge().timetables(), isEmpty);

    await CourseModel()
        .saveCourse(table([course('CS1', '資料結構', {Day.monday: '34'})]));
    AuthSession.instance = FakeAuthSession(isSignedIn: false);

    expect(WidgetBridge().timetables(), isEmpty);
  });

  test('星期從週一算 1、時間是當天的分鐘數、連堂併成一段', () async {
    await CourseModel().saveCourse(table([
      course('CS1', '資料結構', {Day.monday: '34'}),
      course('CS2', '作業系統', {Day.friday: '2'}),
    ]));

    final widget = WidgetBridge().timetables().single;

    expect(widget.semester, '115-1');
    expect((widget.courseCount, widget.credits), (2, 6));
    expect(widget.days.map((d) => d.weekday), [1, 2, 3, 4, 5]);
    expect(widget.days.first.label, R.current.Monday);
    expect(widget.sections.first.start, 8 * 60 + 10);
    expect(
        widget.lessons.map(
            (l) => (l.weekday, l.firstSection, l.lastSection, l.start, l.end)),
        [
          (1, 2, 3, 10 * 60 + 20, 12 * 60 + 10),
          (5, 1, 1, 9 * 60 + 10, 10 * 60),
        ]);
    expect(widget.lessons.map((l) => (l.name, l.order)),
        [('資料結構', 0), ('作業系統', 1)]);
    expect(widget.lessons.first.classroom, isNull);
  });

  test('自己每一學期都給、新的在前；畫面上正在看別人的課表不影響', () async {
    await CourseModel().saveCourse(table(
        [course('CS1', '資料結構', {Day.monday: '34'})],
        semester: '114-2'));
    await CourseModel()
        .saveCourse(table([course('CS2', '作業系統', {Day.friday: '2'})]));
    await CourseModel().saveCourse(table(
        [course('CS9', '別人的課', {Day.tuesday: '2'})],
        studentId: 'B10000000',
        semester: '116-1'));

    final tables = WidgetBridge().timetables();

    expect(tables.map((t) => t.semester), ['115-1', '114-2']);
    expect(tables.first.lessons.single.name, '作業系統');
  });
}
