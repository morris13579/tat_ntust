import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:sprintf/sprintf.dart';

typedef CourseInfoFactRow = ({String label, String value, String? footnote});
typedef CourseInfoText = ({String title, String body});

/// querycourse 的課程資訊怎麼排：哪些上表格、哪些收進「其餘欄位」。
/// Flutter 的課程資訊頁與原生版共用這一份。
class CourseExtraInfoUtils {
  CourseExtraInfoUtils._();

  /// 「課號 · 學年期」。
  static String subtitle(CourseExtraInfoJson info) =>
      [info.courseNo, info.semester]
          .where((text) => text.trim().isNotEmpty)
          .join(' · ');

  /// 必修、學分、全年這三個標籤。
  static List<String> chips(CourseExtraInfoJson info) => [
        info.requireOption.trim(),
        if (info.creditPoint.trim().isNotEmpty)
          sprintf(R.current.creditCount, [info.creditPoint.trim()]),
        info.allYear.trim(),
      ].where((text) => text.isNotEmpty).toList();

  /// 短欄位的表格，空的欄位不出現。
  static List<CourseInfoFactRow> facts(CourseExtraInfoJson info) {
    final rows = <CourseInfoFactRow>[];

    void add(String label, String value, {String? footnote}) {
      if (value.trim().isEmpty) return;
      rows.add((label: label, value: value, footnote: footnote));
    }

    add(R.current.instructor, info.courseTeacher);
    add(R.current.classRoomNo, info.classRoomNo);
    if (info.courseTimes.isNotEmpty || info.practicalTimes.isNotEmpty) {
      add(
        R.current.courseAndPracticalTimes,
        sprintf(R.current.hoursValue, [info.courseTimes, info.practicalTimes]),
      );
    }
    add(
      R.current.enrolledCount,
      info.allStudent.isEmpty
          ? ''
          : sprintf(R.current.enrolledCountValue,
              [info.allStudent, info.chooseStudent, info.threeStudent]),
      footnote: limitSummary(info),
    );
    return rows;
  }

  /// 三個上限任何一個缺就整條不顯示——半條數字比沒有還難懂。
  static String? limitSummary(CourseExtraInfoJson info) {
    final ntu = int.tryParse(info.nTURestrict.trim());
    final ntnu = int.tryParse(info.nTNURestrict.trim());
    if (info.restrict1.isEmpty || info.restrict2.isEmpty) return null;
    if (ntu == null || ntnu == null) return null;
    return sprintf(R.current.enrollmentLimitSummary,
        [info.restrict1, info.restrict2, ntu + ntnu]);
  }

  /// 收進「其餘欄位」的長欄位，空的不出現。
  static List<CourseInfoText> moreFields(CourseExtraInfoJson info) => [
        (title: R.current.courseContent, body: info.courseContent.trim()),
        (title: _booksTitle(info), body: _books(info)),
        (title: R.current.courseNote, body: info.courseNote.trim()),
        (title: R.current.coreAbility, body: info.coreAbility.trim()),
        (title: R.current.courseRemark, body: info.courseRemark.trim()),
      ].where((item) => item.body.isNotEmpty).toList();

  static String _booksTitle(CourseExtraInfoJson info) {
    if (info.courseTextbook.trim().isEmpty) return R.current.courseRefbook;
    if (info.courseRefbook.trim().isEmpty) return R.current.courseTextbook;
    return R.current.courseTextbookAndRefbook;
  }

  static String _books(CourseExtraInfoJson info) =>
      [info.courseTextbook.trim(), info.courseRefbook.trim()]
          .where((text) => text.isNotEmpty)
          .join('\n');
}
