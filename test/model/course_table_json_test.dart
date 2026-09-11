import 'dart:convert';

import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_test/flutter_test.dart';

/// 建立一門「時間表已填滿七天」的課程。
/// `addCourseDetailByCourseInfo` 會對 Day.values[0..6] 直接做 `time[day]!`，
/// 少一天就會炸，所以這裡預設把每一天都補上空字串。
CourseMainInfoJson mainInfo(
  String id,
  String name, {
  String credits = '',
  Map<Day, String>? time,
}) {
  final Map<Day, String> fullTime = {};
  for (final Day d in Day.values) {
    fullTime[d] = '';
  }
  if (time != null) fullTime.addAll(time);
  return CourseMainInfoJson(
    course: CourseMainJson(
      id: id,
      name: name,
      credits: credits,
      time: fullTime,
    ),
  );
}

CourseInfoJson info(
  String id,
  String name, {
  String credits = '',
  Map<Day, String>? time,
}) =>
    CourseInfoJson(main: mainInfo(id, name, credits: credits, time: time));

/// 特徵化測試：凍結 CourseTableJson 與 Day / SectionNumber 目前的行為
/// （含已知的怪異之處），任何重構若改變課表寫入、學分計算或持久化格式，
/// CI 都會紅燈。
void main() {
  group('setCourseDetailByTime', () {
    test('一般情況：課程被放進指定的 Day 與 SectionNumber', () {
      final table = CourseTableJson();
      table.setCourseDetailByTime(
          Day.monday, SectionNumber.t_1, info('A1', '微積分'));

      expect(
          table
              .getCourseDetailByTime(Day.monday, SectionNumber.t_1)
              .main
              .course
              .id,
          'A1');
      expect(table.courseInfoMap[Day.tuesday], isEmpty);
    });

    test('時段衝突時「靜默保留」原課程，新課程直接被丟掉且沒有任何回報', () {
      // 已知問題：setCourseDetailByTime 回傳 void，呼叫端無從得知寫入失敗，
      // 所以加選失敗沒辦法提示使用者。
      final table = CourseTableJson();
      table.setCourseDetailByTime(
          Day.monday, SectionNumber.t_1, info('A1', '微積分'));
      table.setCourseDetailByTime(
          Day.monday, SectionNumber.t_1, info('B2', '線性代數'));

      expect(
          table
              .getCourseDetailByTime(Day.monday, SectionNumber.t_1)
              .main
              .course
              .id,
          'A1');
    });

    test('課名含「實習」或「Lab for」時會反過來覆蓋掉原本的課程', () {
      final table = CourseTableJson();

      table.setCourseDetailByTime(
          Day.monday, SectionNumber.t_1, info('A1', '電子學'));
      table.setCourseDetailByTime(
          Day.monday, SectionNumber.t_1, info('A2', '電子學實習'));
      expect(
          table
              .getCourseDetailByTime(Day.monday, SectionNumber.t_1)
              .main
              .course
              .id,
          'A2');

      table.setCourseDetailByTime(
          Day.tuesday, SectionNumber.t_3, info('B1', 'Electronics'));
      table.setCourseDetailByTime(
          Day.tuesday, SectionNumber.t_3, info('B2', 'Lab for Electronics'));
      expect(
          table
              .getCourseDetailByTime(Day.tuesday, SectionNumber.t_3)
              .main
              .course
              .id,
          'B2');
    });

    test('Day.unKnown 會忽略傳入的節次，改塞進第一個空節次（t_1）', () {
      // 已知怪異行為：傳 t_UnKnown 進來也不會用它，永遠從 SectionNumber.values
      // 的第一個空位開始填，所以「沒有時間的課」其實躺在 unKnown/t_1、t_2…。
      final table = CourseTableJson();
      table.setCourseDetailByTime(
          Day.unKnown, SectionNumber.t_UnKnown, info('X1', '無時間課程一'));
      table.setCourseDetailByTime(
          Day.unKnown, SectionNumber.t_UnKnown, info('X2', '無時間課程二'));

      expect(table.courseInfoMap[Day.unKnown]!.keys.toList(),
          [SectionNumber.t_1, SectionNumber.t_2]);
      expect(
          table.courseInfoMap[Day.unKnown]![SectionNumber.t_UnKnown], isNull);
    });

    test('Day.unKnown 但課號為空字串時完全不寫入', () {
      final table = CourseTableJson();
      table.setCourseDetailByTime(
          Day.unKnown, SectionNumber.t_UnKnown, info('', '沒有課號'));

      expect(table.courseInfoMap[Day.unKnown], isEmpty);
    });
  });

  group('setCourseDetailByTimeString', () {
    test('節次字串以 substring 比對，"12" 同時命中 t_1 與 t_2', () {
      final table = CourseTableJson();
      final added = table.setCourseDetailByTimeString(
          Day.monday, '12', info('A1', '微積分'));

      expect(added, isTrue);
      expect(table.courseInfoMap[Day.monday]!.keys.toList(),
          [SectionNumber.t_1, SectionNumber.t_2]);
    });

    test('空字串代表沒有時間，回傳 false 且不寫入任何節次', () {
      final table = CourseTableJson();
      expect(
          table.setCourseDetailByTimeString(Day.monday, '', info('A1', '微積分')),
          isFalse);
      expect(table.courseInfoMap[Day.monday], isEmpty);
    });

    test('英數節次 "N"、"A"、"D" 各自對應 t_N、t_A、t_D', () {
      final table = CourseTableJson();
      table.setCourseDetailByTimeString(Day.friday, 'NAD', info('A1', '通識'));

      expect(table.courseInfoMap[Day.friday]!.keys.toSet(),
          {SectionNumber.t_N, SectionNumber.t_A, SectionNumber.t_D});
    });

    test('即使因衝突而沒有真的寫入，仍然回傳 true', () {
      // 已知問題：回傳值只代表「有比對到節次」，不代表寫入成功。
      final table = CourseTableJson();
      table.setCourseDetailByTimeString(Day.monday, '1', info('A1', '微積分'));
      final added = table.setCourseDetailByTimeString(
          Day.monday, '1', info('B2', '線性代數'));

      expect(added, isTrue);
      expect(
          table
              .getCourseDetailByTime(Day.monday, SectionNumber.t_1)
              .main
              .course
              .id,
          'A1');
    });
  });

  group('addCourseDetailByCourseInfo', () {
    test('time 表少了任何一天就會丟出 TypeError', () {
      // 已知問題：`info.course.time[day]!` 對預設的 `const {}` 直接爆炸。
      // CourseMainJson 的 time 預設是空 map，只要不是課表 task 組出來的物件就會中。
      final table = CourseTableJson();
      final broken =
          CourseMainInfoJson(course: CourseMainJson(id: 'A1', name: '微積分'));

      expect(() => table.addCourseDetailByCourseInfo(broken),
          throwsA(isA<TypeError>()));
    });

    test('沒有衝突時回傳 true 並寫入對應格子', () {
      final table = CourseTableJson();
      final ok = table.addCourseDetailByCourseInfo(
          mainInfo('A1', '微積分', time: {Day.monday: '12', Day.wednesday: '3'}));

      expect(ok, isTrue);
      expect(table.courseInfoMap[Day.monday]!.keys.toList(),
          [SectionNumber.t_1, SectionNumber.t_2]);
      expect(table.courseInfoMap[Day.wednesday]!.keys.toList(),
          [SectionNumber.t_3]);
    });

    test('任一節次衝突就整堂課回傳 false，連沒衝突的節次也不會寫入', () {
      final table = CourseTableJson();
      table.addCourseDetailByCourseInfo(
          mainInfo('A1', '微積分', time: {Day.monday: '1'}));

      final ok = table.addCourseDetailByCourseInfo(
          mainInfo('B2', '線性代數', time: {Day.monday: '1', Day.friday: '5'}));

      expect(ok, isFalse);
      expect(table.courseInfoMap[Day.friday], isEmpty);
    });

    test('走 addCourseDetailByCourseInfo 時「實習」不會覆蓋，直接回傳 false', () {
      // 已知不一致：實習覆蓋只在 setCourseDetailByTime 生效，
      // 但 addCourseDetailByCourseInfo 的衝突檢查會在那之前就 return false，
      // 所以加選頁面加實習課會失敗，課表 task 組表卻會覆蓋。
      final table = CourseTableJson();
      table.addCourseDetailByCourseInfo(
          mainInfo('A1', '電子學', time: {Day.monday: '1'}));

      final ok = table.addCourseDetailByCourseInfo(
          mainInfo('A2', '電子學實習', time: {Day.monday: '1'}));

      expect(ok, isFalse);
      expect(
          table
              .getCourseDetailByTime(Day.monday, SectionNumber.t_1)
              .main
              .course
              .id,
          'A1');
    });

    test('完全沒有時間的課程會落在 Day.unKnown 的 t_1 並仍回傳 true', () {
      final table = CourseTableJson();
      final ok = table.addCourseDetailByCourseInfo(mainInfo('X1', '空白時間課程'));

      expect(ok, isTrue);
      expect(
          table.courseInfoMap[Day.unKnown]!.keys.toList(), [SectionNumber.t_1]);
      expect(
          table.courseInfoMap[Day.unKnown]![SectionNumber.t_1]!.main.course.id,
          'X1');
    });
  });

  group('學分計算', () {
    test('整數學分正常相加；同一門課佔多節只計一次', () {
      final table = CourseTableJson();
      table.setCourseDetailByTimeString(
          Day.monday, '123', info('A1', '微積分', credits: '3'));
      table.setCourseDetailByTimeString(
          Day.tuesday, '12', info('B2', '線性代數', credits: '2'));

      expect(table.getTotalCredit(), 5);
    });

    test('小數學分會被 toInt() 無條件捨去（"2.5" 算 2 學分）', () {
      // 已知問題：double.parse(...).toInt() 直接截斷，0.5 學分的課會少算。
      final table = CourseTableJson();
      table.setCourseDetailByTimeString(
          Day.monday, '1', info('A1', '體育', credits: '2.5'));

      expect(table.getCreditByCourseId('A1'), 2);
      expect(table.getTotalCredit(), 2);
    });

    test('空字串與括號學分都 parse 失敗，一律當作 0 學分', () {
      // 已知問題：抵免課的 "(3)" 在課表這裡被吃掉；ScoreUtils 那邊反而會去括號。
      final table = CourseTableJson();
      table.setCourseDetailByTimeString(
          Day.monday, '1', info('A1', '沒有學分', credits: ''));
      table.setCourseDetailByTimeString(
          Day.tuesday, '1', info('B2', '抵免課', credits: '(3)'));

      expect(table.getCreditByCourseId('A1'), 0);
      expect(table.getCreditByCourseId('B2'), 0);
      expect(table.getTotalCredit(), 0);
    });

    test('查不到的課號回傳 0 學分（不是丟例外）', () {
      expect(CourseTableJson().getCreditByCourseId('NOPE'), 0);
    });
  });

  group('查詢與移除', () {
    test('getCourseNameByCourseId 找不到時回傳 null', () {
      final table = CourseTableJson();
      table.setCourseDetailByTimeString(Day.monday, '1', info('A1', '微積分'));

      expect(table.getCourseNameByCourseId('A1'), '微積分');
      expect(table.getCourseNameByCourseId('NOPE'), isNull);
    });

    test('removeCourseByCourseId 會清掉該課號的所有節次', () {
      final table = CourseTableJson();
      table.setCourseDetailByTimeString(
          Day.monday, '123', info('A1', '微積分', credits: '3'));
      table.setCourseDetailByTimeString(
          Day.monday, '4', info('B2', '線性代數', credits: '3'));

      table.removeCourseByCourseId('A1');

      expect(
          table.courseInfoMap[Day.monday]!.keys.toList(), [SectionNumber.t_4]);
      expect(table.getCourseIdList(), ['B2']);
      expect(table.getTotalCredit(), 3);
    });
  });

  group('JSON 持久化格式（course_table_list / setting.course.info）', () {
    test('Day 的 JSON key 固定為 monday…unKnown，順序照 enum 宣告', () {
      // 這些字串是已安裝使用者硬碟裡的格式，不可以改名——
      // 見 docs/ARCHITECTURE.md〈不可以改的東西〉。
      final encoded = jsonDecode(jsonEncode(CourseTableJson().toJson()))
          as Map<String, dynamic>;
      final courseInfoMap = encoded['courseInfoMap'] as Map<String, dynamic>;

      expect(courseInfoMap.keys.toList(), [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday',
        'unKnown',
      ]);
      expect(encoded.keys.toList(),
          ['courseSemester', 'studentId', 'studentName', 'courseInfoMap']);
    });

    test('SectionNumber 的 JSON key 固定為 t_1…t_UnKnown，t_N 夾在 t_4 與 t_5 之間', () {
      final table = CourseTableJson();
      for (final SectionNumber n in SectionNumber.values) {
        table.setCourseDetailByTime(Day.monday, n, info('A1', '微積分'));
      }

      final encoded =
          jsonDecode(jsonEncode(table.toJson())) as Map<String, dynamic>;
      final monday = (encoded['courseInfoMap']
          as Map<String, dynamic>)['monday'] as Map<String, dynamic>;

      expect(monday.keys.toList(), [
        't_1',
        't_2',
        't_3',
        't_4',
        't_N',
        't_5',
        't_6',
        't_7',
        't_8',
        't_9',
        't_A',
        't_B',
        't_C',
        't_D',
        't_UnKnown',
      ]);
    });

    test('toJson → jsonEncode → jsonDecode → fromJson 完整往返後內容不變', () {
      final table = CourseTableJson(
        courseSemester: SemesterJson(year: '113', semester: '1'),
        studentId: 'B10902000',
        studentName: '王小明',
      );
      table.addCourseDetailByCourseInfo(mainInfo('A1', '微積分',
          credits: '3', time: {Day.monday: '12', Day.wednesday: 'N'}));

      final raw = jsonEncode(table.toJson());
      final restored =
          CourseTableJson.fromJson(jsonDecode(raw) as Map<String, dynamic>);

      expect(restored.studentId, 'B10902000');
      expect(restored.studentName, '王小明');
      expect(restored.courseSemester.year, '113');
      expect(restored.courseSemester.semester, '1');
      expect(restored.getCourseNameByCourseId('A1'), '微積分');
      expect(restored.getTotalCredit(), 3);
      expect(restored.courseInfoMap[Day.monday]!.keys.toList(),
          [SectionNumber.t_1, SectionNumber.t_2]);
      expect(restored.courseInfoMap[Day.wednesday]!.keys.toList(),
          [SectionNumber.t_N]);
      // 巢狀的 CourseMainJson.time 也用同一組 Day key
      final mondaySlot = (jsonDecode(raw)['courseInfoMap']['monday']['t_1']
          ['main']['course']['time']) as Map<String, dynamic>;
      expect(mondaySlot['monday'], '12');
      expect(mondaySlot['wednesday'], 'N');
      expect(jsonEncode(restored.toJson()), raw);
    });

    test('fromJson 若 JSON 少了某一天，之後所有走訪都會 TypeError', () {
      // 已知問題：只有預設建構子會把八天都補成空 map，fromJson 不補。
      // 手動或舊版寫出的 blob 少一天，開課表就會炸。
      final table = CourseTableJson();
      table.setCourseDetailByTimeString(
          Day.monday, '1', info('A1', '微積分', credits: '3'));

      final json =
          jsonDecode(jsonEncode(table.toJson())) as Map<String, dynamic>;
      (json['courseInfoMap'] as Map<String, dynamic>).remove('tuesday');

      final restored = CourseTableJson.fromJson(json);
      expect(() => restored.getTotalCredit(), throwsA(isA<TypeError>()));
      // 只有在走到缺少的那一天之前就 return 的查詢會僥倖存活：
      // 'A1' 在 monday 就命中，'NOPE' 得走完整張表所以會炸。
      expect(restored.getCourseNameByCourseId('A1'), '微積分');
      expect(() => restored.getCourseNameByCourseId('NOPE'),
          throwsA(isA<TypeError>()));
    });
  });
}
