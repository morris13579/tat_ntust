import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_quizzes_by_courses.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_user_attempts.dart';
import 'package:flutter_app/src/native/bridge_results.dart';
import 'package:flutter_app/src/native/course_moodle_bridge.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/util/moodle_quiz_text.dart';
import 'package:flutter_app/src/util/moodle_quiz_utils.dart';
import 'package:sprintf/sprintf.dart';

/// 原生版的測驗詳情，照 `CourseQuizController` 與 `course_quiz_detail_page.dart`。
/// 只給看；作答一律去網頁。
class QuizBridge implements TatQuizApi {
  QuizBridge({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static void install() => TatQuizApi.setUp(QuizBridge());

  final DateTime Function() _now;
  final Map<int, MoodleQuiz> _quizzes = {};

  @override
  Future<QuizDetailResult> detail(
      String courseId, int quizId, bool refresh) async {
    // 三個一起發。兩支次要的在進頁時走背景：一次網路失敗會讓三支同時失敗，
    // 而重試框沒有去重，使用者得連關三個才看得到畫面。
    final quizRequest = MoodleRepository.instance.getQuiz(courseId, quizId);
    final attemptsRequest = MoodleRepository.instance
        .getQuizAttempts(quizId, background: !refresh);
    final gradeRequest = MoodleRepository.instance
        .getQuizBestGrade(quizId, background: !refresh);
    final quiz = await quizRequest;
    final attempts = await attemptsRequest;
    final grade = await gradeRequest;
    final q = quiz.dataOrNull;
    if (q == null) {
      return QuizDetailResult(
        error: BridgeResults.errorOf(quiz),
        signedIn: AuthSession.instance.isSignedIn,
      );
    }
    _quizzes[quizId] = q;
    final hint = MoodleQuizUtils.windowHint(q.timeopen, q.timeclose, _now());
    final list = attempts.dataOrNull;
    final used = list == null ? null : MoodleQuizUtils.attemptsUsed(list);
    final best = grade.dataOrNull;
    return QuizDetailResult(
      detail: QuizDetail(
        name: q.name,
        windowHint: quizWindowHintText(hint),
        windowTone: switch (hint.kind) {
          QuizWindowKind.always => QuizWindowTone.always,
          QuizWindowKind.beforeOpen => QuizWindowTone.upcoming,
          QuizWindowKind.open => QuizWindowTone.open,
          QuizWindowKind.closed => QuizWindowTone.closed,
        },
        windowFields: [
          if (q.timeopen > 0)
            FieldRow(
                label: R.current.quizTimeOpen,
                value: quizFormatUnix(q.timeopen)),
          if (q.timeclose > 0)
            FieldRow(
                label: R.current.quizTimeClose,
                value: quizFormatUnix(q.timeclose)),
        ],
        rules: [
          FieldRow(
            label: R.current.quizTimeLimit,
            value: q.hasTimeLimit
                ? quizDurationText(q.timelimit)
                : R.current.quizNoTimeLimit,
          ),
          FieldRow(
            label: R.current.quizAttemptsAllowed,
            value: q.isUnlimitedAttempts
                ? R.current.quizAttemptsUnlimited
                : '${q.attempts}',
          ),
          FieldRow(
            label: R.current.quizGradeMethod,
            value: quizGradeMethodText(
                MoodleQuizUtils.gradeMethodOf(q.grademethod)),
          ),
        ],
        attemptsChipLabel: used == null ? null : QuizAttemptsText.label(q, used),
        attemptsChipTone: used == null
            ? null
            : (QuizAttemptsText.exhausted(q, used)
                ? StatusTone.overdue
                : StatusTone.pending),
        attemptsChipStale: attempts.dataOrNull != null &&
            BridgeResults.noticeOf(attempts) != null,
        gradeError: BridgeResults.errorOf(grade),
        // hasgrade == false 涵蓋「沒作答」與「老師關掉分數顯示」，伺服器沒有再細分的訊號。
        bestGrade: best == null || !best.hasgrade
            ? null
            : sprintf(R.current.quizGradeOutOf, [
                MoodleQuizUtils.formatGrade(best.grade, q.decimalpoints),
                MoodleQuizUtils.formatGrade(q.grade, q.decimalpoints),
              ]),
        gradeToPass: best == null || !best.hasGradeToPass
            ? null
            : MoodleQuizUtils.formatGrade(best.gradetopass, q.decimalpoints),
        attemptsError: BridgeResults.errorOf(attempts),
        attempts: [
          for (final a in MoodleQuizUtils.sortForList(list ?? const []))
            _attempt(a),
        ],
        introHtml: (q.intro ?? '').trim().isEmpty ? null : q.intro,
        notice: BridgeResults.noticeOf(quiz),
      ),
      signedIn: AuthSession.instance.isSignedIn,
    );
  }

  @override
  Future<WebLink?> answerLink(String courseId, int quizId) async {
    final q = _quizzes[quizId];
    if (q == null) return null;
    return CourseMoodleBridge.webLinkOf(CourseMoodleBridge.withLang(
        MoodleWebApiConnector.quizViewUrl(q.coursemodule)));
  }

  static QuizAttemptRow _attempt(MoodleQuizAttempt a) {
    final state = MoodleQuizUtils.attemptStateOf(a.state);
    return QuizAttemptRow(
      title: sprintf(R.current.quizAttemptNumber, [a.attempt]),
      stateLabel: quizAttemptStateText(state),
      tone: switch (state) {
        QuizAttemptState.finished => StatusTone.graded,
        QuizAttemptState.submitted => StatusTone.submitted,
        QuizAttemptState.inProgress => StatusTone.draft,
        QuizAttemptState.overdue => StatusTone.overdue,
        QuizAttemptState.abandoned ||
        QuizAttemptState.notStarted ||
        QuizAttemptState.unknown =>
          StatusTone.pending,
      },
      // 沒送出的用開始時間：timefinish 是 0，印出來會是 1970。
      time: a.hasFinished
          ? FieldRow(
              label: R.current.quizAttemptFinishedAt,
              value: quizFormatUnix(a.timefinish))
          : (a.timestart > 0
              ? FieldRow(
                  label: R.current.quizAttemptStartedAt,
                  value: quizFormatUnix(a.timestart))
              : null),
    );
  }
}
