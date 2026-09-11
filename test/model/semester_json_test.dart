// ignore_for_file: unrelated_type_equality_checks
// 拿 SemesterJson 跟別的型別比較，正是這些測試要驗證的行為。

import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_test/flutter_test.dart';

SemesterJson s(String year, String semester) =>
    SemesterJson(year: year, semester: semester);

void main() {
  group('相等性以數值意義為準（原本就有的語意）', () {
    test('同一個學期', () {
      expect(s('113', '1'), s('113', '1'));
    });

    test('補零與不補零視為同一個學期', () {
      // 學校的頁面有時送 "1" 有時送 "01"。
      expect(s('113', '1'), s('113', '01'));
      expect(s('0113', '1'), s('113', '1'));
    });

    test('不同學期不相等', () {
      expect(s('113', '1'), isNot(s('113', '2')));
      expect(s('113', '1'), isNot(s('112', '1')));
    });

    test('暑期的 H 走字串比對', () {
      expect(s('113', 'H'), s('113', 'H'));
      expect(s('113', 'H'), isNot(s('113', '1')));
    });
  });

  group('跟別的型別比較', () {
    test('回 false，不會拋例外', () {
      // `other is SemesterJson` 必須是第一個判斷，否則會先存取 other.semester
      // 而拋 NoSuchMethodError，例外直接從 == 逸出。
      expect(s('113', '1') == 'not a semester', isFalse);
      expect(s('113', '1') == 42, isFalse);
    });
  });

  group('hashCode 與 == 一致', () {
    test('相等的物件雜湊值相同', () {
      expect(s('113', '1').hashCode, s('113', '01').hashCode);
      expect(s('113', 'H').hashCode, s('113', 'H').hashCode);
    });

    test('放進 Set 時補零的版本會被視為重複', () {
      final set = {s('113', '1'), s('113', '01'), s('113', '2')};
      expect(set.length, 2);
    });
  });

  group('isValid / isEmpty 不受影響', () {
    test('H 是合法的學期', () => expect(s('113', 'H').isValid, isTrue));
    test('非數字的年份不合法', () => expect(s('abc', '1').isValid, isFalse));
    test('兩個都空才算 empty', () {
      expect(s('', '').isEmpty, isTrue);
      expect(s('113', '').isEmpty, isFalse);
    });
  });
}
