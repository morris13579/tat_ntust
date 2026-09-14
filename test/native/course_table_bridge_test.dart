import 'package:flutter_app/generated/core_api.g.dart' show TransferProgress;
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/controller/course_table/course_model.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/native/classroom_bridge.dart';
import 'package:flutter_app/src/native/course_table_bridge.dart';
import 'package:flutter_app/src/repository/ntust_repository.dart';
import 'package:flutter_app/src/store/extra_table_store.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/classroom_availability.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sprintf/sprintf.dart';

import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 原生版課表頁拿到的東西。哪幾天、哪幾節要顯示，分享碼、他人課表與我的課表怎麼存，
/// 都是 Dart 的判斷，Swift 照著畫——這些規則壞了，原生版會靜靜地少一欄或匯入錯的課表。
CourseMainInfoJson course(String id, String name, Map<Day, String> time) {
  final full = {for (final d in Day.values) d: ''}..addAll(time);
  return CourseMainInfoJson(
    course: CourseMainJson(id: id, name: name, credits: '3', time: full),
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

List<CourseMainInfoJson> weekdays() => [
      course('CS3039701', '資料結構', {Day.monday: '34'}),
      course('CS3003302', '作業系統', {Day.friday: '2'}),
    ];

/// 補課名一門回報一次，查到什麼就回什麼。
class _FakeNtust extends NtustRepository {
  List<CourseMainInfoJson> courses = const [];

  @override
  Future<List<CourseMainInfoJson>> restoreSharedCourses(
    SemesterJson semester,
    List<String> courseIds, {
    void Function(int done, int total)? onProgress,
  }) async {
    for (var i = 0; i < courseIds.length; i++) {
      onProgress?.call(i + 1, courseIds.length);
    }
    return courses;
  }
}

void main() {
  setUpAll(() async {
    await loadTestL10n();
    await initializeDateFormatting();
  });

  group('空堂格', () {
    test('帶著最近的那一天與那一節的時間；對不到任何一天的那一欄回 null', () {
      resetAppStatics();
      final bridge = CourseTableBridge();

      final slot = bridge.emptySlot(0, 2)!;

      expect(slot.date,
          ClassroomBridge.dateKey(ClassroomAvailability.dateForWeekday(0)!));
      expect(slot.section, 2);
      expect(slot.title, contains('第'));
      expect(slot.subtitle, endsWith('空堂'));
      expect(bridge.emptySlot(7, 2), isNull);
      expect(bridge.emptySlot(0, 99), isNull);
    });
  });

  group('格線', () {
    test('沒有課的週末、「其它」、中午與晚上的節次都收掉', () {
      final grid = CourseTableBridge.toGrid(table(weekdays()));

      expect(grid.days.map((d) => d.index), [0, 1, 2, 3, 4]);
      expect(grid.sections.map((s) => s.index), [0, 1, 2, 3, 5, 6, 7, 8, 9]);
    });

    test('週末有課就顯示那一天', () {
      final grid = CourseTableBridge.toGrid(table([
        course('PE0000001', '體育', {Day.saturday: '1'}),
      ]));

      expect(grid.days.map((d) => d.index), contains(Day.saturday.index));
      expect(grid.days.map((d) => d.index), isNot(contains(Day.sunday.index)));
    });

    test('一門課佔幾格就有幾個 cell，同一門課同一個 order', () {
      final grid = CourseTableBridge.toGrid(table(weekdays()));

      final cs1 = grid.cells.where((c) => c.courseId == 'CS3039701').toList();
      expect(cs1.map((c) => (c.day, c.section)), [(0, 2), (0, 3)]);
      expect(cs1.map((c) => c.order).toSet(), hasLength(1));
      expect(grid.cells.singleWhere((c) => c.courseId == 'CS3003302').order,
          isNot(cs1.first.order));
    });

    test('摘要與學期字串', () {
      final grid = CourseTableBridge.toGrid(table(weekdays()));

      expect(grid.studentId, 'B11230223');
      expect(grid.semester, '115-1');
      expect(grid.courseCount, 2);
      expect(grid.credits, 6);
    });

    test('節次標籤與時間和 CourseTableControl 同一份：中午之後那一格是第六節', () {
      final grid = CourseTableBridge.toGrid(table(weekdays()));

      final afterNoon = grid.sections.singleWhere((s) => s.index == 5);
      expect(afterNoon.label, '6');
      expect(afterNoon.time, '13:20 - 14:10');
    });

    test('沒有老師與教室時送 null，不送空字串', () {
      final cell = CourseTableBridge.toGrid(table(weekdays())).cells.first;

      expect(cell.teacher, isNull);
      expect(cell.classroom, isNull);
    });

    test('學期字串解析', () {
      expect(CourseTableBridge.parseSemester('115-1')?.year, '115');
      expect(CourseTableBridge.parseSemester('115-1')?.semester, '1');
      expect(CourseTableBridge.parseSemester('1151'), isNull);
    });
  });

  group('分享、他人課表與我的課表', () {
    late CourseTableBridge bridge;
    final progress = <TransferProgress>[];

    setUp(() async {
      final stores = resetAppStatics();
      progress.clear();
      bridge =
          CourseTableBridge(null, ExtraTableStore(stores.plain), progress.add);
      Model.instance.setAccount('B11230223');
      await CourseModel().saveCourse(table(weekdays()));
    });

    test('分享碼解得回同一份課表：學號、學期、門數與節次', () {
      final share = bridge.share()!;

      final preview = bridge.previewShareCode(share.qr)!;
      expect(preview.studentId, 'B11230223');
      expect(preview.semester, '115-1');
      expect(preview.courseCount, 2);
      expect(preview.courses.first.slots, '一 3·4');
      expect(bridge.previewShareCode(share.code)?.courseCount, 2,
          reason: '「複製代碼」複製的是不帶網址前綴的那一段，貼上時也要認得');
    });

    test('不是 TAT 的代碼回 null', () {
      expect(bridge.previewShareCode('https://example.com/qr'), isNull);
      expect(bridge.previewShareCode(''), isNull);
    });

    test('匯入之後出現在他人課表、格子離線就畫得出來，刪掉就沒了', () async {
      final info = (await bridge.importShareCode(bridge.share()!.code))!;

      expect(info.label, 'B11230223');
      expect(info.semester, '115-1');
      expect(info.courseCount, 2);
      expect((await bridge.sharedTables()).map((t) => t.id), [info.id]);
      expect((await bridge.sharedTable(info.id))!.cells, hasLength(3));

      await bridge.deleteSharedTable(info.id);
      expect(await bridge.sharedTables(), isEmpty);
    });

    test('補課名時一門一門報「補課名 x/y」，補完的課畫得出來', () async {
      final info = (await bridge.importShareCode(bridge.share()!.code))!;
      NtustRepository.instance = _FakeNtust()..courses = weekdays();
      addTearDown(() => NtustRepository.instance = NtustRepository());

      final grid = await bridge.restoreSharedTable(info.id);

      final key = 'restore-${info.id}';
      expect(progress.map((p) => (p.key, p.label)), [
        (key, sprintf(R.current.importRestoring, [0, 2])),
        (key, sprintf(R.current.importRestoring, [1, 2])),
        (key, sprintf(R.current.importRestoring, [2, 2])),
      ]);
      expect(progress.last.progress, 1.0);
      expect(grid?.cells, hasLength(3));
    });

    test('我的課表：列得出來、套用得回來、刪得掉', () async {
      expect(bridge.myTables().map((t) => (t.studentId, t.semester)),
          [('B11230223', '115-1')]);
      expect((await bridge.applyMyTable('B11230223', '115-1'))?.courseCount, 2);
      expect(await bridge.applyMyTable('B11230223', '114-2'), isNull);

      await bridge.deleteMyTable('B11230223', '115-1');
      expect(bridge.myTables(), isEmpty);
    });
  });

  group('課程格子的動作', () {
    late CourseTableBridge bridge;

    setUp(() async {
      resetAppStatics();
      bridge = CourseTableBridge();
      Model.instance.setAccount('B11230223');
      await CourseModel().saveCourse(table(weekdays()));
    });

    test('移除點到的那門課並存回去', () async {
      final grid = await bridge.removeCourse(0, 2);

      expect(grid!.cells.map((c) => c.courseId).toSet(), {'CS3003302'});
      expect(bridge.current()!.courseCount, 1, reason: '下次開課表還是少那一門');
    });

    test('改課號：那門課佔的每一格都換掉，前後空白不算', () async {
      final grid = await bridge.editCourseId(0, 3, ' CS9999999 ');

      expect(
          grid!.cells
              .where((c) => c.courseId == 'CS9999999')
              .map((c) => (c.day, c.section)),
          [(0, 2), (0, 3)]);
      expect(bridge.current()!.cells.where((c) => c.courseId == 'CS3039701'),
          isEmpty);
    });

    test('點到空格或超出範圍回 null，課表不動', () async {
      expect(await bridge.removeCourse(2, 0), isNull);
      expect(await bridge.editCourseId(9, 99, 'X'), isNull);
      expect(bridge.current()!.courseCount, 2);
    });
  });
}
