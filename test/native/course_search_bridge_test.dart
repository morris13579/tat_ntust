import 'dart:async';

import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/controller/course_table/course_model.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_department.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course/course_query_filter.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/native/course_search_bridge.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 導入其他課程在原生版的判斷：衝堂對誰算、哪些課被藏起來、加課失敗時課表有沒有被動到。
/// Swift 只照著畫，這些規則壞了，使用者會把排不進去的課加進課表。
CourseMainInfoJson course(
  String id,
  String name,
  Map<Day, String> time, {
  String category = '',
  String teacher = '',
  String classroom = '',
}) {
  final full = {for (final d in Day.values) d: ''}..addAll(time);
  return CourseMainInfoJson(
    course: CourseMainJson(
        id: id, name: name, credits: '3', category: category, time: full),
    teacher: [if (teacher.isNotEmpty) TeacherJson(name: teacher)],
    classroom: [if (classroom.isNotEmpty) ClassroomJson(name: classroom)],
  );
}

CourseTableJson table(List<CourseMainInfoJson> courses) {
  final t = CourseTableJson(
    courseSemester: SemesterJson(year: '115', semester: '1'),
    studentId: 'B11230223',
  );
  for (final c in courses) {
    expect(t.addCourseDetailByCourseInfo(c), isTrue);
  }
  return t;
}

CourseFilter filter(String keyword) => CourseFilter(
      keyword: keyword,
      level: ProgramLevel.all,
      foreignLanguageOnly: false,
      generalOnly: false,
      intensiveOnly: false,
      ntustOnly: false,
    );

void main() {
  setUpAll(() async => loadTestL10n());

  late CourseSearchBridge bridge;
  late List<(SemesterJson, CourseQueryFilter)> queries;
  late List<CourseMainInfoJson> found;

  setUp(() async {
    resetAppStatics();
    Model.instance.setAccount('B11230223');
    await CourseModel().saveCourse(table([
      course('CS3039701', '資料結構', {Day.monday: '34'}),
      course('CS3003302', '作業系統', {Day.friday: '2'}),
    ]));
    queries = [];
    found = [];
    bridge = CourseSearchBridge(query: (semester, filter) async {
      queries.add((semester, filter));
      return found;
    });
  });

  group('開頁', () {
    test('學期、預填課表上最多的系所、節次篩選是一到日與十四節', () {
      final start = bridge.start(null)!;

      expect(start.semester, '115-1');
      expect(start.keyword, 'CS');
      expect(start.days.map((d) => d.index), [0, 1, 2, 3, 4, 5, 6]);
      expect(start.days.first.label, '一');
      expect(start.sections.map((s) => s.index), List.generate(14, (i) => i));
    });

    test('課表上都是通識課時不預填', () async {
      await CourseModel().saveCourse(table([
        course('1101001', '國文', {Day.monday: '1'}),
      ]));

      expect(bridge.start(null)!.keyword, isNull);
    });

    test('還沒有課表時回 null', () {
      Model.instance.getCourseSetting().info = CourseTableJson();

      expect(bridge.start(null), isNull);
    });
  });

  group('查詢', () {
    test('條件照 CourseQueryFilter 送出去，學期是目前課表的', () async {
      await bridge.search(
        CourseFilter(
          keyword: '',
          department: CourseSearchOption(no: 'EE', name: '電機系'),
          dimension: GeDimension.c,
          level: ProgramLevel.master,
          foreignLanguageOnly: true,
          generalOnly: false,
          intensiveOnly: true,
          ntustOnly: false,
        ),
        true,
        [],
      );

      final (semester, sent) = queries.single;
      expect((semester.year, semester.semester), ('115', '1'));
      expect(sent.department?.no, 'EE');
      expect(sent.dimension, CourseDimension.c);
      expect(sent.level, CourseProgramLevel.master);
      expect(sent.foreignLanguageOnly, isTrue);
      expect(sent.intensiveOnly, isTrue);
      expect(
          sent.toRequestBody(semesterCode: '1151', language: 'zh')['CourseNo'],
          'EE',
          reason: '沒打關鍵字時系所代碼就是課號前綴');
    });

    test('衝堂的課預設藏起來；門數與衝堂數算的是全部', () async {
      found = [
        course('CS4001301', '演算法', {Day.monday: '4', Day.friday: '2'}),
        course('EE2001301', '電路學', {Day.tuesday: '12'},
            category: 'R', teacher: '王大明', classroom: 'EE-101'),
        course('CS3039701', '資料結構', {Day.monday: '34'}),
      ];

      final hidden = (await bridge.search(filter('CS'), true, []))!;
      expect(hidden.total, 3);
      expect(hidden.clashes, 1);
      expect(hidden.courses.map((c) => c.id), ['EE2001301', 'CS3039701']);

      final all = bridge.results(false, []);
      expect(all.courses.first.conflicts.map((c) => (c.courseName, c.slots)),
          [('資料結構', '一 4'), ('作業系統', '五 2')],
          reason: '撞到幾門就幾行，每一行列出撞到的節次');
      final ee = all.courses[1];
      expect((ee.credits, ee.requirement, ee.teacher, ee.slots, ee.classroom),
          ('3', CourseRequirement.compulsory, '王大明', '二 1·2', 'EE-101'));
      expect(all.courses.last.added, isTrue);
      expect(all.courses.last.conflicts, isEmpty,
          reason: '課表上本來就有的課不算跟自己衝堂');
    });

    test('節次篩選：每一格都要落在勾選的節次裡，沒有時間的課排除', () async {
      found = [
        course('EE2001301', '電路學', {Day.tuesday: '12'}),
        course('EE2002301', '電子學', {Day.tuesday: '123'}),
        course('PE1001001', '校隊', {}),
      ];
      await bridge.search(filter('EE'), true, []);

      final picked = bridge.results(true, [
        TimeSlot(day: Day.tuesday.index, section: SectionNumber.t_1.index),
        TimeSlot(day: Day.tuesday.index, section: SectionNumber.t_2.index),
      ]);
      expect(picked.courses.map((c) => c.id), ['EE2001301']);
      expect(bridge.results(true, []).courses, hasLength(3));
    });

    test('被後來的查詢蓋過就回 null，之後以後來的結果為準', () async {
      final slow = Completer<List<CourseMainInfoJson>>();
      var calls = 0;
      final racing = CourseSearchBridge(query: (semester, filter) {
        calls++;
        return calls == 1
            ? slow.future
            : Future.value([
                course('EE2001301', '電路學', {Day.tuesday: '12'})
              ]);
      });

      final first = racing.search(filter('CS'), true, []);
      final second = await racing.search(filter('EE'), true, []);
      slow.complete([
        course('CS4001301', '演算法', {Day.monday: '4'})
      ]);

      expect(await first, isNull);
      expect(second!.courses.map((c) => c.id), ['EE2001301']);
      expect(racing.results(false, []).courses.map((c) => c.id), ['EE2001301']);
    });
  });

  group('加課與移除', () {
    test('加進目前的課表並存起來，搜尋結果變成已加入', () async {
      found = [
        course('EE2001301', '電路學', {Day.tuesday: '12'})
      ];
      await bridge.search(filter('EE'), true, []);

      final change = await bridge.add('EE2001301');

      expect(change.applied, isTrue);
      expect(change.grid!.courseCount, 3);
      expect(
          change.grid!.cells
              .where((c) => c.courseId == 'EE2001301')
              .map((c) => c.selected),
          everyElement(isFalse),
          reason: '自己加的課不是選課系統裡的課');
      expect(CourseModel().getCourseSettingInfo()!.getCourseIdList(),
          contains('EE2001301'));
      expect(bridge.results(true, []).courses.single.added, isTrue);
    });

    test('衝堂的課加不進去，課表不動', () async {
      found = [
        course('CS4001301', '演算法', {Day.monday: '4'})
      ];
      await bridge.search(filter('CS'), false, []);

      final change = await bridge.add('CS4001301');

      expect(change.applied, isFalse);
      expect(change.grid!.courseCount, 2);
      expect(CourseModel().getCourseSettingInfo()!.getCourseIdList(),
          isNot(contains('CS4001301')));
    });

    test('同一個課號回兩筆時併成一門：其中一筆衝堂就整門藏起來、加不進去', () async {
      found = [
        course('EE2001301', '電路學', {Day.tuesday: '1'}),
        course('EE2001301', '電路學', {Day.monday: '4'}),
      ];
      await bridge.search(filter('EE'), true, []);

      expect(bridge.results(true, []).courses, isEmpty);
      expect(bridge.results(false, []).courses.single.conflicts, isNotEmpty);
      final change = await bridge.add('EE2001301');
      expect(change.applied, isFalse);
      expect(CourseModel().getCourseSettingInfo()!.getCourseIdList(),
          isNot(contains('EE2001301')));
    });

    test('同一個課號回兩筆、都不衝堂時列一門，加進去每一節都在課表上', () async {
      found = [
        course('EE2001301', '電路學', {Day.tuesday: '1'}),
        course('EE2001301', '電路學', {Day.thursday: '5'}),
      ];
      await bridge.search(filter('EE'), true, []);

      expect(bridge.results(true, []).courses.single.id, 'EE2001301');
      expect((await bridge.add('EE2001301')).applied, isTrue);
      final map = CourseModel().getCourseSettingInfo()!.courseInfoMap;
      expect(map[Day.tuesday]![SectionNumber.t_1]?.main.course.id, 'EE2001301');
      expect(map[Day.thursday]![SectionNumber.t_5]?.main.course.id, 'EE2001301');
    });

    test('不在這次結果裡的課號加不進去', () async {
      expect((await bridge.add('XX0000000')).applied, isFalse);
    });

    test('移除之後搜尋結果變回未加入', () async {
      found = [
        course('CS3039701', '資料結構', {Day.monday: '34'})
      ];
      await bridge.search(filter('CS'), true, []);

      final change = await bridge.remove('CS3039701');

      expect(change.applied, isTrue);
      expect(change.grid!.courseCount, 1);
      expect(bridge.results(true, []).courses.single.added, isFalse);
    });
  });

  test('學院與系所：名字依介面語言挑一份，抓不到回空清單', () async {
    final catalog = CourseSearchBridge(
      loadColleges: () async =>
          [const CollegeJson(no: '1', name: '電資學院', engName: 'EECS')],
      loadDepartments: (no) async => null,
    );

    expect((await catalog.colleges()).map((c) => (c.no, c.name)),
        [('1', '電資學院')]);
    expect(await catalog.departments('1'), isEmpty);
  });
}
