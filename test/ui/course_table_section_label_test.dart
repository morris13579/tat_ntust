import 'package:flutter_app/src/connector/course_connector.dart';
import 'package:flutter_app/src/model/course_table/course_time.dart';
import 'package:flutter_app/src/util/course_table_control.dart';
import 'package:flutter_test/flutter_test.dart';

/// 節次標籤。
///
/// 臺科的節次是 `1…10 A…D`：中午 12:20–13:10 就是**第五節**，之後依序往下，
/// 17:30 那格是第十節，與 querycourse 前端那張表一致。
///
/// 內部代號是另一套：[SectionNumber] 的名稱、`CourseConnector.timeEnum` 與
/// 分享碼都必須一格一個字元（`CourseTableJson.string2Time` 用 `contains`
/// 逐字比對），所以中午那格在內部叫 `N`。**兩套不相等，這是刻意的。**
void main() {
  group('CourseTableControl 的節次標籤', () {
    final control = CourseTableControl();

    test('與 timeList、SectionNumber 逐格對位', () {
      expect(
          control.sectionStringList.length, CourseTableControl.sectionLength);
      expect(control.timeList.length, CourseTableControl.sectionLength);
      expect(SectionNumber.values.length - 1, CourseTableControl.sectionLength,
          reason: 't_UnKnown 不算格');
    });

    test('中午 12:20 是第五節，不是 N', () {
      final noon =
          control.timeList.indexWhere((t) => t.startsWith('12:20'));

      expect(noon, isNot(-1));
      expect(control.getSectionString(noon), '5');
      expect(control.sectionStringList, isNot(contains('N')));
    });

    test('午休那一格的內部代號仍然是 N——它是持久化與分享碼的字母', () {
      // 換掉會讓已存的課表解不開，也會讓 string2Time 的逐字比對撞在一起。
      expect(SectionNumber.t_N.index, 4);
      expect(CourseConnector.timeEnum[4], 'N');
      expect(control.getSectionString(4), '5');
    });

    test('內部代號每一格都是單一字元', () {
      // 一旦有兩個字元，string2Time 的 contains 會讓 "10" 也命中第 1 節。
      for (final code in CourseConnector.timeEnum) {
        expect(code.length, 1, reason: '$code 不是單一字元');
      }
    });

    test('標籤與上課時間對得起來', () {
      for (final (time, label) in const [
        ('08:10', '1'),
        ('11:20', '4'),
        ('12:20', '5'),
        ('13:20', '6'),
        ('15:30', '8'),
        ('17:30', '10'),
        ('18:25', 'A'),
        ('21:00', 'D'),
      ]) {
        final i = control.timeList.indexWhere((t) => t.startsWith(time));
        expect(i, isNot(-1), reason: '找不到 $time');
        expect(control.getSectionString(i), label, reason: '$time 應該是第 $label 節');
      }
    });
  });
}
