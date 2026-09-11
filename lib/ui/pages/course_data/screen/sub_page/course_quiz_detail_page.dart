import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/controller/course_data/course_quiz_controller.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_quizzes_by_courses.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_user_attempts.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_user_best_grade.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:flutter_app/src/util/moodle_quiz_utils.dart';
import 'package:flutter_app/ui/components/card/section_card.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/html/moodle_html_view.dart';
import 'package:flutter_app/ui/components/page/inline_error_view.dart';
import 'package:flutter_app/ui/components/page/result_view.dart';
import 'package:flutter_app/ui/components/page/section_empty_state.dart';
import 'package:flutter_app/ui/components/page/web_view_opener.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/quiz_attempt_chip.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sprintf/sprintf.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';

/// 一個測驗的唯讀資訊；作答一律走「在網頁作答」。錯誤畫面與 WebView 開啟器
/// 由呼叫端注入，見 docs/ARCHITECTURE.md「UI 慣例」。
class CourseQuizDetailPage extends StatefulWidget {
  const CourseQuizDetailPage(
    this.courseInfo, {
    required this.quizId,
    this.quiz,
    required this.errorBuilder,
    required this.openWebView,
    super.key,
  });

  final CourseInfoJson courseInfo;

  /// quiz instance id（`MoodleQuiz.id` / `Modules.instance`）。
  final int quizId;

  /// 手上已有就不重抓。
  final MoodleQuiz? quiz;

  final Widget Function(String message) errorBuilder;
  final WebViewOpener openWebView;

  static String formatUnix(int unix) => DateFormat.yMd()
      .add_jm()
      .format(DateTime.fromMillisecondsSinceEpoch(unix * 1000));

  @override
  State<CourseQuizDetailPage> createState() => _CourseQuizDetailPageState();
}

class _CourseQuizDetailPageState extends State<CourseQuizDetailPage> {
  late final CourseQuizController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CourseQuizController(
      courseId: widget.courseInfo.main.course.id,
      quizId: widget.quizId,
      quiz: widget.quiz,
    );
    unawaited(_controller.loadAll());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _courseName => widget.courseInfo.main.course.name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Obx(() => baseAppbar(
            title: _controller.quiz.value?.dataOrNull?.name ??
                R.current.quizDetail)),
      ),
      body: ResultView<MoodleQuiz>(
        state: _controller.quiz,
        onRetry: _controller.loadQuiz,
        errorBuilder: widget.errorBuilder,
        builder: _buildBody,
      ),
    );
  }

  Widget _buildBody(MoodleQuiz q) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        SectionHeader(
          icon: LucideIcons.calendarClock,
          title: R.current.quizSectionWindow,
          first: true,
        ),
        _windowCard(q),
        SectionHeader(
          icon: LucideIcons.timer,
          title: R.current.quizSectionRules,
          trailing: Obx(
              () => QuizAttemptsChip.fromResult(q, _controller.attempts.value)),
        ),
        _rulesCard(q),
        SectionHeader(
          icon: LucideIcons.award,
          title: R.current.quizSectionGrade,
        ),
        _gradeCard(q),
        SectionHeader(
          icon: LucideIcons.listOrdered,
          title: R.current.quizSectionAttempts,
        ),
        _attemptsCard(),
        SectionHeader(
          icon: LucideIcons.fileText,
          title: R.current.quizIntro,
        ),
        _introCard(q),
        const SizedBox(height: 28),
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () => unawaited(_openInWeb(q)),
          icon: const Icon(LucideIcons.externalLink),
          label: Text(R.current.quizAnswerInWeb),
        ),
      ],
    );
  }

  Widget _windowCard(MoodleQuiz q) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final hint =
        MoodleQuizUtils.windowHint(q.timeopen, q.timeclose, DateTime.now());
    // 染紅只給「已關閉」，與 windowHint 的 kind 同源；timeopen / timeclose
    // 為 0 一律是「沒有時間限制」。
    final color = switch (hint.kind) {
      QuizWindowKind.closed => scheme.error,
      QuizWindowKind.always => scheme.onSurfaceVariant,
      _ => scheme.onSurface,
    };
    return SectionCard([
      Text(
        quizWindowHintText(hint),
        style: text.titleMedium?.copyWith(
          height: 1.25,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      if (q.hasOpenWindow) ...[
        const SectionDivider(),
        if (q.timeopen > 0)
          SectionField(R.current.quizTimeOpen,
              CourseQuizDetailPage.formatUnix(q.timeopen)),
        if (q.timeclose > 0)
          SectionField(R.current.quizTimeClose,
              CourseQuizDetailPage.formatUnix(q.timeclose)),
      ],
    ]);
  }

  Widget _rulesCard(MoodleQuiz q) {
    return SectionCard([
      SectionField(
        R.current.quizTimeLimit,
        q.hasTimeLimit
            ? quizDurationText(q.timelimit)
            : R.current.quizNoTimeLimit,
      ),
      SectionField(
        R.current.quizAttemptsAllowed,
        q.isUnlimitedAttempts
            ? R.current.quizAttemptsUnlimited
            : "${q.attempts}",
      ),
      SectionField(
        R.current.quizGradeMethod,
        quizGradeMethodText(MoodleQuizUtils.gradeMethodOf(q.grademethod)),
      ),
    ]);
  }

  /// 嵌在沒有高度上限的 ListView 裡所以開 `shrinkWrap`；失敗畫
  /// [InlineErrorView] 而不是整頁 errorBuilder，頁面其餘部分都還在。
  Widget _gradeCard(MoodleQuiz q) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ResultView<MoodleQuizBestGrade>(
      shrinkWrap: true,
      state: _controller.bestGrade,
      onRetry: _controller.loadBestGrade,
      errorBuilder: (message) =>
          InlineErrorView(message: message, onRetry: _controller.loadBestGrade),
      // hasgrade == false 涵蓋「沒作答」與「老師關掉分數顯示」，伺服器沒有
      // 再細分的訊號。
      builder: (g) => SectionCard([
        if (!g.hasgrade)
          Text(R.current.quizNoGrade,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))
        else ...[
          Text(R.current.quizBestGrade,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(
            sprintf(R.current.quizGradeOutOf, [
              MoodleQuizUtils.formatGrade(g.grade, q.decimalpoints),
              MoodleQuizUtils.formatGrade(q.grade, q.decimalpoints),
            ]),
            style: text.titleLarge?.copyWith(
                fontWeight: FontWeight.w600, color: scheme.onSurface),
          ),
        ],
        if (g.hasGradeToPass) ...[
          const SizedBox(height: 6),
          SectionField(R.current.quizGradeToPass,
              MoodleQuizUtils.formatGrade(g.gradetopass, q.decimalpoints)),
        ],
      ]),
    );
  }

  Widget _attemptsCard() {
    return ResultView<List<MoodleQuizAttempt>>(
      shrinkWrap: true,
      state: _controller.attempts,
      onRetry: _controller.loadAttempts,
      errorBuilder: (message) =>
          InlineErrorView(message: message, onRetry: _controller.loadAttempts),
      builder: (list) {
        if (list.isEmpty) {
          return SectionEmptyState(
            icon: LucideIcons.listOrdered,
            message: R.current.quizAttemptsEmpty,
          );
        }
        final sorted = MoodleQuizUtils.sortForList(list);
        return SectionCard([
          for (var i = 0; i < sorted.length; i++) ...[
            if (i > 0) const SectionDivider(),
            _attemptRow(sorted[i]),
          ],
        ]);
      },
    );
  }

  Widget _attemptRow(MoodleQuizAttempt a) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                sprintf(R.current.quizAttemptNumber, [a.attempt]),
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            QuizAttemptStateChip(MoodleQuizUtils.attemptStateOf(a.state)),
          ],
        ),
        // 沒送出的用開始時間：timefinish 是 0，印出來會是 1970。
        if (a.hasFinished)
          SectionField(R.current.quizAttemptFinishedAt,
              CourseQuizDetailPage.formatUnix(a.timefinish))
        else if (a.timestart > 0)
          SectionField(R.current.quizAttemptStartedAt,
              CourseQuizDetailPage.formatUnix(a.timestart)),
      ],
    );
  }

  Widget _introCard(MoodleQuiz q) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final intro = q.intro ?? "";
    return SectionCard([
      if (intro.trim().isEmpty)
        Text(R.current.nothingHere,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))
      else
        MoodleHtmlView(
          html: intro,
          title: q.name,
          dirName: _courseName,
          openWebView: widget.openWebView,
        ),
    ]);
  }

  /// 網頁版測驗頁。這裡不呼叫 `autologinUrl`：注入的 [openWebView] 自己會換，
  /// 再換一次等於在六分鐘的伺服器節流內多燒一把鑰匙。
  Future<void> _openInWeb(MoodleQuiz q) async {
    final url = Connector.uriAddQuery(
      MoodleWebApiConnector.quizViewUrl(q.coursemodule),
      {"lang": LanguageUtils.getLangIndex() == LangEnum.zh ? "zh_tw" : "en"},
    );
    await widget.openWebView(q.name, url);
  }
}
