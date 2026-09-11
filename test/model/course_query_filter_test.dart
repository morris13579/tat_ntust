import 'package:flutter_app/src/connector/course_connector.dart';
import 'package:flutter_app/src/model/course/course_query_filter.dart';
import 'package:flutter_test/flutter_test.dart';

/// `/api/courses` 的 request body。
///
/// 這一份是照官方前端 2026-09 實際送出去的 body 釘的（在瀏覽器攔 XHR 抓下來
/// 的），欄位名一個字都不能差：伺服器認的是這些名字，包括拼錯的 `OnleyNTUST`。
void main() {
  Map<String, dynamic> bodyOf(CourseQueryFilter filter) =>
      filter.toRequestBody(semesterCode: '1151', language: 'zh');

  test('欄位集合與官方前端完全一致', () {
    expect(bodyOf(const CourseQueryFilter()).keys.toSet(), {
      'Semester',
      'CourseNo',
      'CourseName',
      'CourseTeacher',
      'Dimension',
      'CourseNotes',
      'CampusNotes',
      'ForeignLanguage',
      'OnlyIntensive',
      'OnlyGeneral',
      'OnleyNTUST',
      'OnlyMaster',
      'OnlyUnderGraduate',
      'OnlyNode',
      'Language',
    });
  });

  test('空條件送出去的 body 就是官方前端的預設值', () {
    expect(bodyOf(const CourseQueryFilter()), {
      'Semester': '1151',
      'CourseNo': '',
      'CourseName': '',
      'CourseTeacher': '',
      'Dimension': '',
      'CourseNotes': '',
      'CampusNotes': '',
      'ForeignLanguage': 0,
      'OnlyIntensive': 0,
      'OnlyGeneral': 0,
      'OnleyNTUST': 0,
      'OnlyMaster': 0,
      'OnlyUnderGraduate': 0,
      'OnlyNode': 0,
      'Language': 'zh',
    });
  });

  test('Language 是大寫 L——小寫的話跟官方前端送的不一樣', () {
    final body = bodyOf(const CourseQueryFilter());
    expect(body.containsKey('Language'), isTrue);
    expect(body.containsKey('language'), isFalse);
  });

  test('學制是兩個獨立的布林，不是三選一', () {
    final under = bodyOf(
        const CourseQueryFilter(level: CourseProgramLevel.underGraduate));
    expect(under['OnlyUnderGraduate'], 1);
    expect(under['OnlyMaster'], 0);

    final master =
        bodyOf(const CourseQueryFilter(level: CourseProgramLevel.master));
    expect(master['OnlyUnderGraduate'], 0);
    expect(master['OnlyMaster'], 1);

    final any = bodyOf(const CourseQueryFilter());
    expect(any['OnlyUnderGraduate'], 0);
    expect(any['OnlyMaster'], 0);
  });

  test('布林條件送 1/0，不是 true/false', () {
    final body = bodyOf(const CourseQueryFilter(
      foreignLanguageOnly: true,
      generalOnly: true,
      intensiveOnly: true,
      ntustOnly: true,
    ));
    expect(body['ForeignLanguage'], 1);
    expect(body['OnlyGeneral'], 1);
    expect(body['OnlyIntensive'], 1);
    expect(body['OnleyNTUST'], 1);
  });

  test('OnlyNode 永遠是 0：實測送 1 伺服器會回非 JSON', () {
    expect(bodyOf(const CourseQueryFilter())['OnlyNode'], 0);
  });

  test('向度送 DimNo 的大寫字母', () {
    expect(
        bodyOf(
            const CourseQueryFilter(dimension: CourseDimension.a))['Dimension'],
        'A');
    expect(
        bodyOf(
            const CourseQueryFilter(dimension: CourseDimension.f))['Dimension'],
        'F');
    expect(bodyOf(const CourseQueryFilter())['Dimension'], '');
  });

  test('關鍵字前後空白不送出去', () {
    final body = bodyOf(const CourseQueryFilter(
        courseNo: '  CS3 ', courseName: ' 離散 ', teacher: ' 戴 '));
    expect(body['CourseNo'], 'CS3');
    expect(body['CourseName'], '離散');
    expect(body['CourseTeacher'], '戴');
  });

  group('isEmpty', () {
    test('什麼都沒填才算空——空條件會讓伺服器回整個學期 4282 門', () {
      expect(const CourseQueryFilter().isEmpty, isTrue);
      expect(const CourseQueryFilter(courseNo: 'CS3').isEmpty, isFalse);
      expect(const CourseQueryFilter(generalOnly: true).isEmpty, isFalse);
      expect(const CourseQueryFilter(dimension: CourseDimension.a).isEmpty,
          isFalse);
    });

    test('只有空白字元還是算空', () {
      expect(const CourseQueryFilter(courseNo: '   ').isEmpty, isTrue);
    });
  });

  group('hasRefinements', () {
    test('只打關鍵字不算有套用篩選', () {
      expect(const CourseQueryFilter(courseNo: 'CS3').hasRefinements, isFalse);
    });

    test('勾了任何一項就算', () {
      expect(const CourseQueryFilter(foreignLanguageOnly: true).hasRefinements,
          isTrue);
      expect(
          const CourseQueryFilter(level: CourseProgramLevel.master)
              .hasRefinements,
          isTrue);
    });
  });

  test('copyWith 的 clearDimension 才清得掉向度', () {
    const filter = CourseQueryFilter(dimension: CourseDimension.a);
    expect(filter.copyWith().dimension, CourseDimension.a);
    expect(filter.copyWith(clearDimension: true).dimension, isNull);
  });

  group('dedupeClassroom', () {
    test('querycourse 一節列一次教室，同一間只留一個', () {
      // 實測 3NG115701（一 6·7）回的就是這一串。
      expect(CourseConnector.dedupeClassroom('公館 Ｅ101、公館 Ｅ101'), '公館 Ｅ101');
    });

    test('真的分兩間上課時兩間都留著——那是資訊不是重複', () {
      expect(CourseConnector.dedupeClassroom('TR-312、IB-510'), 'TR-312、IB-510');
    });

    test('空字串與空白段落不會留下多餘的頓號', () {
      expect(CourseConnector.dedupeClassroom(''), '');
      expect(CourseConnector.dedupeClassroom('TR-312、'), 'TR-312');
      expect(CourseConnector.dedupeClassroom('、'), '');
    });

    test('半形逗號也認', () {
      expect(CourseConnector.dedupeClassroom('TR-312,TR-312'), 'TR-312');
    });
  });
}
