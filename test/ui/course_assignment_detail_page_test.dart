import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/util/moodle_assign_attempt_utils.dart';
import 'package:flutter_app/src/util/moodle_assign_submit_utils.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_assignment_detail_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/assign_status_chip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sprintf/sprintf.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/moodle_assign_fixtures.dart';
import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';
import '../helpers/finders.dart';

/// 作業詳情頁的畫面規格。作業本體與狀態直接以 seed 傳入，不碰網路；
/// 離線，所以被丟掉的 seed 再抓時只會落到快取或 Failed。
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

  MoodleAssignment a1() => fixtureAssignments()[0];
  MoodleAssignment a2() => fixtureAssignments()[1];

  Future<void> pump(
    WidgetTester tester,
    MoodleAssignment? a, {
    int? assignId,
    Result<MoodleAssignSubmissionStatus>? status,
    List<(String, String)>? opened,
    Size viewSize = const Size(800, 3000),
    bool settle = true,
  }) async {
    // ListView 是懶載入的，超出視窗的段落根本不會被建出來；把視窗拉高，
    // 整頁都在畫面上。
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(GetMaterialApp(
      home: CourseAssignmentDetailPage(
        courseInfo,
        assignId: assignId ?? a!.id,
        assignment: a,
        initialStatus: status,
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

  /// 把標籤與值釘在同一列：只比對標籤或只比對值，都抓不到「延長期限那列
  /// 填成 duedate」這種串線。
  void expectField(String label, String value) {
    expect(
      find.ancestor(
          of: find.text(label), matching: find.widgetWithText(Row, value)),
      findsOneWidget,
      reason: '「$label」那列的值應該是 $value',
    );
  }

  testWidgets('已繳交且已評分：每一段都畫出來', (tester) async {
    await pump(tester, a1(), status: Ok(fixtureStatus('status_graded')));

    // 標題在 AppBar。
    expect(
      find.descendant(
          of: find.byType(AppBar), matching: find.text('HW1 & Report')),
      findsOneWidget,
    );
    // 日期列。「截止日期」是段標題，主行是相對提示、副行才是原本的 duedate。
    for (final label in ['開放繳交', '截止日期', '最後繳交期限']) {
      expect(find.text(label), findsOneWidget, reason: '缺少 $label');
    }
    expect(find.textContaining('已逾期'), findsOneWidget);
    expect(find.text(CourseAssignmentDetailPage.formatUnix(a1().duedate)),
        findsOneWidget,
        reason: '相對提示底下要有絕對時間');
    expectField('開放繳交',
        CourseAssignmentDetailPage.formatUnix(a1().allowsubmissionsfromdate));
    expectField(
        '最後繳交期限', CourseAssignmentDetailPage.formatUnix(a1().cutoffdate));
    // 說明（HTML）與附件。
    expect(find.text('作業說明'), findsOneWidget);
    expect(find.textContaining('PDF', findRichText: true), findsOneWidget);
    expect(find.text('附件'), findsOneWidget);
    expect(find.text('hw1.pdf'), findsOneWidget);
    // 狀態卡。
    expect(find.widgetWithText(AssignStatusChip, '已評分'), findsOneWidget);
    expect(find.text('評分狀態'), findsOneWidget);
    expect(find.text('已評分'), findsNWidgets(2), reason: '籤與評分狀態列各一');
    expect(find.text('繳交時間'), findsOneWidget);
    expect(find.text('繳交的檔案'), findsOneWidget);
    expect(find.text('hw1_b10000000.pdf'), findsOneWidget);
    expect(find.text('線上文字'), findsOneWidget);
    expect(find.textContaining('已附上報告', findRichText: true), findsOneWidget);
    expect(find.text('成績'), findsOneWidget);
    // connector 把 `85.00&nbsp;/&nbsp;100.00` 的實體還原成 U+00A0。
    expect(find.text('85.00\u00a0/\u00a0100.00'), findsOneWidget);
    expect(find.textContaining('&nbsp;'), findsNothing);
    expect(find.text('評分時間'), findsOneWidget);
    expect(find.text('老師回饋'), findsOneWidget);
    expect(find.textContaining('不錯', findRichText: true), findsOneWidget);
    expect(find.text('回饋檔案'), findsOneWidget);
    expect(find.text('hw1_marked.pdf'), findsOneWidget);
    // 導網頁搬到 app bar 上那顆圖示了，內文不再有一顆同等份量的全寬鈕。
    expect(find.byIcon(LucideIcons.externalLink), findsOneWidget);
    expect(find.text('在網頁開啟'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('草稿：時間那一列叫「最後修改時間」，不是「繳交時間」', (tester) async {
    await pump(tester, a1(), status: Ok(fixtureStatus('status_draft')));

    // Moodle 這一列是 timemodified：草稿只是最後一次存檔，不是繳交。
    expect(find.text('最後修改時間'), findsOneWidget);
    expect(find.text('繳交時間'), findsNothing);
    expect(find.text('hw1_b10000000.pdf'), findsOneWidget);
  });

  testWidgets('沒繳交、沒回饋：已逾期籤、尚未評分，沒有繳交與成績段落', (tester) async {
    await pump(tester, a1(), status: Ok(fixtureStatus('status_none')));

    expect(find.widgetWithText(AssignStatusChip, '已逾期'), findsOneWidget);
    expect(find.text('尚未評分'), findsOneWidget);
    expect(find.text('繳交的檔案'), findsNothing);
    expect(find.text('繳交時間'), findsNothing);
    expect(find.text('成績'), findsNothing);
    expect(find.text('老師回饋'), findsNothing);
  });

  testWidgets('intro 是 null：說明暫不顯示、沒有附件段、沒有截止日期', (tester) async {
    await pump(tester, a2(), status: Ok(fixtureStatus('status_none')));

    expect(find.text('尚未開放繳交，說明暫不顯示'), findsOneWidget);
    expect(find.text('附件'), findsNothing);
    expect(find.text('沒有截止日期'), findsOneWidget);
    expect(find.text('最後繳交期限'), findsNothing);
    expect(find.widgetWithText(AssignStatusChip, '未繳交'), findsOneWidget);
  });

  testWidgets('intro 是空字串：顯示 nothingHere 而不是「暫不顯示」', (tester) async {
    await pump(tester, a1()..intro = '',
        status: Ok(fixtureStatus('status_none')));

    expect(find.text(R.current.nothingHere), findsOneWidget);
    expect(find.text('尚未開放繳交，說明暫不顯示'), findsNothing);
  });

  testWidgets('有延長期限：多一列', (tester) async {
    final status = fixtureStatus('status_extension');
    await pump(tester, a1(), status: Ok(status));

    expectField(
        '延長期限', CourseAssignmentDetailPage.formatUnix(status.extensionDueDate));
    // 延長到 2025-09-16，早就過了 → 已逾期。
    expect(find.widgetWithText(AssignStatusChip, '已逾期'), findsOneWidget);
  });

  testWidgets('延長期限還沒到：截止列的相對提示跟著延長期限，籤是已延長', (tester) async {
    final status = MoodleAssignSubmissionStatus(
      lastattempt: MoodleAssignLastAttempt(
        extensionduedate: DateTime.now()
                .add(const Duration(days: 5))
                .millisecondsSinceEpoch ~/
            1000,
        gradingstatus: 'notgraded',
      ),
    );
    await pump(tester, a1(), status: Ok(status));

    // 這一頁自己就有一列「延長期限」，籤只說「未繳交」的話兩者對不起來。
    expect(find.widgetWithText(AssignStatusChip, '已延長'), findsOneWidget);
    // 「截止日期」那列仍顯示原本的 duedate（照 Moodle），但提示不再說已逾期。
    expect(find.textContaining('天後截止'), findsOneWidget);
    expect(find.textContaining('已逾期'), findsNothing);
    expect(find.text(CourseAssignmentDetailPage.formatUnix(a1().duedate)),
        findsOneWidget);
    expectField(
        '延長期限', CourseAssignmentDetailPage.formatUnix(status.extensionDueDate));
  });

  testWidgets('團隊作業由隊友代交：自己那筆是草稿，籤仍是待評分，檔案來自群組那筆', (tester) async {
    final team = a2()..duedate = a1().duedate;
    await pump(tester, team, status: Ok(fixtureStatus('status_team_draft')));

    expect(find.widgetWithText(AssignStatusChip, '待評分'), findsOneWidget);
    expect(find.text('繳交時間'), findsOneWidget);
    expect(find.text('hw1_b10000000.pdf'), findsOneWidget);
  });

  testWidgets('狀態是 Stale：多一列舊資料提示與重新整理鈕，籤帶時鐘', (tester) async {
    await pump(tester, a1(),
        status: Stale(fixtureStatus('status_graded'), const Offline()));

    expect(find.text(R.current.networkError), findsOneWidget);
    expect(buttonWithText(R.current.refresh), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AssignStatusChip),
        matching: find.byIcon(LucideIcons.history),
      ),
      findsOneWidget,
    );
  });

  testWidgets('seed 是 Failed 就重抓；離線沒快取 → 狀態卡畫就地重試的錯誤畫面', (tester) async {
    await pump(tester, a1(), status: const Failed(FetchFailed('x')));

    expect(find.text(R.current.networkError), findsOneWidget);
    expect(find.text('x'), findsNothing, reason: 'Failed 的 seed 不該被沿用');
    // 不是整頁的 errorBuilder：那個沒有重試鈕，要離開頁面才能再抓一次。
    expect(find.textContaining('ERR:'), findsNothing);
    final refresh = buttonWithText(R.current.refresh);
    expect(refresh, findsOneWidget);
    // 作業本體是 seed 的 Ok，頁面其餘部分照畫。
    expect(find.text('作業說明'), findsOneWidget);

    // 按重新整理會再抓一次（離線 → 仍然失敗，但畫面沒有卡在轉圈）。
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    expect(find.text(R.current.networkError), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('從「檔案」分頁進來（沒有 seed）而且抓不到：AppBar 是「作業詳情」不是分頁名', (tester) async {
    await pump(tester, null, assignId: 4101);

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('作業詳情')),
      findsOneWidget,
    );
    expect(find.text('ERR:${R.current.networkError}'), findsOneWidget);
  });

  testWidgets('在網頁開啟 → 交給注入的 openWebView：cmid 網址加 lang', (tester) async {
    final opened = <(String, String)>[];
    await pump(tester, a1(),
        status: Ok(fixtureStatus('status_graded')), opened: opened);

    await tester.tap(find.byIcon(LucideIcons.externalLink));
    await tester.pumpAndSettle();

    expect(opened, hasLength(1));
    expect(opened.single.$1, 'HW1 & Report');
    expect(
        opened.single.$2,
        startsWith(
            'https://moodle2.ntust.edu.tw/mod/assign/view.php?id=93001'));
    expect(opened.single.$2, contains('lang='));
  });

  testWidgets(
      '說明裡的 <img>：只有自家 pluginfile 由 App 帶 token 載入，data: URI 交回預設 factory',
      (tester) async {
    // 1x1 透明 PNG。
    const png =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
    final a = a1()
      ..intro = '<p><img src="data:image/png;base64,$png" alt="inline"></p>'
          '<p><img src="https://moodle2.ntust.edu.tw/webservice/pluginfile.php/555/mod_assign/intro/0/x.png" width="120" height="80"></p>';
    await pump(tester, a, status: Ok(fixtureStatus('status_none')));

    // data: URI 由預設 factory 解成 MemoryImage，不會是破圖。
    expect(
      find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage),
      findsOneWidget,
    );
    // pluginfile 那張走 Image.network（測試環境沒有網路 → 破圖 icon 剛好一個），
    // 而且 width / height 有帶上。
    final network = tester.widget<Image>(
        find.byWidgetPredicate((w) => w is Image && w.image is NetworkImage));
    expect(network.width, 120);
    expect(network.height, 80);
    expect(find.byIcon(LucideIcons.imageOff), findsOneWidget);
  });

  testWidgets('說明裡的連結：https 交給 openWebView，javascript: 被擋下', (tester) async {
    final opened = <(String, String)>[];
    final a = a1()
      ..intro = '<p><a href="https://example.com/x">safe</a></p>'
          '<p><a href="javascript:alert(1)">evil</a></p>';
    await pump(tester, a,
        status: Ok(fixtureStatus('status_none')), opened: opened);

    // 段落是整行寬的區塊，文字靠左；tap 要落在文字上而不是 widget 中心。
    Future<void> tapLink(String text) async {
      final finder = find.text(text, findRichText: true);
      await tester.tapAt(tester.getTopLeft(finder) + const Offset(6, 8));
      await tester.pumpAndSettle();
    }

    await tapLink('safe');
    expect(opened, [('HW1 & Report', 'https://example.com/x')]);

    await tapLink('evil');
    expect(opened, hasLength(1), reason: 'javascript: 不能進 WebView');
  });

  testWidgets('狀態還在載入：截止與說明照畫，繳交狀態那一段是轉圈', (tester) async {
    final repo = _PendingStatusRepository();
    MoodleRepository.instance = repo;
    await pump(tester, a1(), settle: false);

    expect(find.text('截止日期'), findsOneWidget);
    expect(find.text('作業說明'), findsOneWidget);
    expect(find.text('繳交狀態'), findsOneWidget);
    expect(find.text('成績與回饋'), findsNothing);
    // 籤位置的 14dp 小轉圈，加上狀態卡的 LoadingPage。
    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
    // 狀態還沒到就不知道逾期與否，提示一律中性色，不會先紅一下再變灰。
    final hint = find.textContaining('已逾期');
    expect(tester.widget<Text>(hint).style?.color,
        Theme.of(tester.element(hint)).colorScheme.onSurface);

    repo.pending.complete(const Failed(FetchFailed('x')));
    await tester.pumpAndSettle();
  });

  testWidgets('成績與回饋自成一段', (tester) async {
    await pump(tester, a1(), status: Ok(fixtureStatus('status_graded')));

    expect(find.text('成績與回饋'), findsOneWidget);
    for (final label in ['成績', '評分時間', '老師回饋', '回饋檔案']) {
      expect(find.text(label), findsOneWidget, reason: '缺少 $label');
    }
  });

  testWidgets('回饋四段全空：不畫成績與回饋群組，評分狀態仍在', (tester) async {
    final status = MoodleAssignSubmissionStatus(
      lastattempt: MoodleAssignLastAttempt(gradingstatus: 'notgraded'),
      feedback: MoodleAssignFeedback(),
    );
    await pump(tester, a1(), status: Ok(status));

    expect(find.text('成績與回饋'), findsNothing);
    expect(find.text('成績'), findsNothing);
    expect(find.text('評分狀態'), findsOneWidget);
    expect(find.text('尚未評分'), findsOneWidget);
  });

  testWidgets('有分數但 gradefordisplay 是空的：不畫空的成績列，評分時間仍在', (tester) async {
    final status = MoodleAssignSubmissionStatus(
      lastattempt: MoodleAssignLastAttempt(gradingstatus: 'graded'),
      feedback: MoodleAssignFeedback(
        grade: MoodleAssignGrade(grade: '85.00000'),
        gradeddate: 1756700000,
      ),
    );
    await pump(tester, a1(), status: Ok(status));

    expect(find.text('成績與回饋'), findsOneWidget);
    expect(find.text('成績'), findsNothing, reason: '沒有可顯示的字串就不畫空值那一列');
    expect(find.text('評分時間'), findsOneWidget);
    expect(find.widgetWithText(AssignStatusChip, '已評分'), findsOneWidget);
  });

  testWidgets('不需繳交的作業：過了截止也不染紅', (tester) async {
    await pump(tester, a1()..nosubmissions = 1,
        status: Ok(fixtureStatus('status_none')));

    expect(find.widgetWithText(AssignStatusChip, '不需繳交'), findsOneWidget);
    final hint = find.textContaining('已逾期');
    expect(hint, findsOneWidget, reason: '資料不刪，只是不喊狼來了');
    final scheme = Theme.of(tester.element(hint)).colorScheme;
    expect(tester.widget<Text>(hint).style?.color, scheme.onSurface);
    expect(tester.widget<Text>(hint).style?.color, isNot(scheme.error));
  });

  testWidgets('狀態失敗：只有那一段掛掉，截止與說明都還在', (tester) async {
    await pump(tester, a1(), status: const Failed(FetchFailed('x')));

    expect(find.text('開放繳交'), findsOneWidget);
    expect(find.text('作業說明'), findsOneWidget);
    expect(find.text('繳交狀態'), findsOneWidget, reason: '標題還在才知道哪一段掛了');
    expect(find.text('延長期限'), findsNothing);
    expect(find.text('評分狀態'), findsNothing);
    expect(find.text('成績與回饋'), findsNothing);
  });

  testWidgets('每一個檔案列都有下載提示', (tester) async {
    final a = a1();
    final s = fixtureStatus('status_graded');
    await pump(tester, a, status: Ok(s));

    final files = a.introattachments.length +
        s.submissionFor(a)!.files.length +
        s.feedback!.files.length;
    expect(files, greaterThan(0));
    expect(find.byIcon(LucideIconsThin.download), findsNWidgets(files));
  });

  testWidgets('超長中文檔名：截成兩行，不擠掉下載 icon 也不 overflow', (tester) async {
    final a = a1()
      ..introattachments = [
        MoodleAssignFile(
          filename: '${'期末專題報告與附錄' * 12}.pdf',
          fileurl:
              'https://moodle2.ntust.edu.tw/webservice/pluginfile.php/1/x.pdf',
          mimetype: 'application/pdf',
        ),
      ];
    await pump(tester, a,
        status: Ok(fixtureStatus('status_none')),
        viewSize: const Size(360, 3000));

    expect(tester.takeException(), isNull);
    expect(find.byIcon(LucideIconsThin.download), findsOneWidget);
    final title = tester.widget<Text>(find.textContaining('期末專題報告與附錄'));
    expect(title.maxLines, 2);
    expect(title.overflow, TextOverflow.ellipsis);
  });

  /// 繳交入口的可見性矩陣。這是整個交作業功能最重要的一段畫面守門：伺服器說
  /// 不能交的時候，入口必須根本不存在，而且不對著沒權限的人喊話。
  group('繳交入口', () {
    MoodleAssignment submittable() => fixtureSubmittableAssignment();

    void expectNoSubmitEntry() {
      expect(find.text(R.current.assignAddSubmission), findsNothing);
      expect(find.text(R.current.assignEditSubmission), findsNothing);
      expect(find.text(R.current.assignSubmitForGrading), findsNothing);
    }

    testWidgets('canedit 為 false：三顆鈕都沒有，也沒有任何理由文字', (tester) async {
      await pump(tester, submittable(),
          status: Ok(fixtureStatus('status_locked')));

      expectNoSubmitEntry();
      expect(find.text(R.current.assignTeamNoGroup), findsNothing);
      expect(find.text(R.current.assignSubmitWebOnlyPlugin), findsNothing);
      expect(find.text(R.current.assignSubmitNeedsFresh), findsNothing);
      // 唯一的出口是 app bar 上那顆圖示，不是內文裡的全寬鈕。
      expect(find.byIcon(LucideIcons.externalLink), findsOneWidget);
    });

    testWidgets('canedit 為 true 而且還沒交過：新增繳交，沒有送出評分', (tester) async {
      await pump(tester, submittable(),
          status: Ok(fixtureStatus('status_can_edit')));

      expect(find.text(R.current.assignAddSubmission), findsOneWidget);
      expect(find.text(R.current.assignEditSubmission), findsNothing);
      expect(find.text(R.current.assignSubmitForGrading), findsNothing);
    });

    testWidgets('已經有繳交紀錄：字樣變編輯繳交；cansubmit 為 true 時多一顆送出評分', (tester) async {
      await pump(tester, submittable(),
          status: Ok(fixtureStatus('status_can_submit')));

      expect(find.text(R.current.assignEditSubmission), findsOneWidget);
      expect(find.text(R.current.assignAddSubmission), findsNothing);
      expect(find.text(R.current.assignSubmitForGrading), findsOneWidget);
    });

    testWidgets('團隊作業有分到組：照樣交得出去', (tester) async {
      await pump(tester, submittable()..teamsubmission = 1,
          status: Ok(fixtureStatus('status_team')));

      expect(find.text(R.current.assignEditSubmission), findsOneWidget);
      expect(find.text(R.current.assignTeamNoGroup), findsNothing);
    });

    testWidgets('團隊作業但沒有分到組：不畫入口，改說一句修得好的話', (tester) async {
      await pump(
          tester,
          submittable()
            ..teamsubmission = 1
            ..preventsubmissionnotingroup = 1,
          status: Ok(fixtureStatus('status_can_edit')));

      expectNoSubmitEntry();
      // 團隊區塊與繳交入口各說一次；重點是它出現，而且不是「請在網頁繳交」。
      expect(find.text(R.current.assignTeamNoGroup), findsWidgets);
    });

    testWidgets('preventsubmissionnotingroup 關著時沒有組別也照畫入口：伺服器會收進預設組別',
        (tester) async {
      await pump(tester, submittable()..teamsubmission = 1,
          status: Ok(fixtureStatus('status_can_edit')));

      expect(find.text(R.current.assignAddSubmission), findsOneWidget);
      expect(find.text(R.current.assignTeamNoGroup), findsNothing);
    });

    testWidgets('有作答時限（lastattempt.timelimit）：入口照畫，時限只是資訊', (tester) async {
      await pump(tester, submittable(),
          status: Ok(fixtureStatus('status_timed')));

      expect(find.text(R.current.assignAddSubmission), findsOneWidget);
      expect(find.text(R.current.assignTimeLimit), findsWidgets);
    });

    testWidgets('匿名評分：入口照畫，只多一句說明', (tester) async {
      await pump(tester, submittable()..blindmarking = 1,
          status: Ok(fixtureStatus('status_can_edit')));

      expect(find.text(R.current.assignAddSubmission), findsOneWidget);
      expect(find.text(R.current.assignBlindMarkingNote), findsOneWidget);
    });

    testWidgets('第三方繳交外掛：不畫入口，改說要在網頁繳交', (tester) async {
      final a = submittable()
        ..configs.add(MoodleAssignConfig(
            plugin: 'turnitintooltwo',
            subtype: 'assignsubmission',
            name: 'enabled',
            value: '1'));
      await pump(tester, a, status: Ok(fixtureStatus('status_can_edit')));

      expectNoSubmitEntry();
      expect(find.text(R.current.assignSubmitWebOnlyPlugin), findsOneWidget);
    });

    testWidgets('狀態是 Stale：不給交，改說要先重新整理', (tester) async {
      await pump(tester, submittable(),
          status: Stale(fixtureStatus('status_can_edit'), const Offline()));

      expectNoSubmitEntry();
      expect(find.text(R.current.assignSubmitNeedsFresh), findsOneWidget);
    });

    testWidgets('狀態還在載入時什麼都不畫，不會先閃一顆鈕', (tester) async {
      final repo = _PendingStatusRepository();
      MoodleRepository.instance = repo;

      await pump(tester, submittable(), settle: false);

      expectNoSubmitEntry();
      expect(find.text(R.current.assignSubmitNeedsFresh), findsNothing);
      repo.pending.complete(Ok(fixtureStatus('status_can_edit')));
      await tester.pumpAndSettle();
      expect(find.text(R.current.assignAddSubmission), findsOneWidget);
    });
  });

  group('送出評分', () {
    MoodleAssignment submittable() => fixtureSubmittableAssignment();

    Future<void> tapSubmitForGrading(WidgetTester tester) async {
      await tester.tap(find.text(R.current.assignSubmitForGrading));
      await tester.pumpAndSettle();
      // 這份 fixture 要求同意繳交聲明，沒勾就按不了確定。
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text(R.current.sure));
      await tester.pump();
    }

    testWidgets('進行中那顆鈕是 disabled：第二趟必定被伺服器判成失敗', (tester) async {
      final repo = _PendingSubmitRepository();
      MoodleRepository.instance = repo;
      await pump(tester, submittable(),
          status: Ok(fixtureStatus('status_can_submit')));

      await tapSubmitForGrading(tester);

      final button = tester.widget<ButtonStyleButton>(
          buttonWithText(R.current.assignSubmitForGrading));
      expect(button.onPressed, isNull);

      repo.pending.complete(Ok(MoodleAssignSubmitResult(
          status: fixtureStatus('status_graded'), submitted: true)));
      await tester.pumpAndSettle();
    });

    testWidgets('成功但重抓不到狀態：說出來並自己再抓一次，不留著送出評分那顆鈕', (tester) async {
      final ui = RecordingUi();
      TaskUiDelegate.instance = ui;
      final repo = _PendingSubmitRepository();
      MoodleRepository.instance = repo;
      await pump(tester, submittable(),
          status: Ok(fixtureStatus('status_can_submit')));

      await tapSubmitForGrading(tester);
      repo.pending.complete(
          const Ok(MoodleAssignSubmitResult(status: null, submitted: true)));
      await tester.pumpAndSettle();

      expect(ui.toasts, contains(R.current.assignSubmittedToast));
      expect(ui.toasts, contains(R.current.assignStatusRefreshFailed));
      // loadStatus 把 status 清成 null 再抓，離線就落到 Failed。
      expect(find.text(R.current.assignSubmitForGrading), findsNothing);
    });

    testWidgets('被拒絕：toast 原因而不是「已送出」，並套上重抓到的狀態', (tester) async {
      final ui = RecordingUi();
      TaskUiDelegate.instance = ui;
      final repo = _PendingSubmitRepository();
      MoodleRepository.instance = repo;
      await pump(tester, submittable(),
          status: Ok(fixtureStatus('status_can_submit')));

      await tapSubmitForGrading(tester);
      repo.pending.complete(Ok(MoodleAssignSubmitResult(
        status: fixtureStatus('status_graded'),
        submitted: false,
        error: R.current.assignSubmitForGradingRejected,
      )));
      await tester.pumpAndSettle();

      expect(ui.toasts.last, R.current.assignSubmitForGradingRejected);
      expect(ui.toasts, isNot(contains(R.current.assignSubmittedToast)));
      // 拒絕之後仍然要套上重抓到的狀態：那顆「送出評分」不可以留在畫面上。
      expect(find.text(R.current.assignSubmitForGrading), findsNothing);
      expect(find.text(R.current.assignStatusGraded), findsWidgets);
    });
  });

  /// 從詳情頁一路開到繳交頁再存檔。這一段守的是「伺服器已經被寫過了，畫面
  /// 不可以停在寫入前」——`save_submission` 不是原子的。
  group('繳交頁回來之後', () {
    MoodleAssignment submittable() => fixtureSubmittableAssignment();

    Future<void> openAndSave(WidgetTester tester) async {
      await tester.tap(find.text(R.current.assignAddSubmission));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '報告內容');
      await tester.pump();
      await tester.tap(find.text(R.current.assignSaveDraft));
      await tester.pumpAndSettle();
    }

    testWidgets('存檔成功但重抓不到狀態：說出來並自己再抓一次', (tester) async {
      final ui = RecordingUi();
      TaskUiDelegate.instance = ui;
      MoodleRepository.instance = _StubSaveRepository(
          const Ok(MoodleAssignSubmitResult(status: null, submitted: false)));
      await pump(tester, submittable(),
          status: Ok(fixtureStatus('status_can_edit')));

      await openAndSave(tester);

      expect(ui.toasts, contains(R.current.assignDraftSaved));
      // 不補這一句，那顆鈕會一直寫著「新增繳交」，邀請使用者再交一次。
      expect(ui.toasts, contains(R.current.assignStatusRefreshFailed));
    });

    testWidgets('被拒絕但已經送出去了：toast 原因，而且套上重抓到的狀態', (tester) async {
      final ui = RecordingUi();
      TaskUiDelegate.instance = ui;
      MoodleRepository.instance = _StubSaveRepository(Ok(
        MoodleAssignSubmitResult(
          status: fixtureStatus('status_draft'),
          submitted: false,
          error: R.current.assignSubmitRejected,
        ),
      ));
      await pump(tester, submittable(),
          status: Ok(fixtureStatus('status_can_edit')));

      await openAndSave(tester);

      expect(ui.toasts.last, R.current.assignSubmitRejected);
      expect(ui.toasts, isNot(contains(R.current.assignDraftSaved)));
      // 回到詳情頁，而且看到的是伺服器的真相不是寫入前那一份。
      expect(find.byType(CourseAssignmentDetailPage), findsOneWidget);
      expect(find.text(R.current.assignEditSubmission), findsOneWidget);
    });
  });

  /// 溢位選單、移除與沿用上一次。這三件事動的是**伺服器上**的那一份，
  /// 所以它們在這一頁；而移除是全頁唯一不可逆又不是目標的動作，確認框
  /// 說得出後果才算數。
  group('溢位選單：移除與沿用上一次', () {
    MoodleAssignment submittable() => fixtureSubmittableAssignment();

    /// 一份寫實的行動服務清單：remove / start 在裡面，copy 不在。
    void stubMobileService({bool copy = false, bool remove = true}) {
      MoodleWebApiConnector.siteInfo = MoodleProfileEntity(functions: [
        if (remove)
          MoodleProfileFunctions(
              name: MoodleWebApiConnector.removeSubmissionFunction,
              version: '4.5'),
        MoodleProfileFunctions(
            name: MoodleWebApiConnector.startSubmissionFunction,
            version: '4.5'),
        if (copy)
          MoodleProfileFunctions(
              name: MoodleWebApiConnector.copyPreviousAttemptFunction,
              version: '4.5'),
      ]);
    }

    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byIcon(LucideIcons.ellipsisVertical));
      await tester.pumpAndSettle();
    }

    testWidgets('draft：選單裡有移除，沒有沿用上一次', (tester) async {
      stubMobileService();
      await pump(tester, submittable(),
          status: Ok(fixtureStatus('status_draft')));

      await openMenu(tester);
      expect(find.text(R.current.assignRemoveSubmission), findsOneWidget);
      expect(find.text(R.current.assignCopyPrevious), findsNothing);
    });

    testWidgets('submitted：照樣有移除——submissiondrafts 為 0 時它動的是活的繳交',
        (tester) async {
      stubMobileService();
      await pump(tester, submittable(),
          status: Ok(fixtureStatus('status_can_submit')));

      await openMenu(tester);
      expect(find.text(R.current.assignRemoveSubmission), findsOneWidget);
    });

    testWidgets('new / reopened 沒有東西可以移除，選單裡就不該有那一項', (tester) async {
      stubMobileService(copy: true);
      await pump(tester, submittable(),
          status: Ok(fixtureStatus('status_reopened')));

      await openMenu(tester);
      expect(find.text(R.current.assignRemoveSubmission), findsNothing);
      expect(find.text(R.current.assignCopyPrevious), findsOneWidget);
    });

    testWidgets('沒有任何動作時整顆選單都不畫', (tester) async {
      stubMobileService();
      // canedit 為 false。
      await pump(tester, submittable(),
          status: Ok(fixtureStatus('status_locked')));

      expect(find.byIcon(LucideIcons.ellipsisVertical), findsNothing);
    });

    testWidgets('站台沒開放 copy（NTUST 的常態）：選單裡沒有它，改成一句話加網頁出口', (tester) async {
      stubMobileService();
      await pump(tester, submittable(),
          status: Ok(fixtureStatus('status_reopened')));

      // reopened 仍然有「開始新的一次」，所以選單本身可能不存在——重點是
      // 那一項不在，而且畫面說得出為什麼。
      expect(find.text(R.current.assignCopyPreviousWebOnly), findsOneWidget);
      if (find.byIcon(LucideIcons.ellipsisVertical).evaluate().isNotEmpty) {
        await openMenu(tester);
        expect(find.text(R.current.assignCopyPrevious), findsNothing);
      }
    });

    testWidgets('移除的確認框說得出後果：不可逆、已繳交要重交', (tester) async {
      stubMobileService();
      // 這一份的 submission 真的是 submitted，移除等於退回去重交。
      await pump(tester, submittable(),
          status: Ok(fixtureStatus('status_graded')));

      await openMenu(tester);
      await tester.tap(find.text(R.current.assignRemoveSubmission).last);
      await tester.pumpAndSettle();

      expect(
          find.textContaining(R.current.assignRemoveConfirm), findsOneWidget);
      expect(find.textContaining(R.current.assignRemoveConfirmSubmitted),
          findsOneWidget);
      // 個人作業不該扯上整組。
      expect(
          find.textContaining(R.current.assignRemoveConfirmTeam), findsNothing);
    });

    testWidgets('團隊作業的確認框多一句「整組都會受影響」', (tester) async {
      stubMobileService();
      await pump(tester, submittable()..teamsubmission = 1,
          status: Ok(fixtureStatus('status_team')));

      await openMenu(tester);
      await tester.tap(find.text(R.current.assignRemoveSubmission).last);
      await tester.pumpAndSettle();

      expect(find.textContaining(R.current.assignRemoveConfirmTeam),
          findsOneWidget);
    });

    testWidgets('確認之後才送，取消就一趟都不送', (tester) async {
      stubMobileService();
      final repo = _PendingRemoveRepository();
      MoodleRepository.instance = repo;
      await pump(tester, submittable(),
          status: Ok(fixtureStatus('status_draft')));

      await openMenu(tester);
      await tester.tap(find.text(R.current.assignRemoveSubmission).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(R.current.cancel));
      await tester.pumpAndSettle();

      expect(repo.calls, 0);
    });

    testWidgets('移除成功：toast 並套上重抓到的狀態', (tester) async {
      stubMobileService();
      final ui = RecordingUi();
      TaskUiDelegate.instance = ui;
      final repo = _PendingRemoveRepository();
      MoodleRepository.instance = repo;
      await pump(tester, submittable(),
          status: Ok(fixtureStatus('status_draft')));

      await openMenu(tester);
      await tester.tap(find.text(R.current.assignRemoveSubmission).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(R.current.sure));
      await tester.pump();

      repo.pending.complete(Ok(MoodleAssignSubmitResult(
          status: fixtureStatus('status_can_edit'), submitted: false)));
      await tester.pumpAndSettle();

      expect(repo.calls, 1);
      expect(ui.toasts, contains(R.current.assignRemoved));
      // 伺服器上已經沒有那一份了，入口要回到「新增繳交」。
      expect(find.text(R.current.assignAddSubmission), findsOneWidget);
    });

    testWidgets('移除進行中：整條進度線亮起來，選單裡那兩項都按不動', (tester) async {
      stubMobileService(copy: true);
      final repo = _PendingRemoveRepository();
      MoodleRepository.instance = repo;
      await pump(tester, submittable(),
          status: Ok(fixtureStatus('status_draft')));

      // 按下去之前：沒有進度線，那一項按得動。
      expect(find.byType(LinearProgressIndicator), findsNothing);

      await openMenu(tester);
      await tester.tap(find.text(R.current.assignRemoveSubmission).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(R.current.sure));
      await tester.pump();

      // 這一趟沒有進度框，也沒有任何一顆鈕會變樣子——這條線就是全部的證據。
      // 不定量的進度條永遠不會靜止，這一段只能手動 pump。
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.tap(find.byIcon(LucideIcons.ellipsisVertical));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
          tester
              .widget<PopupMenuItem<AssignAction>>(find.widgetWithText(
                  PopupMenuItem<AssignAction>,
                  R.current.assignRemoveSubmission))
              .enabled,
          isFalse,
          reason: '寫入進行中再按一下什麼都不會發生，看起來就是壞了');
      Navigator.of(tester.element(find.byType(CourseAssignmentDetailPage)))
          .pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      repo.pending.complete(Ok(MoodleAssignSubmitResult(
          status: fixtureStatus('status_can_edit'), submitted: false)));
      await tester.pumpAndSettle();

      expect(repo.calls, 1);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('移除被拒絕：toast 原因而不是「已移除」', (tester) async {
      stubMobileService();
      final ui = RecordingUi();
      TaskUiDelegate.instance = ui;
      final repo = _PendingRemoveRepository();
      MoodleRepository.instance = repo;
      await pump(tester, submittable(),
          status: Ok(fixtureStatus('status_draft')));

      await openMenu(tester);
      await tester.tap(find.text(R.current.assignRemoveSubmission).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(R.current.sure));
      await tester.pump();

      repo.pending.complete(Ok(MoodleAssignSubmitResult(
        status: fixtureStatus('status_draft'),
        submitted: false,
        error: R.current.assignRemoveRejected,
      )));
      await tester.pumpAndSettle();

      expect(ui.toasts.last, R.current.assignRemoveRejected);
      expect(ui.toasts, isNot(contains(R.current.assignRemoved)));
    });
  });

  /// 次數、歷次繳交、團隊與倒數這幾張新卡片。
  group('次數 / 團隊 / 倒數', () {
    MoodleAssignment submittable() => fixtureSubmittableAssignment();

    testWidgets('reopened：畫出次數與上一次的成績', (tester) async {
      await pump(tester, submittable(),
          status: Ok(fixtureStatus('status_reopened')));

      expect(find.text(R.current.assignPreviousAttempts), findsOneWidget);
      // 上一次拿了 52 分，gradefordisplay 已經還原成純文字。
      expect(find.textContaining('52.00'), findsWidgets);
      // 這一份的截止日早就過了，籤上寫的是「已逾期」而不是「重新開放」——
      // resolveStatus 的順序刻意讓逾期贏過重新開放，同草稿那一條。
      expect(find.text(R.current.assignStatusReopened), findsNothing);
    });

    testWidgets('第一次繳交不畫次數那一段——替不存在的概念佔版面', (tester) async {
      await pump(tester, submittable(),
          status: Ok(fixtureStatus('status_draft')));

      expect(find.text(R.current.assignPreviousAttempts), findsNothing);
    });

    testWidgets('要求全員送出的團隊作業：說得出還有幾位沒交，只給數字不給名字', (tester) async {
      await pump(
          tester,
          submittable()
            ..teamsubmission = 1
            ..requireallteammemberssubmit = 1,
          status: Ok(fixtureStatus('status_team_all_must_submit')));

      expect(find.text(R.current.assignTeamSubmission), findsWidgets);
      expect(find.text(sprintf(R.current.assignTeamPendingMembers, [2])),
          findsOneWidget);
    });

    testWidgets('全組都交完了：那一句換成好消息，不是「還有 0 位尚未送出」', (tester) async {
      final status = fixtureStatus('status_team_all_must_submit');
      status.lastattempt!.submissiongroupmemberswhoneedtosubmit = const [];
      await pump(
          tester,
          submittable()
            ..teamsubmission = 1
            ..requireallteammemberssubmit = 1,
          status: Ok(status));

      expect(find.text(R.current.assignTeamAllSubmitted), findsOneWidget);
      expect(find.text(sprintf(R.current.assignTeamPendingMembers, [0])),
          findsNothing);
    });

    testWidgets('跨了多組：說一句老師修得好的話，不是死掉的鈕', (tester) async {
      await pump(
          tester,
          submittable()
            ..teamsubmission = 1
            ..preventsubmissionnotingroup = 1,
          status: Ok(fixtureStatus('status_team_multiple_groups')));

      expect(find.text(R.current.assignTeamMultipleGroups), findsWidgets);
      expect(find.text(R.current.assignAddSubmission), findsNothing);
    });

    testWidgets('計時中：詳情頁只顯示倒數，沒有「開始作答」那顆鈕（那在繳交頁）', (tester) async {
      await pump(tester, submittable(),
          status: Ok(fixtureStatus('status_timed_started')));

      expect(find.text(R.current.assignTimeLimit), findsWidgets);
      expect(find.text(R.current.assignStartAttempt), findsNothing);
    });

    testWidgets('倒數用自己的標籤：不是掛在「繳交狀態」底下', (tester) async {
      // fixture 的 timestarted 是寫死的過去，要拉到現在才會是「計時中」；
      // duedate 也要拿掉，timerEndUnix 會跟它取小。
      final status = fixtureStatus('status_timed_started');
      status.lastattempt!.submission!.timestarted =
          DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60;
      await pump(tester, submittable()..duedate = 0, status: Ok(status));

      expect(find.text(R.current.assignTimeRemaining), findsOneWidget);
      // 「剩餘時間」已經說了是剩下多久，值就只是那個數字。
      expect(find.textContaining(R.current.assignTimeLeft.split('%s').first),
          findsNothing);
    });

    testWidgets('次數那一列的標籤是「目前次數」', (tester) async {
      await pump(tester, submittable(),
          status: Ok(fixtureStatus('status_reopened')));

      expect(find.text(R.current.assignCurrentAttempt), findsOneWidget);
    });
  });
}

/// 存檔永遠回同一個結果，不碰網路。
class _StubSaveRepository extends MoodleRepository {
  _StubSaveRepository(this.result);

  final Result<MoodleAssignSubmitResult> result;

  @override
  Future<Result<MoodleAssignSubmitResult>> saveAssignSubmission({
    required MoodleAssignment assignment,
    required MoodleAssignSubmissionStatus status,
    required AssignSubmissionDraft draft,
    void Function(AssignTransferProgress progress)? onProgress,
    CancelToken? cancelToken,
  }) async =>
      result;
}

/// 讓送出評分一直停在進行中。
class _PendingSubmitRepository extends MoodleRepository {
  final pending = Completer<Result<MoodleAssignSubmitResult>>();

  @override
  Future<Result<MoodleAssignSubmitResult>> submitAssignForGrading({
    required MoodleAssignment assignment,
    required MoodleAssignSubmissionStatus status,
    required bool acceptStatement,
  }) =>
      pending.future;
}

/// 讓繳交狀態一直停在「載入中」：離線時真的去抓會在第一幀之前就落到
/// [Failed]，測不到轉圈那一幀。
class _PendingStatusRepository extends MoodleRepository {
  final pending = Completer<Result<MoodleAssignSubmissionStatus>>();

  @override
  Future<Result<MoodleAssignSubmissionStatus>> getSubmissionStatus(
    int assignId, {
    bool background = false,
  }) =>
      pending.future;
}

/// 讓移除繳交一直停在進行中，並數出真的送了幾趟。
class _PendingRemoveRepository extends MoodleRepository {
  final pending = Completer<Result<MoodleAssignSubmitResult>>();
  int calls = 0;

  @override
  Future<Result<MoodleAssignSubmitResult>> removeAssignSubmission({
    required MoodleAssignment assignment,
    required MoodleAssignSubmissionStatus status,
  }) {
    calls++;
    return pending.future;
  }
}
