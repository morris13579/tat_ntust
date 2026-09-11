import 'package:flutter_app/src/util/moodle_course_name_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// NTUST 課名前綴的判讀規格。這一份規則同時被行事曆待辦（`courseLabelOf`）
/// 與「Moodle 目前成績」的課名用，所以抽在 util。
void main() {
  test('剝掉 `115.1【AT1001301】` 這種前綴', () {
    expect(
      MoodleCourseNameUtils.stripCoursePrefix('115.1【AT1001301】計算機概論'),
      '計算機概論',
    );
  });

  test('沒有「.」的前綴也剝得掉', () {
    expect(
      MoodleCourseNameUtils.stripCoursePrefix('1151【AT1001301】計算機概論'),
      '計算機概論',
    );
  });

  test('沒有前綴的課名原樣回傳（trim 過）', () {
    expect(MoodleCourseNameUtils.stripCoursePrefix('  計算機概論  '), '計算機概論');
  });

  test('只有前綴、剝完是空字串時退回原字串，不可以回空', () {
    // 回空字串的話畫面上那一列會變成一行空白，比顯示前綴更糟。
    expect(
      MoodleCourseNameUtils.stripCoursePrefix('115.1【AT1001301】'),
      '115.1【AT1001301】',
    );
  });
}
