import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/util/course_table_share_codec.dart';
import 'package:flutter_test/flutter_test.dart';

/// 分享碼的編解碼。載體設計的每一條規則都在這裡釘住。
void main() {
  CourseTableJson tableOf(List<(String, Map<Day, String>)> courses,
      {String studentId = 'B11000001',
      String year = '115',
      String semester = '1'}) {
    final table = CourseTableJson(
      courseSemester: SemesterJson(year: year, semester: semester),
      studentId: studentId,
    );
    for (final (id, time) in courses) {
      // addCourseDetailByCourseInfo 對七天都做 `time[day]!`，少一天就 TypeError。
      final full = {for (final day in Day.values) day: time[day] ?? ''};
      table.addCourseDetailByCourseInfo(CourseMainInfoJson(
        course: CourseMainJson(id: id, name: id, time: full),
      ));
    }
    return table;
  }

  /// 實測的課表：6 門，課號都是 9 碼。
  CourseTableJson realTable() => tableOf([
        ('CS3039701', {Day.thursday: '6 7'}),
        ('PE1133725', {Day.thursday: '9 A'}),
        ('FE1791702', {Day.wednesday: '6 7'}),
        ('CS3003302', {Day.thursday: '3 4'}),
        ('TCG159301', {Day.thursday: '1 2'}),
        ('CS490B001', {Day.monday: '8'}),
      ]);

  group('encode', () {
    test('整包只有大寫英數與 QR alphanumeric 允許的符號', () {
      final code = CourseTableShareCodec.encode(realTable());
      // QR alphanumeric 字集：0-9 A-Z 空格 $ % * + - . / :
      expect(RegExp(r'^[0-9A-Z $%*+\-./:]+$').hasMatch(code), isTrue,
          reason: code);
    });

    test('前綴、magic、學期、學號依序排好', () {
      final code = CourseTableShareCodec.encode(realTable());
      expect(code, startsWith('HTTPS://NTUST-TAT.WEB.APP/S/TAT21151B11000001'));
    });

    test('同一份課表編出來的碼是穩定的', () {
      expect(CourseTableShareCodec.encode(realTable()),
          CourseTableShareCodec.encode(realTable()));
    });
  });

  group('round trip', () {
    test('課號、學號、學期、每一格時間都回得來', () {
      final decoded = CourseTableShareCodec.decode(
          CourseTableShareCodec.encode(realTable()));
      expect(decoded, isNotNull);
      expect(decoded!.studentId, 'B11000001');
      expect(decoded.year, '115');
      expect(decoded.semester, '1');
      // 順序照課表走訪：星期一 → 星期三 → 星期四（再照節次）。
      expect(decoded.courses.map((c) => c.id).toList(), [
        'CS490B001',
        'FE1791702',
        'TCG159301',
        'CS3003302',
        'CS3039701',
        'PE1133725',
      ]);
      final discrete = decoded.courses.firstWhere((c) => c.id == 'CS3003302');
      expect(discrete.slots.map((s) => (s.day, s.section)).toList(), [
        (Day.thursday, SectionNumber.t_3),
        (Day.thursday, SectionNumber.t_4),
      ]);
    });

    test('沒有時間的課也帶得過去', () {
      final table = tableOf([
        ('CS3039701', {Day.thursday: '6 7'}),
        ('CS490B001', const {}),
      ]);
      final decoded =
          CourseTableShareCodec.decode(CourseTableShareCodec.encode(table));
      final timeless = decoded!.courses.firstWhere((c) => c.id == 'CS490B001');
      expect(timeless.slots, isEmpty);
    });

    test('中午的 N 節與 A-D 節都對得回來', () {
      final table = tableOf([
        ('CS3039701', {Day.monday: 'N'}),
        ('CS3003302', {Day.friday: 'A B C D'}),
      ]);
      final decoded =
          CourseTableShareCodec.decode(CourseTableShareCodec.encode(table));
      expect(decoded!.courses.first.slots.single.section, SectionNumber.t_N);
      expect(decoded.courses.last.slots.map((s) => s.section).toList(), [
        SectionNumber.t_A,
        SectionNumber.t_B,
        SectionNumber.t_C,
        SectionNumber.t_D,
      ]);
    });

    test('暑期學期 114H', () {
      final decoded =
          CourseTableShareCodec.decode(CourseTableShareCodec.encode(tableOf([
        ('CS3039701', {Day.monday: '1'})
      ], year: '114', semester: 'H')));
      expect(decoded!.year, '114');
      expect(decoded.semester, 'H');
    });

    test('空課表：解得開，課程是空的', () {
      final decoded = CourseTableShareCodec.decode(
          CourseTableShareCodec.encode(tableOf([])));
      expect(decoded, isNotNull);
      expect(decoded!.courses, isEmpty);
      expect(decoded.studentId, 'B11000001');
    });

    test('裸碼（貼上代碼那條路徑）不必帶網址前綴', () {
      final payload = CourseTableShareCodec.encodePayload(realTable());
      expect(payload, isNot(startsWith('HTTPS')));
      expect(CourseTableShareCodec.decode(payload)?.courses, hasLength(6));
    });

    test('小寫也吃得下：使用者貼上的字串不保證大小寫', () {
      final code = CourseTableShareCodec.encode(realTable()).toLowerCase();
      expect(CourseTableShareCodec.decode(code)?.studentId, 'B11000001');
    });
  });

  group('拒絕不是我們的碼', () {
    test('別的 App 的 QR', () {
      expect(CourseTableShareCodec.decode('https://example.com/hello'), isNull);
      expect(CourseTableShareCodec.decode('WIFI:S:home;T:WPA;P:x;;'), isNull);
      expect(CourseTableShareCodec.decode(''), isNull);
    });

    test('被截斷的字串', () {
      final code = CourseTableShareCodec.encode(realTable());
      expect(CourseTableShareCodec.decode(code.substring(0, 30)), isNull);
      expect(CourseTableShareCodec.decode(code.substring(0, 40)), isNull);
    });

    test('課號不是 9 碼', () {
      expect(CourseTableShareCodec.decode('TAT21151B11000001CS30397'), isNull);
      expect(
          CourseTableShareCodec.decode('TAT21151B11000001CS3039701X'), isNull);
    });

    test('星期或節次超出範圍', () {
      expect(
          CourseTableShareCodec.decode('TAT21151B11000001CS3039701.86'), isNull,
          reason: '星期 8 不存在');
      expect(
          CourseTableShareCodec.decode('TAT21151B11000001CS3039701.4Z'), isNull,
          reason: '節次 Z 不存在');
      expect(
          CourseTableShareCodec.decode('TAT21151B11000001CS3039701.4'), isNull,
          reason: '只有星期、沒有節次');
    });

    test('TAT1 是舊格式，仍然解得開（只有課號、沒有時間）', () {
      final decoded =
          CourseTableShareCodec.decode('TAT11151B11000001CS3039701');
      expect(decoded?.courses.single.id, 'CS3039701');
      expect(decoded?.courses.single.slots, isEmpty);
    });
  });

  group('QR 密度', () {
    /// 這是整個載體設計的重點，掉了就代表 QR 會胖一圈：**payload 必須待在
    /// alphanumeric 模式**。這裡不引入 QR 套件，直接斷言字集——只要每個字元都
    /// 在 alphanumeric 字集裡，編碼器就一定選得到那個模式。
    ///
    /// 對照組：課名與教室是中文（例如「華夏體育館2樓桌球室」），一放進去整包就
    /// 掉進 byte 模式，實測 10 門要 85×85、14 門要 101×101，隔著桌子掃不動。
    const charset = r'^[0-9A-Z $%*+\-./:]+$';

    test('20 門課仍然全是 alphanumeric，而且長度可控', () {
      final many = <(String, Map<Day, String>)>[];
      const days = [
        Day.monday,
        Day.tuesday,
        Day.wednesday,
        Day.thursday,
        Day.friday,
      ];
      for (var i = 0; i < 20; i++) {
        many.add((
          'CS${(3000000 + i).toString().padLeft(7, '0')}',
          {days[i % 5]: '${i % 4 + 1} ${i % 4 + 2}'},
        ));
      }
      final code = CourseTableShareCodec.encode(tableOf(many));
      expect(RegExp(charset).hasMatch(code), isTrue);
      // alphanumeric 模式下 v8（49×49）裝得下 258 字元（ECC M）。
      expect(code.length, lessThanOrEqualTo(258), reason: code);
    });

    test('6 門課的碼夠短，v6（41×41）就裝得下', () {
      // alphanumeric + ECC M 的 v6 上限是 154 字元。實測 6 門是 113。
      expect(CourseTableShareCodec.encode(realTable()).length,
          lessThanOrEqualTo(154));
    });

    test('同一天的節次會併成一段，不是每一節都重寫星期', () {
      final code = CourseTableShareCodec.encodePayload(tableOf([
        ('CS3039701', {Day.thursday: '3 4'})
      ]));
      expect(code, endsWith('CS3039701.434'));
    });
  });

  group('實機掃出來的碼', () {
    /// 這一串是從模擬器畫面上的 QR 用 OpenCV 解出來的，不是手寫的——
    /// 它同時驗證了「qr_flutter 產出的圖真的掃得回原字串」與「解碼器吃得下」。
    const scanned =
        'HTTPS://NTUST-TAT.WEB.APP/S/TAT21151B11000001CS3039701.1789-'
        'PE1133725.289-FE1791702.356-CS3003302.38.434-TCG159301.456-CS490B001';

    test('解得開，學號學期與六門課都對', () {
      final decoded = CourseTableShareCodec.decode(scanned);
      expect(decoded, isNotNull);
      expect(decoded!.studentId, 'B11000001');
      expect(decoded.semesterCode, '1151');
      expect(decoded.courses.map((c) => c.id).toList(), [
        'CS3039701',
        'PE1133725',
        'FE1791702',
        'CS3003302',
        'TCG159301',
        'CS490B001',
      ]);
    });

    test('跨兩天的課：離散數學是三 8 與四 3·4', () {
      final course = CourseTableShareCodec.decode(scanned)!
          .courses
          .firstWhere((c) => c.id == 'CS3003302');
      expect(course.slots.map((s) => (s.day, s.section)).toList(), [
        (Day.wednesday, SectionNumber.t_8),
        (Day.thursday, SectionNumber.t_3),
        (Day.thursday, SectionNumber.t_4),
      ]);
    });

    test('沒有時間的課（資工實務專題）帶得過去但不佔格子', () {
      final course = CourseTableShareCodec.decode(scanned)!
          .courses
          .firstWhere((c) => c.id == 'CS490B001');
      expect(course.slots, isEmpty);
    });

    test('長度 128，仍然在 v6（41x41）的容量內', () {
      expect(scanned.length, 128);
      expect(scanned.length, lessThanOrEqualTo(154));
    });
  });
}
