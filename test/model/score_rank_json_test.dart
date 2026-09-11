// ignore_for_file: unrelated_type_equality_checks
// 拿 SemesterJson 跟別的型別比較，正是這些測試要驗證的行為。

import 'dart:convert';

import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/score/score_json.dart';
import 'package:flutter_test/flutter_test.dart';

/// 特徵化測試：凍結 `ScoreRankJson` / `SemesterScoreJson` / `RankJson` 目前的行為，
/// 包含 `SemesterJson.==` 的數值比對、`==` 與 `hashCode` 不一致，
/// 以及 `toJson()` 其實不是純 JSON 這幾個已知怪異之處。
///
/// 注意：`ScoreItemJson.isPassScore` / `isValidScore` 已由
/// `test/util/score_utils_test.dart` 覆蓋，這裡不重複。

SemesterJson semester(String year, String sem) =>
    SemesterJson(year: year, semester: sem);

ScoreItemJson scoreItem(String courseId) => ScoreItemJson(
      courseId: courseId,
      name: '課程 $courseId',
      credit: '3',
      score: 'A',
      generalDimension: '',
      remark: '',
    );

RankJson rank(String classRank) => RankJson(
      classRank: classRank,
      departmentRank: '20/100',
      averageScore: '85.5',
      classRankYears: '3/50',
      departmentRankYears: '18/100',
      averageYears: '86.0',
    );

void main() {
  group('ScoreRankJson.addScoreBySemester', () {
    test('學期不存在時會新建一筆 SemesterScoreJson，且 rank 為 null', () {
      final scoreRank = ScoreRankJson();
      scoreRank.addScoreBySemester(semester('111', '1'), scoreItem('CS101'));

      expect(scoreRank.info.length, 1);
      expect(scoreRank.info.first.item.length, 1);
      expect(scoreRank.info.first.item.first.courseId, 'CS101');
      expect(scoreRank.info.first.rank, isNull);
    });

    test('同一學期再加課程會併入既有 item，不會多一筆學期', () {
      final scoreRank = ScoreRankJson();
      scoreRank.addScoreBySemester(semester('111', '1'), scoreItem('CS101'));
      scoreRank.addScoreBySemester(semester('111', '1'), scoreItem('CS102'));

      expect(scoreRank.info.length, 1);
      expect(
        scoreRank.info.first.item.map((e) => e.courseId).toList(),
        ['CS101', 'CS102'],
      );

      // 已知現況：沒有以 courseId 做去重，重複抓取成績會產生重複列。
      scoreRank.addScoreBySemester(semester('111', '1'), scoreItem('CS101'));
      expect(scoreRank.info.first.item.length, 3);
    });

    test('不同學期會各自成為一筆，且維持插入順序', () {
      final scoreRank = ScoreRankJson();
      scoreRank.addScoreBySemester(semester('111', '2'), scoreItem('CS201'));
      scoreRank.addScoreBySemester(semester('111', '1'), scoreItem('CS101'));

      expect(scoreRank.info.length, 2);
      // 沒有任何排序，就是加入的先後順序。
      expect(scoreRank.info[0].semester.semester, '2');
      expect(scoreRank.info[1].semester.semester, '1');
    });
  });

  group('ScoreRankJson.addRankBySemester', () {
    test('學期不存在時會新建一筆 SemesterScoreJson，item 為空清單', () {
      final scoreRank = ScoreRankJson();
      scoreRank.addRankBySemester(semester('111', '1'), rank('5/50'));

      expect(scoreRank.info.length, 1);
      expect(scoreRank.info.first.item, isEmpty);
      expect(scoreRank.info.first.rank!.classRank, '5/50');
    });

    test('學期已存在時只覆蓋 rank，不動既有的 item', () {
      final scoreRank = ScoreRankJson();
      scoreRank.addScoreBySemester(semester('111', '1'), scoreItem('CS101'));
      scoreRank.addRankBySemester(semester('111', '1'), rank('5/50'));
      scoreRank.addRankBySemester(semester('111', '1'), rank('1/50'));

      expect(scoreRank.info.length, 1);
      expect(scoreRank.info.first.item.length, 1);
      // 後寫入的 rank 直接取代前一個。
      expect(scoreRank.info.first.rank!.classRank, '1/50');
    });
  });

  group('ScoreRankJson.getCourseIdBySemester', () {
    test('回傳該學期所有課號並保持順序', () async {
      final scoreRank = ScoreRankJson();
      scoreRank.addScoreBySemester(semester('111', '1'), scoreItem('CS101'));
      scoreRank.addScoreBySemester(semester('111', '1'), scoreItem('CS102'));
      scoreRank.addScoreBySemester(semester('111', '2'), scoreItem('CS201'));

      expect(await scoreRank.getCourseIdBySemester(semester('111', '1')),
          ['CS101', 'CS102']);
    });

    test('查無此學期、空 info、只有 rank 的學期都回傳空清單', () async {
      final scoreRank = ScoreRankJson();
      scoreRank.addScoreBySemester(semester('111', '1'), scoreItem('CS101'));
      scoreRank.addRankBySemester(semester('110', '2'), rank('5/50'));

      expect(
          await scoreRank.getCourseIdBySemester(semester('109', '1')), isEmpty);
      expect(
          await scoreRank.getCourseIdBySemester(semester('110', '2')), isEmpty);
      expect(await ScoreRankJson().getCourseIdBySemester(semester('111', '1')),
          isEmpty);
    });
  });

  group('學期比對（SemesterJson.==）如何影響 ScoreRankJson', () {
    test('補零的 "0111"/"01" 會被視為與 "111"/"1" 同一學期', () {
      // SemesterJson.== 先試 int.parse 再比數值，所以前導零會被忽略。
      expect(semester('0111', '01') == semester('111', '1'), isTrue);

      final scoreRank = ScoreRankJson();
      scoreRank.addScoreBySemester(semester('111', '1'), scoreItem('CS101'));
      scoreRank.addScoreBySemester(semester('0111', '01'), scoreItem('CS102'));

      // 因此不會新增第二筆學期，兩門課會落在同一個 SemesterScoreJson。
      expect(scoreRank.info.length, 1);
      expect(scoreRank.info.first.item.length, 2);
      // 而且保留的是「先加入」的那個 SemesterJson 物件，"0111" 被丟棄。
      expect(scoreRank.info.first.semester.year, '111');
    });

    test('暑修 "H" 的學期，年份一樣會做前導零正規化', () {
      // 每個欄位各自正規化：int.parse("H") 失敗只影響 semester 自己，
      // 年份照樣忽略前導零。
      expect(semester('111', 'H') == semester('111', 'H'), isTrue);
      expect(semester('0111', 'H') == semester('111', 'H'), isTrue);
      expect(semester('111', 'H') == semester('111', '1'), isFalse);

      final scoreRank = ScoreRankJson();
      scoreRank.addScoreBySemester(semester('111', 'H'), scoreItem('CS101'));
      scoreRank.addScoreBySemester(semester('0111', 'H'), scoreItem('CS102'));
      // 併成同一筆學期，與數字學期的行為一致。
      expect(scoreRank.info.length, 1);
      expect(scoreRank.info.first.item.length, 2);
    });

    test('== 與 hashCode 一致，放進 Set 會去重', () {
      final a = semester('0111', '01');
      final b = semester('111', '1');
      expect(a == b, isTrue);
      // hashCode 必須跟著 == 的正規化走，直接雜湊原始字串會違反 hash 契約。
      expect(a.hashCode == b.hashCode, isTrue);
      expect({a, b}.length, 1);
    });

    test('拿非 SemesterJson 的東西比較回 false，不再拋例外', () {
      // `other is SemesterJson` 必須是第一個判斷，否則會先存取 other.semester，
      // NoSuchMethodError 直接從 == 逸出。
      expect(semester('111', '1') == 'foo', isFalse);
      expect(semester('111', '1') == 42, isFalse);
    });
  });

  group('ScoreRankJson 的 toJson / fromJson', () {
    test('空 info 可以完整 round-trip', () {
      final json = ScoreRankJson().toJson();
      expect(json['info'], isEmpty);

      final restored = ScoreRankJson.fromJson(json);
      expect(restored.info, isEmpty);
    });

    test('經過 jsonEncode/jsonDecode 後，含 rank 的巢狀結構可完整還原', () {
      final scoreRank = ScoreRankJson();
      scoreRank.addScoreBySemester(semester('111', '1'), scoreItem('CS101'));
      scoreRank.addRankBySemester(semester('111', '1'), rank('5/50'));

      final decoded = jsonDecode(jsonEncode(scoreRank.toJson()));
      final restored = ScoreRankJson.fromJson(decoded as Map<String, dynamic>);

      expect(restored.info.length, 1);
      final only = restored.info.first;
      expect(only.semester.year, '111');
      expect(only.semester.semester, '1');
      expect(only.item.length, 1);
      expect(only.item.first.courseId, 'CS101');
      expect(only.item.first.name, '課程 CS101');
      expect(only.rank!.classRank, '5/50');
      expect(only.rank!.averageYears, '86.0');
      // 再序列化一次應該得到一模一樣的字串。
      expect(jsonEncode(restored.toJson()), jsonEncode(scoreRank.toJson()));
    });

    test('沒有 rank 時 key 仍會輸出且為 null，還原後也是 null', () {
      final scoreRank = ScoreRankJson();
      scoreRank.addScoreBySemester(semester('111', '1'), scoreItem('CS101'));

      final decoded =
          jsonDecode(jsonEncode(scoreRank.toJson())) as Map<String, dynamic>;
      expect((decoded['info'] as List).first, containsPair('rank', isNull));
      expect(ScoreRankJson.fromJson(decoded).info.first.rank, isNull);
    });

    test('toJson() 不是純 Map，直接餵回 fromJson 會拋 TypeError（現況）', () {
      final scoreRank = ScoreRankJson();
      scoreRank.addScoreBySemester(semester('111', '1'), scoreItem('CS101'));

      final json = scoreRank.toJson();
      // 產生器只放進物件本身，沒有遞迴呼叫 toJson()。
      expect(json['info'].first, isA<SemesterScoreJson>());
      // 所以 round-trip 一定要先過 jsonEncode/jsonDecode，
      // 否則 `e as Map<String, dynamic>` 會炸。呼叫端都靠 jsonEncode 才沒踩到。
      expect(() => ScoreRankJson.fromJson(json), throwsA(isA<TypeError>()));
    });
  });

  group('二次退選不進歷年課表', () {
    ScoreItemJson withdrawn(String courseId) => ScoreItemJson(
          courseId: courseId,
          name: '課程 $courseId',
          credit: '3',
          // 實測成績單：score 與 remark 兩欄都是這四個字。
          score: '二次退選',
          generalDimension: '',
          remark: '二次退選',
        );

    test('二次退選的課不會進歷年課表', () async {
      final scoreRank = ScoreRankJson();
      scoreRank.addScoreBySemester(
          semester('113', '1'), scoreItem('CS3009302'));
      scoreRank.addScoreBySemester(
          semester('113', '1'), withdrawn('CS1012701'));

      expect(await scoreRank.getCourseIdBySemester(semester('113', '1')),
          ['CS3009302']);
    });

    test('只有 remark 標記時也算', () async {
      final scoreRank = ScoreRankJson();
      scoreRank.addScoreBySemester(
          semester('113', '1'),
          ScoreItemJson(
              courseId: 'CS1012701',
              name: 'x',
              credit: '3',
              score: '',
              generalDimension: '',
              remark: '二次退選'));

      expect(
          await scoreRank.getCourseIdBySemester(semester('113', '1')), isEmpty);
    });

    test('不及格與免修照樣留著——那些課真的上過', () async {
      final scoreRank = ScoreRankJson();
      scoreRank.addScoreBySemester(
          semester('113', '1'),
          ScoreItemJson(
              courseId: 'CS3003301',
              name: '離散數學',
              credit: '3',
              score: 'E',
              generalDimension: '',
              remark: '不及格'));
      expect(await scoreRank.getCourseIdBySemester(semester('113', '1')),
          ['CS3003301']);
    });
  });
}
