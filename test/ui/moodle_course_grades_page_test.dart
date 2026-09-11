import 'package:flutter/material.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/controller/score_page/moodle_course_grades_controller.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_gradereport_overview_course_grades.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/ui/components/page/empty_state.dart';
import 'package:flutter_app/ui/components/page/inline_error_view.dart';
import 'package:flutter_app/ui/components/page/loading_page.dart';
import 'package:flutter_app/ui/components/page/section_empty_state.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/pages/score/moodle_course_grades_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

class _FakeRepo extends MoodleRepository {
  MoodleCourseGradeList? next;
  int calls = 0;

  @override
  Future<MoodleCourseGradeList?> fetchCourseGrades() async {
    calls++;
    return next;
  }
}

/// 「Moodle 目前成績」頁的畫面規格。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRepo repo;

  setUpAll(() async {
    await loadTestL10n();
  });

  setUp(() {
    resetAppStatics();
    repo = _FakeRepo();
    MoodleRepository.instance = repo;
    AuthSession.instance = FakeAuthSession();
    TaskUiDelegate.instance = RecordingUi();
    ConnectivityProbe.instance = FakeConnectivityProbe();
  });

  tearDown(() async {
    MoodleRepository.instance = MoodleRepository();
    AuthSession.instance = const UninstalledAuthSession();
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
    await loadTestL10n();
  });

  MoodleCourseGradeList twoCourses() => MoodleCourseGradeList(
        semester: SemesterJson(year: '115', semester: '1'),
        courses: [
          MoodleCourseGradeItem(
              courseId: 'AT10001', name: '計算機概論', grade: '85.55'),
          MoodleCourseGradeItem(courseId: 'BB20002', name: '微積分', grade: '-'),
        ],
      );

  /// 先把 controller 載好再 pump：這一頁在收到注入的 controller 時不會自己
  /// 再發請求（同 announcement_center_page_test 的做法）。
  Future<MoodleCourseGradesController> pump(
    WidgetTester tester, {
    bool load = true,
    List<MoodleCourseGradeItem>? opened,
  }) async {
    final controller = MoodleCourseGradesController();
    if (load) await controller.load();
    await tester.pumpWidget(GetMaterialApp(
      home: MoodleCourseGradesPage(
        controller: controller,
        onOpenCourse: (course) async => opened?.add(course),
      ),
    ));
    if (load) {
      await tester.pumpAndSettle();
    } else {
      // 載入中的畫面有一個永不停的轉圈，pumpAndSettle 會逾時。
      await tester.pump();
    }
    // 先把畫面拆掉再關掉 Rx：Obx 還掛在上面時關掉來源會在 unmount 時炸。
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
    return controller;
  }

  testWidgets('載入中：轉圈在，但標題與說明卡片已經在畫面上', (tester) async {
    await pump(tester, load: false);

    expect(find.byType(LoadingPage), findsOneWidget);
    expect(find.text('Moodle 目前成績'), findsOneWidget,
        reason: '只有 AppBar 一處；頁面內不再重複一次同名標題');
    expect(find.textContaining('不是學校的正式成績'), findsOneWidget);
  });

  testWidgets('兩門課：課名、課號、分數與學期都在；"-" 照字面顯示', (tester) async {
    repo.next = twoCourses();

    await pump(tester);

    expect(find.text('計算機概論'), findsOneWidget);
    expect(find.text('AT10001'), findsOneWidget);
    expect(find.text('85.55'), findsOneWidget);
    expect(find.text('微積分'), findsOneWidget);
    expect(find.text('-'), findsOneWidget);
    expect(find.text('115-1'), findsOneWidget);
  });

  testWidgets('空清單 → SectionEmptyState，而不是整頁級的 EmptyState', (tester) async {
    repo.next = MoodleCourseGradeList(
        semester: SemesterJson(year: '115', semester: '1'), courses: []);

    await pump(tester);

    expect(find.byType(SectionEmptyState), findsOneWidget);
    expect(find.byType(EmptyState), findsNothing);
    expect(find.text('這學期在 Moodle 上沒有可以顯示的總分'), findsOneWidget);
  });

  testWidgets('失敗 → InlineErrorView，按重新整理會再抓一次', (tester) async {
    repo.next = null;

    await pump(tester);
    expect(find.byType(InlineErrorView), findsOneWidget);
    final before = repo.calls;

    await tester.tap(find.text('重新整理'));
    await tester.pumpAndSettle();

    expect(repo.calls, before + 1);
  });

  testWidgets('Stale：舊資料橫幅與清單同時在', (tester) async {
    repo.next = twoCourses();
    final warmUp = MoodleCourseGradesController();
    await warmUp.load();
    warmUp.dispose();
    repo.next = null;

    await pump(tester);

    expect(find.byIcon(LucideIcons.history), findsOneWidget);
    expect(find.text('計算機概論'), findsOneWidget);
    expect(find.text('115-1'), findsOneWidget, reason: '學期來自快取裡的那一份');
  });

  testWidgets('點一列：onOpenCourse 收到那一列，而且沒有真的導頁', (tester) async {
    repo.next = twoCourses();
    final opened = <MoodleCourseGradeItem>[];

    await pump(tester, opened: opened);
    await tester.tap(find.text('微積分'));
    await tester.pumpAndSettle();

    expect(opened.single.courseId, 'BB20002');
    expect(find.text('微積分'), findsOneWidget, reason: '沒有第二個畫面被推上來');
  });

  testWidgets('分數欄是等寬數字：課名長短不一時分數仍上下對齊', (tester) async {
    repo.next = twoCourses();

    await pump(tester);

    final style = tester.widget<Text>(find.text('85.55')).style!;
    expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
  });

  testWidgets('語系切成英文時標題與說明都跟著走 R.current', (tester) async {
    await loadTestL10n(const Locale('en'));
    repo.next = twoCourses();

    await pump(tester);

    expect(find.text('Moodle running totals'), findsOneWidget);
    expect(
        find.textContaining('not your official NTUST grades'), findsOneWidget);
  });
}
