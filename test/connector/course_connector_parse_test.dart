import 'dart:convert';
import 'dart:io';

import 'package:flutter_app/src/connector/course_connector.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_test/flutter_test.dart';

/// querycourse 三個 API 的 fixture golden，以**未登入的純 HTTP** 從
/// `https://querycourse.ntust.edu.tw` 直接擷取：
///
/// - `courses_1151_sample.json`：`POST /querycourse/api/courses`
///   （全量回應裡挑出的 9 筆代表性資料，未做任何修改）
/// - `coursedetials_1151_3N1154701.json`：`GET /querycourse/api/coursedetials`
/// - `semestersinfo.json`：`GET /querycourse/api/semestersinfo`
///
/// **這三個來源不需要學生帳號**：getCourseExtraInfo 的 `requires` 是空集合，
/// 送出的 ConnectorParameter 不帶 token 也不帶憑證。所以這幾個 golden 任何人
/// 都能重新擷取，內容也只有公開的課程與授課教師欄位，不含個人資料。
void main() {
  List<dynamic> loadJson(String path) =>
      jsonDecode(File(path).readAsStringSync()) as List<dynamic>;

  group('parseSearchResult（/api/courses）', () {
    late List<dynamic> raw;

    setUp(() {
      raw = loadJson('test/fixtures/querycourse/courses_1151_sample.json');
    });

    test('每一筆都轉得出來，不會因為單一筆壞資料整批消失', () {
      // searchCourse 的 catch 包住整個迴圈並 return null，所以「一筆例外
      // 等於整批搜尋結果消失」。這個 fixture 刻意含 Node 為 null、
      // ClassRoomNo 為 null 與小寫星期的資料。
      final result = CourseConnector.parseSearchResult(raw);
      expect(result.length, raw.length);
    });

    test('課號預設取回應裡的 CourseNo', () {
      final result = CourseConnector.parseSearchResult(raw);
      expect(result.first.course.id, 'CS2028701');
    });

    test('overrideId 會蓋掉課號，其餘欄位不變', () {
      // getCourseMainInfoListByCourseId 是以課號逐一查詢後組課表，
      // 課表要對回呼叫端給的 courseIds，所以那條路徑用 overrideId。
      final result =
          CourseConnector.parseSearchResult(raw, overrideId: 'FAKE-ID');
      expect(result.first.course.id, 'FAKE-ID');
      expect(result.first.course.name, '遊戲企劃:造遊實域拆解與重構');
    });

    test('小寫星期的真實資料（CS2028701 的 "w7,w8,w9"）會落在星期三', () {
      // 星期代號的比對必須忽略大小寫，否則這三節全被丟掉，
      // 這門課在課表上一格都不會出現。
      final course = CourseConnector.parseSearchResult(raw).first.course;
      expect(course.time[Day.wednesday], '6 7 8 ');
    });

    test('兩位數節次與字母節次都對得上', () {
      final result = CourseConnector.parseSearchResult(raw);
      // 3T5127701 大氣程式實作，Node = "M10"
      expect(result[1].course.time[Day.monday], '9 ');
      // 3N3001701 臺語天文學，Node = "RA,RB,RC"
      expect(result[2].course.time[Day.thursday], 'A B C ');
    });

    test('跨午休的真實資料（3N1326701 的 "F3,F4,F5"）顯示為 "3 4 N"', () {
      final result = CourseConnector.parseSearchResult(raw);
      expect(result[3].course.time[Day.friday], '3 4 N ');
    });

    test('Node 與 ClassRoomNo 為 null 的課（3T1063701）轉成空字串而不是拋例外', () {
      // 真實資料有上百門課的 Node 與 ClassRoomNo 是 null，靠
      // course_search_json.g.dart 的 `as String? ?? ""` 擋住；這條 golden 是
      // 為了讓「把模型欄位改成非空、又忘了預設值」時 CI 會紅。
      final result = CourseConnector.parseSearchResult(raw);
      final course = result[4];
      expect(course.course.name, '地質調查導論二');
      expect(course.classroom.single.name, '');
      for (final day in CourseConnector.dayEnum) {
        expect(course.course.time[day], '');
      }
    });

    test('週日（MG5428701 的 "U1"）對得到 Day.sunday', () {
      final result = CourseConnector.parseSearchResult(raw);
      expect(result[5].course.time[Day.sunday], '1 ');
    });

    test('同課號不同教室會保留成兩筆，不會被合併或去重', () {
      // 同一個課程代碼在不同教室會有多筆資料：AD2001301 建築設計(三)
      // 就有 T8,T9（RB-809A）與 R3..R10（RB-708）兩筆。
      final result = CourseConnector.parseSearchResult(raw);
      final ad = result.where((e) => e.course.id == 'AD2001301').toList();
      expect(ad.length, 2);
      expect(ad[0].classroom.single.name, 'RB-809A');
      expect(ad[1].classroom.single.name, 'RB-708');
      expect(ad[0].course.time[Day.tuesday], '7 8 ');
      expect(ad[1].course.time[Day.thursday], '3 4 N 5 6 7 8 9 ');
    });

    test('教師、學分、備註直接照抄回應欄位', () {
      final result = CourseConnector.parseSearchResult(raw);
      final course = result[6]; // 3N1154701 基礎微積分
      expect(course.teacher.single.name, '丁老師');
      expect(course.course.credits, '3');
      expect(course.course.note, '師大課程／限外系 生科一、學科一；限修學制：大、碩、博');
      // category 放 RequireOption 的原始碼：實測值域只有 R（必修）與 E（選修）。
      // 在地化字串在畫面那一層才組——model 不 import R.dart。
      expect(course.course.category, 'E');
      // hours 才是真的沒有：課程查詢 API 沒有這一欄，只有選課系統的課表 HTML 有。
      expect(course.course.hours, '');
    });

    test('七天的 time 都會被初始化成空字串（不是 null）', () {
      // fillCourseTime 直接對 `courseMain.time[day]!` 做字串串接，
      // 少初始化一天就是 null check operator 例外。
      final result = CourseConnector.parseSearchResult(raw);
      for (final info in result) {
        for (final day in CourseConnector.dayEnum) {
          expect(info.course.time[day], isNotNull);
        }
      }
    });
  });

  group('parseCourseSemesters（/api/semestersinfo）', () {
    test('只取第一筆，切成三碼學年與一碼學期', () {
      final raw = loadJson('test/fixtures/querycourse/semestersinfo.json');
      final result = CourseConnector.parseCourseSemesters(raw);
      expect(result.length, 1);
      expect(result.single.year, '115');
      expect(result.single.semester, '1');
    });

    test('暑期的學期碼是 "H" 不是數字，SemesterJson 仍視為有效', () {
      // fixture 第二筆是 "114H"。SemesterJson.isValid 對 "H" 有特例，
      // 這裡確認切字串的方式不會把它切壞。
      final raw = loadJson('test/fixtures/querycourse/semestersinfo.json');
      final second = raw[1] as Map<String, dynamic>;
      final result = CourseConnector.parseCourseSemesters([second]);
      expect(result.single.year, '114');
      expect(result.single.semester, 'H');
      expect(result.single.isValid, isTrue);
    });

    test('空清單會拋例外（現況：由 getCourseSemesters 的 catch 轉成 null）', () {
      expect(() => CourseConnector.parseCourseSemesters([]), throwsRangeError);
    });
  });

  group('parseCourseExtraInfo（/api/coursedetials）', () {
    test('取陣列第一筆，欄位照 JsonKey 對應', () {
      final raw = loadJson(
          'test/fixtures/querycourse/coursedetials_1151_3N1154701.json');
      final info = CourseConnector.parseCourseExtraInfo(raw);
      expect(info.courseNo, '3N1154701');
      expect(info.courseName, '基礎微積分');
      expect(info.courseTeacher, '丁老師');
      expect(info.creditPoint, '3');
      expect(info.requireOption, '選修');
      expect(info.allYear, '半學年');
    });

    test('回應裡是 null 的欄位轉成空字串', () {
      // CourseTextbook、CourseNote 等在這門課全是 null。模型的欄位是非空
      // String，靠產生的 `as String? ?? ""` 擋住；這是課程詳細頁不崩的前提。
      final raw = loadJson(
          'test/fixtures/querycourse/coursedetials_1151_3N1154701.json');
      final info = CourseConnector.parseCourseExtraInfo(raw);
      expect(info.courseTextbook, '');
      expect(info.courseNote, '');
      expect(info.courseGrading, '');
    });
  });
}
