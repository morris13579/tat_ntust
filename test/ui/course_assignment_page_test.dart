import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/controller/course_data/course_data_controller.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/store/cache_store.dart';
import 'package:flutter_app/ui/pages/course_data/screen/course_assignment_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_assignment_detail_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/assign_status_chip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/moodle_assign_fixtures.dart';
import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 課程頁「作業」分頁的畫面規格。離線、快取預先塞好，與 course_score_page_test
/// 同一套；狀態籤的資料來自快取所以一律是 Stale（帶時鐘小圖示）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const courseId = 'CS3001701';

  setUpAll(() async {
    await loadTestL10n();
    // DateFormat.yMd() 需要 zh_TW 的日期符號。
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

  int unix(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

  Future<void> seedAssignments(List<MoodleAssignment> list) =>
      CacheStore.instance.write(
        CacheKey<List<MoodleAssignment>>(
          'cache_moodle_assign',
          courseId,
          decode: (json) => (json as List)
              .map((e) => MoodleAssignment.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList(),
        ),
        list,
      );

  Future<void> seedStatus(int assignId, MoodleAssignSubmissionStatus s) =>
      CacheStore.instance.write(
        CacheKey<MoodleAssignSubmissionStatus>(
          'cache_moodle_assign_status',
          assignId.toString(),
          decode: (json) => MoodleAssignSubmissionStatus.fromJson(
              Map<String, dynamic>.from(json as Map)),
        ),
        s,
      );

  Future<CourseDataController> pump(
    WidgetTester tester, {
    List<(String, String)>? opened,
  }) async {
    final controller = CourseDataController(courseId);
    await controller.loadAssignments();
    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(
        body: CourseAssignmentPage(
          courseInfo,
          controller: controller,
          errorBuilder: (m) => Text('ERR:$m'),
          openWebView: (title, url) async => opened?.add((title, url)),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    addTearDown(controller.dispose);
    return controller;
  }

  /// fixture 的兩份：HW1（截止 2025-09-11，早就過了）與期末專題（沒有截止）。
  List<MoodleAssignment> twoFromFixture() => fixtureAssignments();

  testWidgets('兩份作業：名稱已還原 HTML 實體、逾期那一行與「沒有截止日期」', (tester) async {
    await seedAssignments(twoFromFixture());
    await seedStatus(4101, fixtureStatus('status_none'));

    await pump(tester);

    // 伺服器 format_string 過的 `HW1 &amp; Report`，connector 已還原。
    expect(find.text('HW1 & Report'), findsOneWidget);
    expect(find.textContaining('&amp;'), findsNothing);
    expect(find.text('期末專題'), findsOneWidget);
    // 沒交又過期：那一行只講逾期幾天，日期讓位給它。
    expect(find.textContaining('已逾期 '), findsOneWidget);
    expect(find.text('沒有截止日期'), findsOneWidget);
  });

  testWidgets('狀態籤：已評分；沒有狀態快取的那一份不畫籤', (tester) async {
    await seedAssignments(twoFromFixture());
    await seedStatus(4101, fixtureStatus('status_graded'));

    await pump(tester);

    // 快取（Stale）的成績留在籤上：籤才有「這是舊資料」的記號，
    // 一個裸分數說不出自己是什麼時候的。
    expect(find.widgetWithText(AssignStatusChip, '已評分'), findsOneWidget);
    expect(find.byType(AssignStatusChip), findsOneWidget,
        reason: '4102 沒有快取 → Failed → 不畫籤');
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('已評分：那一行是「截止日 · 已評分」，沒有逾期天數', (tester) async {
    // fixture 的 HW1 早就過了截止，而且是遲交的。評完之後遲不遲到不再是
    // 使用者要處理的事，掛著「已逾期 N 天」會讓一份結案的作業看起來還欠著。
    await seedAssignments([twoFromFixture().first]);
    await seedStatus(4101, fixtureStatus('status_graded'));

    await pump(tester);

    expect(find.textContaining('已逾期'), findsNothing);
    expect(find.textContaining('截止 · 已評分'), findsOneWidget);
  });

  testWidgets('已繳交等待評分：那一行是繳交日，籤是待評分', (tester) async {
    // status_graded 換成只有繳交、沒有成績的那一份。
    final s = fixtureStatus('status_graded')
      ..feedback = null
      ..lastattempt!.gradingstatus = 'notgraded';
    await seedAssignments([twoFromFixture().first]);
    await seedStatus(4101, s);

    await pump(tester);

    expect(find.widgetWithText(AssignStatusChip, '待評分'), findsOneWidget);
    expect(find.textContaining('已逾期'), findsNothing);
    expect(find.textContaining('繳交'), findsOneWidget);
  });

  testWidgets('狀態籤：草稿過了截止是已逾期', (tester) async {
    await seedAssignments(twoFromFixture());
    await seedStatus(4101, fixtureStatus('status_draft'));

    await pump(tester);

    expect(find.widgetWithText(AssignStatusChip, '已逾期'), findsOneWidget);
  });

  testWidgets('草稿還沒到期：文件圖示、最後編輯日、籤是草稿', (tester) async {
    final a = twoFromFixture().first
      ..duedate = unix(DateTime.now().add(const Duration(days: 3)));
    await seedAssignments([a]);
    await seedStatus(4101, fixtureStatus('status_draft'));

    await pump(tester);

    expect(find.widgetWithText(AssignStatusChip, '草稿'), findsOneWidget);
    // 驚嘆號是「還沒動」，草稿已經寫了東西，用文件圖示。
    expect(find.byIcon(LucideIcons.fileText), findsOneWidget);
    expect(find.byIcon(LucideIcons.circleAlert), findsNothing);
    expect(find.textContaining('最後編輯'), findsOneWidget);
  });

  testWidgets('有延長期限：那一行講延長到哪一天加剩幾天，籤是已延長', (tester) async {
    // duedate 早就過了，但延長到 5 天後。
    final a = twoFromFixture().first;
    await seedAssignments([a]);
    await seedStatus(
      4101,
      MoodleAssignSubmissionStatus(
        lastattempt: MoodleAssignLastAttempt(
          extensionduedate: unix(DateTime.now().add(const Duration(days: 5))),
          gradingstatus: 'notgraded',
        ),
      ),
    );

    await pump(tester);

    // 籤說「未繳交」、旁邊那一行說「延長至……」的話，兩句話對不起來。
    expect(find.widgetWithText(AssignStatusChip, '已延長'), findsOneWidget);
    expect(find.textContaining('已逾期'), findsNothing);
    final line = find.textContaining('延長至 ');
    expect(line, findsOneWidget);
    expect(tester.widget<Text>(line).data, contains(' · 剩 '));
  });

  testWidgets('離線評分的作業：不需繳交，過了截止也不是已逾期', (tester) async {
    final a = twoFromFixture().first..nosubmissions = 1;
    await seedAssignments([a]);
    await seedStatus(4101, fixtureStatus('status_none'));

    await pump(tester);

    expect(find.widgetWithText(AssignStatusChip, '不需繳交'), findsOneWidget);
    expect(find.widgetWithText(AssignStatusChip, '已逾期'), findsNothing);
  });

  testWidgets('狀態籤：沒繳交且還沒截止是未繳交，那一行是「剩 N 天 · 截止時間」', (tester) async {
    final a = twoFromFixture().first
      ..duedate = unix(DateTime.now().add(const Duration(days: 3)));
    await seedAssignments([a]);
    await seedStatus(4101, fixtureStatus('status_none'));

    await pump(tester);

    expect(find.widgetWithText(AssignStatusChip, '未繳交'), findsOneWidget);
    final line = find.textContaining('剩 ');
    expect(line, findsOneWidget);
    expect(tester.widget<Text>(line).data, startsWith('剩 '));
    expect(tester.widget<Text>(line).data, contains(' · '));
  });

  testWidgets('清單頂上那一句：件數，全部評完才加「全部已評分」', (tester) async {
    await seedAssignments(twoFromFixture());
    // 只有一份有狀態，另一份連狀態都抓不到——這時不敢說全部評完。
    await seedStatus(4101, fixtureStatus('status_graded'));

    await pump(tester);

    expect(find.text('2 件'), findsOneWidget);
    expect(find.textContaining('全部已評分'), findsNothing);
  });

  testWidgets('每一份都評完了才會說「全部已評分」', (tester) async {
    await seedAssignments(twoFromFixture());
    await seedStatus(4101, fixtureStatus('status_graded'));
    await seedStatus(4102, fixtureStatus('status_graded'));

    await pump(tester);

    expect(find.text('2 件 · 全部已評分'), findsOneWidget);
  });

  testWidgets('來自快取的籤帶時鐘小圖示', (tester) async {
    await seedAssignments(twoFromFixture());
    await seedStatus(4101, fixtureStatus('status_graded'));

    await pump(tester);

    expect(
      find.descendant(
        of: find.byType(AssignStatusChip),
        matching: find.byIcon(LucideIcons.history),
      ),
      findsOneWidget,
    );
  });

  testWidgets('空清單 → 「這門課沒有作業」', (tester) async {
    await seedAssignments(const []);

    await pump(tester);

    expect(find.text('這門課沒有作業'), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
    expect(find.byType(AssignStatusChip), findsNothing);
  });

  testWidgets('清單失敗 → 注入的 errorBuilder', (tester) async {
    await pump(tester);

    expect(find.text('ERR:${R.current.networkError}'), findsOneWidget);
  });

  testWidgets('排序：未截止（升冪）、沒有截止、已截止（降冪）；延長期限算未截止', (tester) async {
    final now = DateTime.now();
    MoodleAssignment a(int id, String name, Duration? offset) =>
        MoodleAssignment(
          id: id,
          cmid: id,
          name: name,
          duedate: offset == null ? 0 : unix(now.add(offset)),
        );
    await seedAssignments([
      a(1, 'A past 1d', const Duration(days: -1)),
      a(2, 'B future 1d', const Duration(days: 1)),
      a(3, 'C none', null),
      a(4, 'D past 5d', const Duration(days: -5)),
      a(5, 'E future 3d', const Duration(days: 3)),
      a(6, 'F past but extended 2d', const Duration(days: -2)),
    ]);
    await seedStatus(
      6,
      MoodleAssignSubmissionStatus(
        lastattempt: MoodleAssignLastAttempt(
          extensionduedate: unix(now.add(const Duration(days: 2))),
          gradingstatus: 'notgraded',
        ),
      ),
    );

    await pump(tester);

    double y(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(y('B future 1d'), lessThan(y('F past but extended 2d')));
    expect(y('F past but extended 2d'), lessThan(y('E future 3d')));
    expect(y('E future 3d'), lessThan(y('C none')));
    expect(y('C none'), lessThan(y('A past 1d')));
    expect(y('A past 1d'), lessThan(y('D past 5d')));
  });

  testWidgets('點一列 → 進詳情頁，狀態沿用清單那一顆（不再轉圈）', (tester) async {
    await seedAssignments(twoFromFixture());
    await seedStatus(4101, fixtureStatus('status_graded'));

    await pump(tester);
    await tester.tap(find.text('HW1 & Report'));
    await tester.pumpAndSettle();

    expect(find.byType(CourseAssignmentDetailPage), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('85.00\u00a0/\u00a0100.00'), findsOneWidget);
  });

  testWidgets('詳情頁回報新狀態時，清單那一列的籤跟著換', (tester) async {
    await seedAssignments(twoFromFixture());
    // 快取裡是「還沒繳交」，籤是未繳交（而且帶時鐘，因為離線）。
    await seedStatus(4101, fixtureStatus('status_none'));

    await pump(tester);
    expect(find.widgetWithText(AssignStatusChip, '已逾期'), findsOneWidget);

    await tester.tap(find.text('HW1 & Report'));
    await tester.pumpAndSettle();

    // 交完之後詳情頁會呼叫這個回呼；這裡直接觸發它，驗的是「線真的接上了」。
    final detail = tester.widget<CourseAssignmentDetailPage>(
        find.byType(CourseAssignmentDetailPage));
    expect(detail.onStatusChanged, isNotNull);
    detail.onStatusChanged!(fixtureStatus('status_graded'));

    Get.back();
    await tester.pumpAndSettle();

    // 評完之後右邊那一格換成分數：狀態改由標題底下那一行的「· 已評分」講。
    expect(find.text('85.00'), findsOneWidget);
    expect(find.text('/100.00'), findsOneWidget);
    expect(find.textContaining('已評分'), findsWidgets);
    // 分數取代了籤——那一列不再有任何狀態籤（另一份沒有快取，本來就沒有）。
    expect(find.byType(AssignStatusChip), findsNothing);
  });
}
