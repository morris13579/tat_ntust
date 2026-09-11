import 'package:flutter_app/src/connector/course_connector.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_test/flutter_test.dart';

/// `CourseConnector.fillCourseTime`：整張課表與課程搜尋的節次都經過它。
///
/// **節次對映**：querycourse 前端把節次表寫死成十四格
/// `["1","2","3","4","5","6","7","8","9","10","A","B","C","D"]`；App 的
/// `timeEnum` 是十四格的 `1 2 3 4 N 5 6 7 8 9 A B C D`（`SectionNumber` 的
/// `t_N` 也夾在 `t_4` 與 `t_5` 之間）。兩張表逐格對位，所以 Node 帶的是
/// 「第幾格」而不是節次代號：API 的 "5" 是午休、App 顯示成 "N"；API 的
/// "10" 是 App 的 "9"。全量回應同樣支持：同一天相鄰兩格一起開課，3→4 有
/// 1459 次、6→7 有 1242 次，而 4→5 只有 142 次、5→6 只有 161 次。
void main() {
  /// 建一個時間欄位已初始化的 CourseMainJson，與 connector 內的作法一致。
  CourseMainJson emptyCourse() {
    final course = CourseMainJson(time: {});
    for (final day in CourseConnector.dayEnum) {
      course.time[day] = "";
    }
    return course;
  }

  String timeOf(CourseMainJson course, Day day) => course.time[day]!;

  group('節次對映', () {
    test('數字 token 是「第幾格」：M1 到 M4 就是 1 到 4', () {
      final course = emptyCourse();
      CourseConnector.fillCourseTime(course, "M1,M2,M3,M4");
      expect(timeOf(course, Day.monday), "1 2 3 4 ");
    });

    test('數字 5 是午休那一格，顯示為 "N" 而不是 "5"', () {
      // querycourse 的 times 表沒有 "N"，午休就是第 5 格；timeEnum 的第 5
      // 格正是 "N"，所以 parsed-1 是對的。真實課號 3N1326701 的 Node 就是
      // "F3,F4,F5"。
      final course = emptyCourse();
      CourseConnector.fillCourseTime(course, "F3,F4,F5");
      expect(timeOf(course, Day.friday), "3 4 N ");
    });

    test('數字 6 之後整體往後挪一格：T6 顯示為 "5"', () {
      final course = emptyCourse();
      CourseConnector.fillCourseTime(course, "T6,T7");
      expect(timeOf(course, Day.tuesday), "5 6 ");
    });

    test('兩位數的 10 是第 10 格，顯示為 "9"', () {
      // 真實課號 3T5127701 的 Node 就是單一個 "M10"，所以長度檢查必須是
      // `t.length < 2`，不能寫成 `!= 2`。
      final course = emptyCourse();
      CourseConnector.fillCourseTime(course, "M10");
      expect(timeOf(course, Day.monday), "9 ");
    });

    test('字母 token 與數字 token 是同一個對映：A 是第 11 格', () {
      // timeEnum.indexOf("A") == 10，等於「第 11 格減 1」，與數字分支的
      // parsed-1 同一個慣例。
      final course = emptyCourse();
      CourseConnector.fillCourseTime(course, "RA,RB,RC");
      expect(timeOf(course, Day.thursday), "A B C ");
    });

    test('D 是最後一格，不會越界', () {
      final course = emptyCourse();
      CourseConnector.fillCourseTime(course, "WD");
      expect(timeOf(course, Day.wednesday), "D ");
    });

    test('token 直接寫 "N" 也對到午休那一格', () {
      // 字母節次一定要查 timeEnum：`codeUnitAt(1) - 'A' + 10` 對 'N' 會算出
      // 23 而 RangeError。
      final course = emptyCourse();
      CourseConnector.fillCourseTime(course, "MN");
      expect(timeOf(course, Day.monday), "N ");
    });
  });

  group('星期對映', () {
    test('七個星期代號都對得到（含週六 S 與週日 U）', () {
      final course = emptyCourse();
      CourseConnector.fillCourseTime(course, "M1,T1,W1,R1,F1,S1,U1");
      expect(timeOf(course, Day.monday), "1 ");
      expect(timeOf(course, Day.tuesday), "1 ");
      expect(timeOf(course, Day.wednesday), "1 ");
      expect(timeOf(course, Day.thursday), "1 ");
      expect(timeOf(course, Day.friday), "1 ");
      expect(timeOf(course, Day.saturday), "1 ");
      expect(timeOf(course, Day.sunday), "1 ");
    });

    test('小寫的星期代號也吃得下', () {
      // 真實資料會出現小寫星期（課號 CS2028701 的 Node 是 "w7,w8,w9"）；
      // 只比對大寫的話整門課在課表上一格都不會出現。
      final course = emptyCourse();
      CourseConnector.fillCourseTime(course, "w7,w8,w9");
      expect(timeOf(course, Day.wednesday), "6 7 8 ");
    });
  });

  group('壞資料只跳過該 token，不影響其他節次', () {
    test('不認得的星期代號被跳過，同一串的其他 token 照常', () {
      // 外層 catch 包住整個 courseIds 迴圈並 return null，所以壞 token 一旦
      // 讓 dayEnum[-1] 拋 RangeError，整張課表就消失。
      final course = emptyCourse();
      CourseConnector.fillCourseTime(course, "X1,M2");
      expect(timeOf(course, Day.monday), "2 ");
    });

    test('超出範圍的節次（M15）被跳過', () {
      final course = emptyCourse();
      CourseConnector.fillCourseTime(course, "M15,M2");
      expect(timeOf(course, Day.monday), "2 ");
    });

    test('節次為 0 時 parsed-1 會是 -1，同樣被跳過而不是拋例外', () {
      final course = emptyCourse();
      CourseConnector.fillCourseTime(course, "M0,M2");
      expect(timeOf(course, Day.monday), "2 ");
    });

    test('不認得的字母節次（MZ）被跳過', () {
      final course = emptyCourse();
      CourseConnector.fillCourseTime(course, "MZ,M2");
      expect(timeOf(course, Day.monday), "2 ");
    });

    test('長度不足 2 的 token（只有星期、或空字串）被跳過', () {
      final course = emptyCourse();
      CourseConnector.fillCourseTime(course, "M,,M2");
      expect(timeOf(course, Day.monday), "2 ");
    });

    test('Node 為空字串時什麼都不填，也不拋例外', () {
      // 真實資料有上百門課的 Node 是 null，經 CourseSearchJson 轉成 ""。
      final course = emptyCourse();
      CourseConnector.fillCourseTime(course, "");
      for (final day in CourseConnector.dayEnum) {
        expect(timeOf(course, day), "");
      }
    });
  });

  test('同一天多節會依序累加，每節後面補一個空白', () {
    final course = emptyCourse();
    CourseConnector.fillCourseTime(course, "R6,R7,R8");
    expect(timeOf(course, Day.thursday), "5 6 7 ");
  });
}
