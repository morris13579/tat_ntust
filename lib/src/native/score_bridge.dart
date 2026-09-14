import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_gradereport_get_grade_items.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_gradereport_overview_course_grades.dart';
import 'package:flutter_app/src/model/score/score_json.dart';
import 'package:flutter_app/src/native/bridge_results.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/ntust_repository.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/moodle_grade_utils.dart';
import 'package:flutter_app/src/util/score_utils.dart';

/// 原生版的成績頁。流程照 `ScorePageController`：先用存著的，沒有或要重新整理才抓；
/// 抓不到時把手上那一份一起回去，錯誤對話框核心的 `run()` 已經問過。
class ScoreBridge implements TatScoreApi {
  static void install() => TatScoreApi.setUp(ScoreBridge());

  @override
  Future<ScoreReport> load(bool refresh) async {
    if (!AuthSession.instance.isSignedIn) {
      return ScoreReport(state: ScoreState.notSignedIn, semesters: []);
    }
    await Model.instance.loadScore();
    var semesters = Model.instance.getScore().info;
    var state = ScoreState.ok;
    if (semesters.isEmpty || refresh) {
      final data = (await NtustRepository.instance.getScoreRank()).dataOrNull;
      if (data == null) {
        state = ScoreState.failed;
      } else {
        Model.instance.setScore(data);
        await Model.instance.saveScore();
        semesters = data.info;
      }
    }
    ScoreUtils.sortForDisplay(semesters);
    return ScoreReport(
      state: state,
      semesters: [for (final semester in semesters) _semester(semester)],
    );
  }

  @override
  Future<MoodleGrades> moodleGrades(bool refresh) async {
    final result =
        await MoodleRepository.instance.getCourseGrades(background: !refresh);
    final data = result.dataOrNull;
    final semester = data?.semester;
    return MoodleGrades(
      semester: semester == null || semester.isEmpty
          ? null
          : '${semester.year}-${semester.semester}',
      courses: [
        for (final course in data?.courses ?? const <MoodleCourseGradeItem>[])
          MoodleGradeCourse(
              courseId: course.courseId,
              name: course.name,
              grade: course.grade),
      ],
      error: BridgeResults.errorOf(result),
      notice: BridgeResults.noticeOf(result),
      signedIn: AuthSession.instance.isSignedIn,
    );
  }

  @override
  Future<MoodleCourseScore> courseScore(String courseId) async {
    final result = await MoodleRepository.instance.getCourseScore(courseId);
    final items =
        result.dataOrNull?.gradeItems ?? const <MoodleGradeItemEntity>[];
    return MoodleCourseScore(
      rows: [
        for (final item in items)
          if (item.hasDisplayableContent) _row(item),
      ],
      error: BridgeResults.errorOf(result),
      notice: BridgeResults.noticeOf(result),
      signedIn: AuthSession.instance.isSignedIn,
    );
  }

  static ScoreSemester _semester(SemesterScoreJson semester) {
    final gpa = ScoreUtils.calculateGPA(semester.item);
    return ScoreSemester(
      semester: '${semester.semester.year}-${semester.semester.semester}',
      // calculateGPA 一門有效成績都沒有時回字面上的 "NaN"。
      gpa: gpa == 'NaN' ? null : gpa,
      credits: ScoreUtils.passedCredit(semester.item),
      failed: ScoreUtils.failedCount(semester.item),
      courses: [
        for (final item in semester.item)
          ScoreCourse(
            courseId: item.courseId,
            name: item.name,
            credits: ScoreUtils.parseCredit(item.credit),
            dimension:
                item.generalDimension.isEmpty ? null : item.generalDimension,
            label: ScoreUtils.scoreLabel(item),
            failed: item.isFailScore,
          ),
      ],
    );
  }

  static MoodleGradeRow _row(MoodleGradeItemEntity item) {
    final hasFeedback = MoodleGradeUtils.hasFeedback(item.feedback);
    final grade = MoodleGradeUtils.plain(item.gradeFormatted);
    final meta = MoodleGradeUtils.metaOf(item, hasFeedback: hasFeedback);
    return MoodleGradeRow(
      id: item.id,
      title: MoodleGradeUtils.titleOf(item),
      kind: item.isCourseTotal
          ? GradeRowKind.course
          : item.isCategoryTotal
              ? GradeRowKind.category
              : GradeRowKind.item,
      meta: meta.isEmpty ? null : meta,
      grade: MoodleGradeUtils.hasContent(grade) ? grade : null,
      feedback: hasFeedback ? item.feedback : null,
    );
  }

}
