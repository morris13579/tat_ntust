import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_quizzes_by_courses.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_user_attempts.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_user_best_grade.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/ui/components/page/inline_error_view.dart';
import 'package:flutter_app/ui/components/page/section_empty_state.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_quiz_detail_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/quiz_attempt_chip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/moodle_quiz_fixtures.dart';
import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';
import '../helpers/finders.dart';

/// 測驗頁的畫面規格。三段資料都由假的 repository 供給，不碰網路也不碰快取。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const courseId = 'CS3001701';

  setUpAll(() async {
    await loadTestL10n();
    await initializeDateFormatting();
  });

  setUp(() {
    resetAppStatics();
    AuthSession.instance = FakeAuthSession();
    TaskUiDelegate.instance = RecordingUi();
    ConnectivityProbe.instance = FakeConnectivityProbe(online: false);
    MoodleRepository.instance = MoodleRepository();
  });

  tearDown(() {
    AuthSession.instance = const UninstalledAuthSession();
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
  });

  final courseInfo = CourseInfoJson(
    main:
        CourseMainInfoJson(course: CourseMainJson(id: courseId, name: '作業系統')),
  );

  /// fixture 的第一份：開放時間早就過去（已關閉）、時限一小時、三次、最高分。
  MoodleQuiz q1() => fixtureQuizzes()[0];

  /// fixture 的第二份：完全沒有時間限制、不限次數、沒有說明。
  MoodleQuiz q2() => fixtureQuizzes()[1];

  int unix(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

  MoodleQuizAttempt attempt({
    required int number,
    required String state,
    int timestart = 0,
    int timefinish = 0,
  }) =>
      MoodleQuizAttempt(
        id: number,
        attempt: number,
        state: state,
        timestart: timestart,
        timefinish: timefinish,
      );

  Future<void> pump(
    WidgetTester tester, {
    MoodleQuiz? quiz,
    Result<MoodleQuiz>? quizResult,
    Result<List<MoodleQuizAttempt>>? attempts,
    Result<MoodleQuizBestGrade>? bestGrade,
    List<(String, String)>? opened,
    Size viewSize = const Size(800, 4000),
    bool settle = true,
  }) async {
    // ListView 是懶載入的，超出視窗的段落根本不會被建出來；把視窗拉高，
    // 整頁都在畫面上。
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    MoodleRepository.instance = _SeededRepository(
      quiz: quizResult,
      attempts: attempts ?? const Ok(<MoodleQuizAttempt>[]),
      bestGrade: bestGrade ?? Ok(MoodleQuizBestGrade()),
    );

    await tester.pumpWidget(GetMaterialApp(
      home: CourseQuizDetailPage(
        courseInfo,
        quizId: quiz?.id ?? 5101,
        quiz: quiz,
        errorBuilder: (m) => Text('ERR:$m'),
        openWebView: (title, url) async => opened?.add((title, url)),
      ),
    ));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  /// 把標籤與值釘在同一列，只比對其中一邊會漏掉「值填錯欄」這種串線。
  void expectField(String label, String value) {
    expect(
      find.ancestor(
          of: find.text(label), matching: find.widgetWithText(Row, value)),
      findsOneWidget,
      reason: '「$label」那列的值應該是 $value',
    );
  }

  testWidgets('五段標題與「在網頁作答」都畫出來', (tester) async {
    await pump(tester, quiz: q1());

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('期中考 & 小考')),
      findsOneWidget,
    );
    for (final title in ['開放時間', '作答規則', '我的成績', '作答紀錄', '測驗說明']) {
      expect(find.text(title), findsOneWidget, reason: '缺少 $title');
    }
    expect(find.text('在網頁作答'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('開放時間：已關閉的染紅，兩個時間各一列', (tester) async {
    await pump(tester, quiz: q1());

    final hint = find.textContaining('已關閉');
    expect(hint, findsOneWidget);
    final scheme = Theme.of(tester.element(hint)).colorScheme;
    expect(tester.widget<Text>(hint).style?.color, scheme.error);
    expectField('開放作答', CourseQuizDetailPage.formatUnix(q1().timeopen));
    expectField('關閉作答', CourseQuizDetailPage.formatUnix(q1().timeclose));
  });

  testWidgets('沒有任何時間限制：不畫日期列，提示是中性色', (tester) async {
    await pump(tester, quiz: q2());

    expect(find.text('沒有時間限制'), findsOneWidget);
    expect(find.text('開放作答'), findsNothing);
    expect(find.text('關閉作答'), findsNothing);
    final hint = find.text('沒有時間限制');
    final scheme = Theme.of(tester.element(hint)).colorScheme;
    expect(tester.widget<Text>(hint).style?.color, scheme.onSurfaceVariant);
  });

  testWidgets('開放中：提示說幾天後關閉，不染紅', (tester) async {
    final q = q1()
      ..timeopen = unix(DateTime.now().subtract(const Duration(days: 1)))
      ..timeclose = unix(DateTime.now().add(const Duration(days: 3)));
    await pump(tester, quiz: q);

    final hint = find.textContaining('天後關閉');
    expect(hint, findsOneWidget);
    final scheme = Theme.of(tester.element(hint)).colorScheme;
    expect(tester.widget<Text>(hint).style?.color, scheme.onSurface);
  });

  testWidgets('作答規則：時限、次數與計分方式', (tester) async {
    await pump(tester, quiz: q1());

    expectField('作答時限', '1 小時');
    expectField('可作答次數', '3');
    expectField('計分方式', '最高分');
  });

  testWidgets('沒有時限、不限次數', (tester) async {
    await pump(tester, quiz: q2());

    expectField('作答時限', '沒有時限');
    expectField('可作答次數', '不限次數');
    expectField('計分方式', '平均分');
  });

  testWidgets('90 分鐘的時限寫成「1 小時 30 分鐘」', (tester) async {
    await pump(tester, quiz: q1()..timelimit = 5400);

    expectField('作答時限', '1 小時 30 分鐘');
  });

  testWidgets('作答紀錄：最新的在最上面，完成／作答中各自的時間列', (tester) async {
    final finished = unix(DateTime(2025, 9, 11, 10, 30));
    final started = unix(DateTime(2025, 9, 11, 11, 0));
    await pump(
      tester,
      quiz: q1(),
      attempts: Ok([
        attempt(
            number: 1,
            state: 'finished',
            timestart: finished - 600,
            timefinish: finished),
        attempt(number: 2, state: 'abandoned', timefinish: finished + 100),
        attempt(number: 3, state: 'inprogress', timestart: started),
      ]),
    );

    // 伺服器是 attempt ASC，畫面要最新的在上面。
    final rows = tester
        .widgetList<Text>(find.textContaining('次作答'))
        .map((t) => t.data)
        .toList();
    expect(rows, ['第 3 次作答', '第 2 次作答', '第 1 次作答']);

    expect(find.widgetWithText(QuizAttemptStateChip, '已完成'), findsOneWidget);
    expect(find.widgetWithText(QuizAttemptStateChip, '未完成'), findsOneWidget);
    expect(find.widgetWithText(QuizAttemptStateChip, '作答中'), findsOneWidget);
    // 沒送出的那次用開始時間，timefinish 是 0 印出來會是 1970。
    expectField('開始時間', CourseQuizDetailPage.formatUnix(started));
    expectField('完成時間', CourseQuizDetailPage.formatUnix(finished));

    // 「已用」只算 finished 與 abandoned，作答中的那次還沒消耗次數。
    expect(find.widgetWithText(QuizAttemptsChip, '已用 2 / 3 次'), findsOneWidget);
  });

  testWidgets('不限次數的測驗：籤寫「不限次數」', (tester) async {
    await pump(
      tester,
      quiz: q2(),
      attempts: Ok([attempt(number: 1, state: 'finished', timefinish: 1)]),
    );

    expect(find.widgetWithText(QuizAttemptsChip, '不限次數'), findsOneWidget);
  });

  testWidgets('沒有作答紀錄：區塊級空狀態，不是整頁的 EmptyState', (tester) async {
    await pump(tester, quiz: q1());

    expect(find.byType(SectionEmptyState), findsOneWidget);
    expect(find.text('還沒有作答紀錄'), findsOneWidget);
    // 周圍的區塊都還在。
    expect(find.text('作答規則'), findsOneWidget);
  });

  testWidgets('作答紀錄失敗：只有那一段是就地重試的錯誤畫面', (tester) async {
    await pump(tester, quiz: q1(), attempts: const Failed(FetchFailed('x')));

    expect(find.byType(InlineErrorView), findsOneWidget);
    expect(find.text('x'), findsOneWidget);
    // 不是整頁的 errorBuilder。
    expect(find.textContaining('ERR:'), findsNothing);
    expect(find.text('開放時間'), findsOneWidget);
    expect(find.text('作答規則'), findsOneWidget);
    // 次數籤失敗時什麼都不畫，錯誤已由底下那一段說明。
    expect(find.byType(QuizAttemptsChip), findsNothing);
  });

  testWidgets('成績：hasgrade 為 false 時只寫「尚未有成績」', (tester) async {
    await pump(tester, quiz: q1(), bestGrade: Ok(MoodleQuizBestGrade()));

    expect(find.text('尚未有成績'), findsOneWidget);
    expect(find.text('最佳成績'), findsNothing);
    expect(find.text('及格分數'), findsNothing);
  });

  testWidgets('成績：有分數時畫「12.50 / 20.00」與及格分數', (tester) async {
    await pump(tester,
        quiz: q1(), bestGrade: Ok(fixtureBestGrade('best_grade')));

    expect(find.text('最佳成績'), findsOneWidget);
    expect(find.text('12.50 / 20.00'), findsOneWidget);
    expectField('及格分數', '10.00');
  });

  testWidgets('成績：沒設及格分數時不多畫那一列', (tester) async {
    await pump(tester,
        quiz: q1(), bestGrade: Ok(fixtureBestGrade('best_grade_no_pass')));

    expect(find.text('18.00 / 20.00'), findsOneWidget);
    expect(find.text('及格分數'), findsNothing);
  });

  testWidgets('成績失敗：InlineErrorView，其餘照畫', (tester) async {
    await pump(tester,
        quiz: q1(), bestGrade: const Failed(FetchFailed('boom')));

    expect(find.text('boom'), findsOneWidget);
    expect(find.byType(InlineErrorView), findsOneWidget);
    expect(find.text('作答規則'), findsOneWidget);
  });

  testWidgets('說明：有 HTML 就畫出來', (tester) async {
    await pump(tester, quiz: q1());

    expect(find.textContaining('範圍', findRichText: true), findsOneWidget);
  });

  testWidgets('說明是空字串：畫 nothingHere', (tester) async {
    await pump(tester, quiz: q2());

    expect(find.text(R.current.nothingHere), findsOneWidget);
  });

  testWidgets('測驗本體是 Stale：多一條舊資料橫幅', (tester) async {
    await pump(tester, quizResult: Stale(fixtureQuizzes()[0], const Offline()));

    expect(find.text(R.current.networkError), findsOneWidget);
    expect(buttonWithText(R.current.refresh), findsOneWidget);
    expect(find.text('作答規則'), findsOneWidget);
  });

  testWidgets('找不到這個測驗：整頁走注入的 errorBuilder，AppBar 是「測驗詳情」', (tester) async {
    await pump(tester, quizResult: Failed(FetchFailed(R.current.quizNotFound)));

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('測驗詳情')),
      findsOneWidget,
    );
    expect(find.text('ERR:${R.current.quizNotFound}'), findsOneWidget);
  });

  testWidgets('測驗本體還在載入：整頁是 LoadingPage，沒有任何區塊', (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _PendingQuizRepository();
    MoodleRepository.instance = repo;

    await tester.pumpWidget(GetMaterialApp(
      home: CourseQuizDetailPage(
        courseInfo,
        quizId: 5101,
        errorBuilder: (m) => Text('ERR:$m'),
        openWebView: (title, url) async {},
      ),
    ));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('作答規則'), findsNothing);
    // AppBar 在拿到測驗之前是通用標題。
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('測驗詳情')),
      findsOneWidget,
    );

    repo.pending.complete(const Failed(FetchFailed('x')));
    await tester.pumpAndSettle();
  });

  testWidgets('次數籤在作答紀錄還沒回來時是小轉圈', (tester) async {
    final repo = _PendingAttemptsRepository();
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    MoodleRepository.instance = repo;

    await tester.pumpWidget(GetMaterialApp(
      home: CourseQuizDetailPage(
        courseInfo,
        quizId: 5101,
        quiz: q1(),
        errorBuilder: (m) => Text('ERR:$m'),
        openWebView: (title, url) async {},
      ),
    ));
    await tester.pump();

    expect(find.text('作答規則'), findsOneWidget);
    expect(find.byType(QuizAttemptsChip), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    repo.pending.complete(const Failed(FetchFailed('x')));
    await tester.pumpAndSettle();
  });

  testWidgets('在網頁作答 → 交給注入的 openWebView：cmid 網址加 lang', (tester) async {
    final opened = <(String, String)>[];
    await pump(tester, quiz: q1(), opened: opened);

    await tester.tap(find.text('在網頁作答'));
    await tester.pumpAndSettle();

    expect(opened, hasLength(1));
    expect(opened.single.$1, '期中考 & 小考');
    // 94001 是 coursemodule（cmid），不是 quiz id 5101。
    expect(opened.single.$2,
        startsWith('https://moodle2.ntust.edu.tw/mod/quiz/view.php?id=94001'));
    expect(opened.single.$2, contains('lang='));
  });
}

/// 三段資料直接給定；`null` 的那一段沿用頁面自己的 seed（測驗本體）。
class _SeededRepository extends MoodleRepository {
  _SeededRepository({
    this.quiz,
    required this.attempts,
    required this.bestGrade,
  });

  final Result<MoodleQuiz>? quiz;
  final Result<List<MoodleQuizAttempt>> attempts;
  final Result<MoodleQuizBestGrade> bestGrade;

  @override
  Future<Result<MoodleQuiz>> getQuiz(String courseId, int quizId) async =>
      quiz ?? const Failed(FetchFailed('no seed'));

  @override
  Future<Result<List<MoodleQuizAttempt>>> getQuizAttempts(int quizId,
          {bool background = false}) async =>
      attempts;

  @override
  Future<Result<MoodleQuizBestGrade>> getQuizBestGrade(int quizId,
          {bool background = false}) async =>
      bestGrade;
}

/// 讓測驗本體一直停在「載入中」，才測得到整頁的 LoadingPage 那一幀。
class _PendingQuizRepository extends MoodleRepository {
  final pending = Completer<Result<MoodleQuiz>>();

  @override
  Future<Result<MoodleQuiz>> getQuiz(String courseId, int quizId) =>
      pending.future;

  @override
  Future<Result<List<MoodleQuizAttempt>>> getQuizAttempts(int quizId,
          {bool background = false}) async =>
      const Ok(<MoodleQuizAttempt>[]);

  @override
  Future<Result<MoodleQuizBestGrade>> getQuizBestGrade(int quizId,
          {bool background = false}) async =>
      Ok(MoodleQuizBestGrade());
}

/// 讓作答紀錄一直停在「載入中」，才測得到次數籤的轉圈那一幀。
class _PendingAttemptsRepository extends MoodleRepository {
  final pending = Completer<Result<List<MoodleQuizAttempt>>>();

  @override
  Future<Result<List<MoodleQuizAttempt>>> getQuizAttempts(int quizId,
          {bool background = false}) =>
      pending.future;

  @override
  Future<Result<MoodleQuizBestGrade>> getQuizBestGrade(int quizId,
          {bool background = false}) async =>
      Ok(MoodleQuizBestGrade());
}
