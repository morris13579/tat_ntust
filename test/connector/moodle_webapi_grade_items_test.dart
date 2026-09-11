import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_gradereport_get_grade_items.dart';
import 'package:flutter_test/flutter_test.dart';

/// `gradereport_user_get_grade_items` 這一份回應的本機判讀規格。
///
/// 判讀抽成公開純函式 `userGradesOf`：九個 getter 走 static 的
/// `Connector.getJsonByPost`，沒有可以注入假回應的地方。
void main() {
  /// 樣本形狀照 moodle2.ntust.edu.tw 的實測結果：`graderaw` 是 null，
  /// 有值的是 `gradeformatted` 那一組。
  Map<String, dynamic> gradeItem({
    required int id,
    String? itemname,
    String itemtype = 'mod',
    String gradeformatted = '',
    String percentageformatted = '',
    String weightformatted = '',
    String rangeformatted = '',
    String feedback = '',
  }) =>
      {
        'id': id,
        'itemname': itemname,
        'itemtype': itemtype,
        'itemmodule': itemtype == 'mod' ? 'quiz' : null,
        'iteminstance': 1,
        'itemnumber': null,
        'idnumber': null,
        'categoryid': null,
        'outcomeid': null,
        'scaleid': null,
        'locked': null,
        'cmid': null,
        'weightraw': 0.3,
        'weightformatted': weightformatted,
        'graderaw': null,
        'gradedatesubmitted': 1740000000,
        'gradedategraded': null,
        'gradehiddenbydate': false,
        'gradeneedsupdate': false,
        'gradeishidden': false,
        'gradeislocked': null,
        'gradeisoverridden': null,
        'gradeformatted': gradeformatted,
        'grademin': 0,
        'grademax': 100,
        'rangeformatted': rangeformatted,
        'percentageformatted': percentageformatted,
        'feedback': feedback,
        'feedbackformat': 1,
      };

  Map<String, dynamic> response(List<Map<String, dynamic>> items) => {
        'usergrades': [
          {
            'courseid': 28914,
            'courseidnumber': '1141AT10001',
            'userid': 5252,
            'userfullname': 'B10000000 @ 王小明',
            'useridnumber': 'B10000000',
            'maxdepth': 2,
            'gradeitems': items,
          }
        ],
        'warnings': <dynamic>[],
      };

  group('userGradesOf：從回應剝出自己那一筆成績', () {
    test('帶 userid 呼叫時 usergrades 只有一筆，直接回那一筆', () {
      final grades = MoodleWebApiConnector.userGradesOf(response([
        gradeItem(
          id: 11,
          itemname: '小考一',
          gradeformatted: '90.00',
          percentageformatted: '90.00 %',
          weightformatted: '30.00 %',
          rangeformatted: '0&ndash;100',
          feedback: '<p>不錯</p>',
        ),
        gradeItem(
          id: 12,
          itemname: '課程總分',
          itemtype: 'course',
          gradeformatted: '85.00',
        ),
      ]));

      expect(grades, isNotNull);
      expect(grades!.courseId, 28914);
      expect(grades.userFullName, 'B10000000 @ 王小明');
      expect(grades.gradeItems.length, 2);

      final quiz = grades.gradeItems.first;
      // 實測 graderaw 是 null，畫面必須用 gradeformatted。
      expect(quiz.gradeRaw, isNull);
      expect(quiz.gradeFormatted, '90.00');
      expect(quiz.percentageFormatted, '90.00 %');
      expect(quiz.weightFormatted, '30.00 %');
      expect(quiz.rangeFormatted, '0&ndash;100');
      expect(quiz.feedback, '<p>不錯</p>');
      expect(quiz.isCourseTotal, isFalse);
    });

    test('課程總分靠 itemtype 認，與 Moodle 介面語言無關', () {
      // 比對介面文字的話，Moodle 切成英文就再也認不出來。
      final grades = MoodleWebApiConnector.userGradesOf(response([
        gradeItem(id: 1, itemname: 'Course total', itemtype: 'course'),
        gradeItem(id: 2, itemname: 'Category total', itemtype: 'category'),
        gradeItem(id: 3, itemname: 'Quiz 1'),
      ]));

      expect(grades!.gradeItems.where((e) => e.isCourseTotal).map((e) => e.id),
          [1]);
    });

    test('usergrades 是空清單時回 null（不要回一個空成績的「成功」物件）', () {
      // 回空物件的話畫面會顯示一片空白的成功，而且那包空資料還會被寫進快取。
      expect(
        MoodleWebApiConnector.userGradesOf(
            {'usergrades': <dynamic>[], 'warnings': <dynamic>[]}),
        isNull,
      );
      expect(MoodleWebApiConnector.userGradesOf({'warnings': []}), isNull);
    });

    test('回應根本不是 Map 時回 null，不會拋', () {
      expect(MoodleWebApiConnector.userGradesOf(null), isNull);
      expect(MoodleWebApiConnector.userGradesOf(<dynamic>[]), isNull);
      expect(MoodleWebApiConnector.userGradesOf('boom'), isNull);
    });

    test('缺席與 null 的選用欄位一律退回預設值，不會拋', () {
      // 把選用欄位寫成必填會讓整頁掛掉。
      final grades = MoodleWebApiConnector.userGradesOf({
        'usergrades': [
          {
            'gradeitems': [<String, dynamic>{}]
          }
        ]
      });

      expect(grades, isNotNull);
      expect(grades!.courseId, 0);
      expect(grades.gradeItems.single.itemName, isNull);
      expect(grades.gradeItems.single.gradeFormatted, '');
    });

    test('wsfunction 名稱是 grade_items，不是 grades_table', () {
      expect(MoodleWebApiConnector.gradeItemsFunction,
          'gradereport_user_get_grade_items');
    });
  });

  group('沒有 itemname 的列（實機回歸）', () {
    MoodleGradeItemEntity item(String type, {String? name}) =>
        MoodleGradeItemEntity.fromJson({
          'itemtype': type,
          if (name != null) 'itemname': name,
          'gradeformatted': '360.00',
        });

    test('課程總分沒有 itemname 也要留下來', () {
      // Moodle 對課程總分與類別總分就是不送 itemname，用「itemname 非空」
      // 過濾會讓總分那一列整列從畫面上消失。
      expect(item('course').hasDisplayableContent, isTrue);
      expect(item('category').hasDisplayableContent, isTrue);
    });

    test('一般項目沒有 itemname 就沒有東西可顯示，照樣濾掉', () {
      expect(item('mod').hasDisplayableContent, isFalse);
      expect(item('mod', name: '  ').hasDisplayableContent, isFalse);
      expect(item('mod', name: 'Midterm 1').hasDisplayableContent, isTrue);
    });

    test('isCourseTotal / isCategoryTotal 看的是與語系無關的 itemtype', () {
      // 比對寫死的中文字串「課程總分」在英文介面完全失效。
      expect(item('course').isCourseTotal, isTrue);
      expect(item('category').isCategoryTotal, isTrue);
      expect(item('mod', name: '課程總分').isCourseTotal, isFalse);
    });
  });
}
