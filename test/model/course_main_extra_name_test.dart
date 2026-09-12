import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_test/flutter_test.dart';

/// 老師與教室名稱的組字。
///
/// 這兩個 getter 先前每一筆都補一個尾隨空白，名字是空字串時回傳的就是單一個
/// 空白——`isNotEmpty` 是真、畫面上卻什麼都沒有，課表格子的選單因此在時間
/// 前面多排一格空位。呼叫端本來各自補 `.trim()` 繞過去。
void main() {
  CourseMainInfoJson info({
    List<String> teachers = const [],
    List<String> classrooms = const [],
  }) {
    final json = CourseMainInfoJson();
    for (final name in teachers) {
      json.teacher.add(TeacherJson(name: name, href: ''));
    }
    for (final name in classrooms) {
      json.classroom.add(ClassroomJson(name: name, href: ''));
    }
    return json;
  }

  test('名字是空字串時回空字串，不是一個空白', () {
    // querycourse 沒給教室時 ClassroomJson.name 就是空的。
    final one = info(teachers: [''], classrooms: ['']);
    expect(one.getTeacherName(), isEmpty);
    expect(one.getClassroomName(), isEmpty);
  });

  test('一筆的時候沒有尾隨空白', () {
    final one = info(teachers: ['王老師'], classrooms: ['TR-413-1']);
    expect(one.getTeacherName(), '王老師');
    expect(one.getClassroomName(), 'TR-413-1');
  });

  test('多筆以單一空白隔開', () {
    final many = info(teachers: ['王老師', '李老師'], classrooms: ['A-1', 'B-2']);
    expect(many.getTeacherName(), '王老師 李老師');
    expect(many.getClassroomName(), 'A-1 B-2');
  });

  test('空的那一筆會被跳過，不會留下連續空白', () {
    final mixed = info(teachers: ['王老師', '', '李老師']);
    expect(mixed.getTeacherName(), '王老師 李老師');
  });

  test('完全沒有資料時是空字串', () {
    expect(info().getTeacherName(), isEmpty);
    expect(info().getClassroomName(), isEmpty);
  });
}
