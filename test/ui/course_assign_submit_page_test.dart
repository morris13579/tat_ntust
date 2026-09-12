import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/util/moodle_assign_attempt_utils.dart';
import 'package:flutter_app/src/util/moodle_assign_submit_utils.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/file_pick_service.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/ui/components/tile/moodle_file_tile.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_assign_submit_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sprintf/sprintf.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/moodle_assign_fixtures.dart';
import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';
import '../helpers/finders.dart';

/// 挑檔案的假實作：測試裡永遠不碰平台通道。
class _FakePickService implements FilePickService {
  _FakePickService(this.files);

  final List<File> files;
  int calls = 0;
  int? lastLimit;
  List<String>? lastExtensions;

  @override
  Future<List<File>> pick({
    required int limit,
    List<String> extensions = const [],
  }) async {
    calls++;
    lastLimit = limit;
    lastExtensions = extensions;
    return files;
  }
}

/// 交作業編輯頁的畫面規格。作業與狀態都是值傳進來的，這一頁不碰網路。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordingUi ui;
  late Directory tempDir;

  setUpAll(() async {
    await loadTestL10n();
    await initializeDateFormatting();
  });

  setUp(() {
    resetAppStatics();
    ui = RecordingUi();
    AuthSession.instance = FakeAuthSession();
    TaskUiDelegate.instance = ui;
    ConnectivityProbe.instance = FakeConnectivityProbe(online: false);
    MoodleRepository.instance = _NoNetworkRepo();
    tempDir = Directory.systemTemp.createTempSync('assign_submit_page_test');
  });

  tearDown(() {
    AuthSession.instance = const UninstalledAuthSession();
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  MoodleAssignment submittable() => fixtureSubmittableAssignment();

  MoodleAssignment noDrafts() => fixtureNoDraftsAssignment();

  File makeFile(String name, {int bytes = 64}) {
    final file = File('${tempDir.path}/$name');
    file.writeAsBytesSync(List<int>.filled(bytes, 1));
    return file;
  }

  Future<void> pump(
    WidgetTester tester,
    MoodleAssignment a,
    MoodleAssignSubmissionStatus status, {
    List<(String, String)>? opened,
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(GetMaterialApp(
      home: CourseAssignSubmitPage(
        assignment: a,
        status: status,
        courseName: '作業系統',
        openWebView: (title, url) async => opened?.add((title, url)),
      ),
    ));
    await tester.pumpAndSettle();
  }

  bool enabled(WidgetTester tester, Finder finder) =>
      tester.widget<ButtonStyleButton>(finder).onPressed != null;

  /// 挑完檔案要 `File.length()`，那是真的 I/O：假時鐘不會讓它完成，
  /// 得先把真的事件迴圈讓出去再 pump。
  Future<void> tapAndFlush(WidgetTester tester, Finder finder,
      {Finder? until}) async {
    // **整個點擊要跑在真的時鐘裡。** 挑完檔案頁面會 `await File.length()`，
    // 那是真的 I/O；在假時鐘下點下去，那個 future 沒有機會 resolve，接著的
    // pump 就畫出一個還沒有檔案的畫面。先前用「讓出幾輪 Duration.zero」去賭
    // 它會回來，整套測試平行跑、機器忙的時候就會賭輸——那正是這幾支偶發紅的
    // 原因。改成把 tap 本身放進 runAsync，處理鏈整條都在真時鐘上跑完再 pump。
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    if (until == null) return;
    // 機器很忙的時候那 50ms 還是可能不夠。有 [until] 就等到東西真的出現為止
    // ——這才是唯一不必猜時間的做法。逾時不自己丟，讓後面的斷言去報錯，訊息
    // 才看得出是什麼沒出現。
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (until.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pumpAndSettle();
    }
  }

  Finder saveButton(String label) => buttonWithText(label);

  /// 「新增檔案」現在是一列 ListTile（metrics 照抄 MoodleFileTile），
  /// 不再是一顆按鈕：限制寫在它的副標上，而不是它底下。
  Finder addFilesButton() =>
      find.widgetWithText(ListTile, R.current.assignAddFiles);

  bool pickerEnabled(WidgetTester tester) =>
      tester.widget<ListTile>(addFilesButton()).onTap != null;

  /// 內嵌圖片那一份的變體。
  MoodleAssignSubmissionStatus inlineStatus({
    bool dropInlineFiles = false,
    String? text,
  }) {
    final json = loadMoodleAssignFixture('status_onlinetext_inline');
    final plugins = (json['lastattempt'] as Map<String, dynamic>)['submission']
        ['plugins'] as List<dynamic>;
    for (final p in plugins) {
      if ((p as Map<String, dynamic>)['type'] != 'onlinetext') continue;
      if (dropInlineFiles) {
        (p['fileareas'] as List<dynamic>).first['files'] = <dynamic>[];
      }
      if (text != null) {
        (p['editorfields'] as List<dynamic>).first['text'] = text;
      }
    }
    return MoodleAssignSubmissionStatus.fromJson(json);
  }

  /// 現有線上文字含內嵌圖片。`moodlewssettingfileurl` 為真時伺服器送的是
  /// 絕對網址（`format_text` 在回傳前就把 `@@PLUGINFILE@@` 換掉了），
  /// 同一包裡還有那個檔案的 `fileurl`——還原前綴就是從它推出來的。
  MoodleAssignSubmissionStatus statusWithEmbeddedImage() =>
      fixtureStatus('status_onlinetext_inline');

  /// 同上，但 fileareas 是空的：推不出前綴，這一份就真的存不回去。
  MoodleAssignSubmissionStatus statusWithUnresolvableImage() =>
      inlineStatus(dropInlineFiles: true);

  group('區塊可見性', () {
    testWidgets('檔案外掛沒開就整個檔案區塊不畫', (tester) async {
      final a = submittable()
        ..configs = [
          MoodleAssignConfig(
              plugin: 'onlinetext',
              subtype: 'assignsubmission',
              name: 'enabled',
              value: '1'),
        ];
      await pump(tester, a, fixtureStatus('status_can_edit'));

      expect(find.text(R.current.assignAttachmentSection), findsNothing);
      expect(find.text(R.current.assignOnlineText), findsOneWidget);
    });

    testWidgets('線上文字外掛沒開就整個文字區塊不畫', (tester) async {
      await pump(tester, noDrafts(), fixtureStatus('status_can_edit'));

      expect(find.text(R.current.assignAttachmentSection), findsOneWidget);
      expect(find.text(R.current.assignOnlineText), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('有草稿階段的作業照畫繳交聲明，但沒有勾選框（那一步在送出評分時才擋）', (tester) async {
      await pump(tester, submittable(), fixtureStatus('status_can_edit'));

      expect(submittable().requiresStatement, isTrue);
      // 規則本身要看得到，否則它只活在上一頁的對話框裡，按下去才知道。
      expect(find.text(R.current.assignSubmissionStatement), findsOneWidget);
      expect(find.text(R.current.assignStatementAtSubmit), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
    });

    testWidgets('沒有繳交檔案時卡片裡只有挑檔案那一列', (tester) async {
      await pump(tester, submittable(), fixtureStatus('status_can_edit'));

      expect(addFilesButton(), findsOneWidget);
      expect(find.byType(MoodleFileTile), findsNothing);
    });

    testWidgets('已經交過的檔案是清單的初值，一列一個，而且說得出它在哪', (tester) async {
      await pump(tester, submittable(), fixtureStatus('status_draft'));

      expect(find.text('hw1_b10000000.pdf'), findsOneWidget);
      // 這一行副標就是「這個 X 會刪掉伺服器上的檔案」與「只是撤回剛剛那一下」
      // 之間的全部差別。
      expect(find.text(R.current.assignFileOnServer), findsOneWidget);
    });

    testWidgets('剛挑的檔案副標說「這次新增」加大小，跟伺服器上的那一種分得開', (tester) async {
      FilePickService.instance = _FakePickService([makeFile('report.pdf')]);
      await pump(tester, submittable(), fixtureStatus('status_draft'));

      await tapAndFlush(tester, addFilesButton(),
          until: find.textContaining('這次新增'));

      expect(find.text(R.current.assignFileOnServer), findsOneWidget);
      expect(find.textContaining('這次新增'), findsOneWidget);
    });
  });

  /// 表頭：截止提示、狀態籤，以及那一句「按下去會發生什麼事」。
  group('狀態表頭', () {
    testWidgets('有草稿階段：先講清楚存了還要再送出評分', (tester) async {
      await pump(tester, submittable(), fixtureStatus('status_can_edit'));

      expect(find.text(R.current.assignConsequenceDraft), findsOneWidget);
    });

    testWidgets('沒有草稿階段：存檔就是繳交，這句話在按下去之前就講', (tester) async {
      await pump(tester, noDrafts(), fixtureStatus('status_can_edit'));

      expect(find.text(R.current.assignConsequenceDirect), findsOneWidget);
    });

    testWidgets('沒有草稿階段又已經交過：說的是會覆蓋', (tester) async {
      await pump(tester, noDrafts(), fixtureStatus('status_graded'));

      expect(find.text(R.current.assignConsequenceOverwrite), findsOneWidget);
    });

    testWidgets('團隊作業：表頭就說這是整組共用的', (tester) async {
      await pump(tester, submittable()..teamsubmission = 1,
          fixtureStatus('status_team'));

      expect(find.text(R.current.assignTeamNotice), findsOneWidget);
    });
  });

  group('按鈕文案與可按性', () {
    testWidgets('有草稿階段：那顆鈕叫「儲存草稿」', (tester) async {
      await pump(tester, submittable(), fixtureStatus('status_can_edit'));

      expect(find.text(R.current.assignSaveDraft), findsOneWidget);
      expect(find.text(R.current.assignSubmit), findsNothing);
    });

    testWidgets('沒有草稿階段：存檔就是繳交，文案不可以騙人', (tester) async {
      await pump(tester, noDrafts(), fixtureStatus('status_can_edit'));

      expect(find.text(R.current.assignSubmit), findsOneWidget);
      expect(find.text(R.current.assignSaveDraft), findsNothing);
    });

    testWidgets('沒有任何變更就不給按：那一趟必定被判成 submissionempty', (tester) async {
      await pump(tester, submittable(), fixtureStatus('status_draft'));

      expect(enabled(tester, saveButton(R.current.assignSaveDraft)), isFalse);
    });

    testWidgets('改了線上文字之後就可以按', (tester) async {
      await pump(tester, submittable(), fixtureStatus('status_draft'));

      await tester.enterText(find.byType(TextField), '改過的內容');
      await tester.pump();

      expect(enabled(tester, saveButton(R.current.assignSaveDraft)), isTrue);
    });

    testWidgets('沒有任何變更時，那顆鈕底下說得出是為什麼', (tester) async {
      await pump(tester, submittable(), fixtureStatus('status_draft'));

      expect(find.text(R.current.assignBlockedNoChanges), findsOneWidget);
    });

    testWidgets('達到 maxfilesubmissions 時挑檔案那一列停用，而且在自己身上講出前提', (tester) async {
      // no_drafts 的 maxfilesubmissions 是 1，status_draft 已經有一個檔案。
      await pump(tester, noDrafts(), fixtureStatus('status_draft'));

      expect(pickerEnabled(tester), isFalse);
      expect(find.text(sprintf(R.current.assignFileLimitReached, ['1'])),
          findsOneWidget);
    });

    testWidgets('還沒滿的時候可以按，而且只要求剩下的額度', (tester) async {
      final pick = _FakePickService([]);
      FilePickService.instance = pick;
      await pump(tester, submittable(), fixtureStatus('status_draft'));

      expect(pickerEnabled(tester), isTrue);
      await tapAndFlush(tester, addFilesButton(),
          until: find.textContaining('這次新增'));

      // maxfilesubmissions 3，已經有 1 個。
      expect(pick.lastLimit, 2);
      // filetypeslist 全是副檔名，所以直接交給挑選器過濾。
      expect(pick.lastExtensions, ['pdf', 'docx']);
    });
  });

  group('繳交聲明', () {
    testWidgets('沒有草稿階段又要求同意：勾選框在，沒勾就不能送，勾了才可以', (tester) async {
      FilePickService.instance = _FakePickService([makeFile('report.pdf')]);
      await pump(tester, noDrafts(), fixtureStatus('status_can_edit'));

      expect(find.text(R.current.assignSubmissionStatement), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsOneWidget);

      await tapAndFlush(tester, addFilesButton(),
          until: find.textContaining('這次新增'));
      expect(find.text('report.pdf'), findsOneWidget);
      // 有變更了，但還沒同意聲明——而且動作列說得出是這個原因。
      expect(enabled(tester, saveButton(R.current.assignSubmit)), isFalse);
      expect(find.text(R.current.assignBlockedStatement), findsOneWidget);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(enabled(tester, saveButton(R.current.assignSubmit)), isTrue);
    });
  });

  group('線上文字', () {
    testWidgets('現有內容含內嵌圖片時不開輸入框，但說的是「會原樣保留」而不是「唯讀」', (tester) async {
      final opened = <(String, String)>[];
      await pump(tester, submittable(), statusWithEmbeddedImage(),
          opened: opened);

      // 純文字框改不動這一段，但它會被原樣送回去——檔案照樣可以增減。
      expect(find.byType(TextField), findsNothing);
      expect(find.text(R.current.assignOnlineTextKeepAsIs), findsOneWidget);
      expect(find.text(R.current.assignOnlineTextPreserved), findsOneWidget);

      await tester.tap(find.text(R.current.assignEditOnlineTextInWeb));
      await tester.pumpAndSettle();
      expect(opened.single.$2, contains('/mod/assign/view.php?id=93201'));
    });

    testWidgets('只開線上文字的作業也畫得出那張卡', (tester) async {
      // 這一組的判斷全是短路運算：沒有檔案外掛、沒有字數上限時一個
      // observable 都讀不到，包錯一層 Obx 就會 improper-use 當場炸掉。
      final a = submittable()
        ..configs = [
          MoodleAssignConfig(
              plugin: 'onlinetext',
              subtype: 'assignsubmission',
              name: 'enabled',
              value: '1'),
        ];
      await pump(tester, a, statusWithEmbeddedImage());

      expect(find.text(R.current.assignOnlineTextPreserved), findsOneWidget);
      expect(find.text(R.current.assignOnlineTextKeepAsIs), findsOneWidget);
    });

    testWidgets('有字數上限時提示裡帶著上限', (tester) async {
      await pump(tester, submittable(), fixtureStatus('status_can_edit'));

      expect(find.text(sprintf(R.current.assignWordCount, ['0', '500'])),
          findsOneWidget);
    });
  });

  group('挑檔案的本地把關', () {
    testWidgets('超大的檔案不進清單，只出一個 toast', (tester) async {
      // no_drafts 的單檔上限是 1 MB。
      FilePickService.instance =
          _FakePickService([makeFile('huge.pdf', bytes: 1048577)]);
      await pump(tester, noDrafts(), fixtureStatus('status_can_edit'));

      await tapAndFlush(tester, addFilesButton(),
          until: find.textContaining('這次新增'));

      expect(find.text('huge.pdf'), findsNothing);
      expect(find.byType(MoodleFileTile), findsNothing);
      expect(ui.toasts.single, contains('huge.pdf'));
    });

    testWidgets('副檔名不在允許清單裡的也擋下來', (tester) async {
      FilePickService.instance = _FakePickService([makeFile('note.txt')]);
      await pump(tester, submittable(), fixtureStatus('status_can_edit'));

      await tapAndFlush(tester, addFilesButton(),
          until: find.textContaining('這次新增'));

      expect(find.text('note.txt'), findsNothing);
      expect(ui.toasts.single, contains('note.txt'));
    });

    testWidgets('挑選器叫不起來時只 toast，不加任何檔案', (tester) async {
      FilePickService.instance = _ThrowingPickService();
      await pump(tester, submittable(), fixtureStatus('status_can_edit'));

      await tapAndFlush(tester, addFilesButton(),
          until: find.textContaining('這次新增'));

      expect(ui.toasts.single, R.current.assignFilePickerUnavailable);
      expect(find.byType(MoodleFileTile), findsNothing);
    });
  });

  group('寫入進行中', () {
    testWidgets('進度列與取消鈕都在，而且清單被擋住不給再改', (tester) async {
      final repo = _PendingRepo();
      MoodleRepository.instance = repo;
      await pump(tester, submittable(), fixtureStatus('status_draft'));

      await tester.enterText(find.byType(TextField), '改過的內容');
      await tester.pump();
      await tester.tap(saveButton(R.current.assignSaveDraft));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text(R.current.cancel), findsOneWidget);
      // 進行中的時候動作列整條換成傳輸列，儲存鈕根本不在畫面上——按第二次
      // 這件事不存在。
      expect(saveButton(R.current.assignSaveDraft), findsNothing);

      // 上傳到第一個檔案時，進度列會說正在傳哪一個。
      repo.onProgress?.call(const AssignTransferProgress(
          done: 0,
          total: 1,
          ratio: 0.5,
          phase: AssignTransferPhase.upload,
          filename: 'hw1_b10000000.pdf'));
      await tester.pump();
      expect(
          find.text(
              sprintf(R.current.assignUploadingFile, ['hw1_b10000000.pdf'])),
          findsOneWidget);

      // 舊檔案要先下載再重傳，那一段不可以說成「正在上傳」。
      repo.onProgress?.call(const AssignTransferProgress(
          done: 0,
          total: 1,
          ratio: 0.1,
          phase: AssignTransferPhase.download,
          filename: 'hw1_b10000000.pdf'));
      await tester.pump();
      expect(
          find.text(
              sprintf(R.current.assignPreparingFile, ['hw1_b10000000.pdf'])),
          findsOneWidget);

      await tester.tap(find.text(R.current.cancel));
      await tester.pump();
      expect(repo.cancelToken?.isCancelled, isTrue);

      repo.completer.complete(const Failed(FetchFailed('x')));
      await tester.pumpAndSettle();
      // 失敗就留在這一頁，變更還在。
      expect(find.byType(CourseAssignSubmitPage), findsOneWidget);
      // 使用者自己按的取消不是「繳交失敗」。
      expect(ui.toasts.last, R.current.assignSubmitCancelled);
    });
  });

  group('線上文字外掛開著就一定要送', () {
    testWidgets('只動檔案時照樣帶著伺服器原本那份文字，不是 null', (tester) async {
      // 伺服器端 assign_submission_onlinetext::save() 沒有 isset 把關：不送
      // 這個鍵不是「保留」，是被空值覆蓋。送回去的那一份要來自原文那一趟，
      // 不是狀態物件裡那份算繪過的。
      final repo = _PendingRepo()
        ..editText = (
          rawText: '<p>已附上報告</p>',
          inlineFiles: const <MoodleAssignFile>[],
        );
      MoodleRepository.instance = repo;
      FilePickService.instance = _FakePickService([makeFile('extra.pdf')]);
      await pump(tester, submittable(), fixtureStatus('status_draft'));

      await tapAndFlush(tester, addFilesButton(),
          until: find.textContaining('這次新增'));
      await tester.tap(saveButton(R.current.assignSaveDraft));
      await tester.pump();

      expect(repo.draft!.files, isNotNull);
      expect(repo.draft!.onlineText, '<p>已附上報告</p>');
    });

    testWidgets('文字裡有圖也存得下去：送回去的是還原成 @@PLUGINFILE@@ 的原文', (tester) async {
      final repo = _PendingRepo()
        ..editText = (
          rawText: '<p>看圖 <img src="@@PLUGINFILE@@/Lecture%20%281%29.png"></p>',
          inlineFiles: const <MoodleAssignFile>[],
        );
      MoodleRepository.instance = repo;
      FilePickService.instance = _FakePickService([makeFile('new.pdf')]);
      await pump(tester, submittable(), statusWithEmbeddedImage());

      await tapAndFlush(tester, addFilesButton(),
          until: find.textContaining('這次新增'));
      expect(find.text('new.pdf'), findsOneWidget);
      // 這一顆按不下去，就等於「文字裡有一張圖」＝這份作業在 App 內交不了。
      expect(enabled(tester, saveButton(R.current.assignSaveDraft)), isTrue);

      await tester.tap(saveButton(R.current.assignSaveDraft));
      await tester.pump();

      // 送絕對網址回去會被逐字寫進資料庫，那些圖從此要憑證才打得開。
      expect(repo.draft!.onlineText, contains('@@PLUGINFILE@@'));
      expect(repo.draft!.onlineText, isNot(contains('pluginfile.php')));
    });

    testWidgets('文字框打不開時，超過字數上限那一句要叫人去網頁刪，不是「請刪減」', (tester) async {
      final a = submittable()
        ..configs = [
          MoodleAssignConfig(
              plugin: 'onlinetext',
              subtype: 'assignsubmission',
              name: 'enabled',
              value: '1'),
          MoodleAssignConfig(
              plugin: 'onlinetext',
              subtype: 'assignsubmission',
              name: 'wordlimitenabled',
              value: '1'),
          MoodleAssignConfig(
              plugin: 'onlinetext',
              subtype: 'assignsubmission',
              name: 'wordlimit',
              value: '1'),
        ];
      // 圖片還在（所以文字框開不了），而字數超過老師新設的上限。
      await pump(tester, a,
          inlineStatus(text: '<p>one two three <img src="/x.png"></p>'));

      // 「請刪減後再繳交」是對著一個不存在的輸入框說的。
      expect(
          find.text(R.current.assignWordCountExceededReadOnly), findsOneWidget);
      expect(find.text(R.current.assignWordCountExceeded), findsNothing);
    });

    testWidgets('原文那一趟拿不到時：不寫回算繪過的那一份，而且說得出原因', (tester) async {
      // 送回去的必須是資料庫原文。拿不到就整趟不送——狀態物件裡那一份是
      // filter 與 Purifier 跑過的算繪結果，寫回去是永久的。
      final repo = _RecordingSaveRepo();
      MoodleRepository.instance = repo;
      FilePickService.instance = _FakePickService([makeFile('new.pdf')]);
      await pump(tester, submittable(), statusWithUnresolvableImage());

      await tapAndFlush(tester, addFilesButton(),
          until: find.textContaining('這次新增'));
      // 擋的不是按鈕：那一趟重試就好，鈕停用了就沒有第二次機會。
      expect(enabled(tester, saveButton(R.current.assignSaveDraft)), isTrue);

      await tester.tap(saveButton(R.current.assignSaveDraft));
      await tester.pumpAndSettle();

      expect(repo.saved, isNull);
      expect(ui.toasts, contains(R.current.assignOnlineTextRawFailed));
    });

    testWidgets('儲存被硬擋下來時就不准再說「原樣送回、檔案照樣可以增減」', (tester) async {
      // 動作列說 Moodle 會擋下整次儲存，卡片同時說檔案照樣可以增減——
      // 兩句話不可能同時是真的。
      final a = submittable()
        ..configs = [
          MoodleAssignConfig(
              plugin: 'file',
              subtype: 'assignsubmission',
              name: 'enabled',
              value: '1'),
          MoodleAssignConfig(
              plugin: 'onlinetext',
              subtype: 'assignsubmission',
              name: 'enabled',
              value: '1'),
          MoodleAssignConfig(
              plugin: 'onlinetext',
              subtype: 'assignsubmission',
              name: 'wordlimitenabled',
              value: '1'),
          MoodleAssignConfig(
              plugin: 'onlinetext',
              subtype: 'assignsubmission',
              name: 'wordlimit',
              value: '1'),
        ];
      await pump(tester, a,
          inlineStatus(text: '<p>one two three <img src="/x.png"></p>'));

      expect(
          find.text(R.current.assignWordCountExceededReadOnly), findsOneWidget);
      expect(find.text(R.current.assignOnlineTextPreserved), findsNothing);
      expect(find.text(R.current.assignOnlineTextKeepAsIs), findsNothing);
      // 純文字框改不動這一段還是事實，只是不再附贈那句承諾。
      expect(find.text(R.current.assignOnlineTextReadOnly), findsOneWidget);
    });
  });

  group('字數上限', () {
    testWidgets('超過就不給送，並且即時把字數說出來', (tester) async {
      await pump(tester, submittable(), fixtureStatus('status_can_edit'));

      await tester.enterText(
          find.byType(TextField), List.filled(501, 'w').join(' '));
      await tester.pump();

      expect(enabled(tester, saveButton(R.current.assignSaveDraft)), isFalse);
      // 一次在字數列底下，一次在動作列那顆鈕上面。
      expect(find.text(R.current.assignWordCountExceeded), findsNWidgets(2));

      await tester.enterText(find.byType(TextField), '短短一句');
      await tester.pump();
      expect(enabled(tester, saveButton(R.current.assignSaveDraft)), isTrue);
    });
  });

  group('寫入中不給離開', () {
    testWidgets('返回鍵按不掉：CancelToken 到不了 save_submission', (tester) async {
      final repo = _PendingRepo();
      MoodleRepository.instance = repo;
      await pump(tester, submittable(), fixtureStatus('status_draft'));

      await tester.enterText(find.byType(TextField), '改過的內容');
      await tester.pump();
      await tester.tap(saveButton(R.current.assignSaveDraft));
      await tester.pump();

      await tester.tap(find.byIcon(LucideIcons.chevronLeft));
      // 不定量的進度條永遠不會靜止，所以只 pump 不 settle。
      await tester.pump();
      await tester.pump();

      // 連確認框都不該出現：這裡沒有「捨棄變更」這回事。
      expect(find.text(R.current.assignDiscardChanges), findsNothing);
      expect(find.byType(CourseAssignSubmitPage), findsOneWidget);

      repo.completer.complete(const Failed(FetchFailed('x')));
      await tester.pumpAndSettle();
    });
  });

  group('檔案列', () {
    testWidgets('本機剛挑的那一列不吃點擊：沒有事情可做就不要給漣漪', (tester) async {
      FilePickService.instance = _FakePickService([makeFile('report.pdf')]);
      await pump(tester, noDrafts(), fixtureStatus('status_can_edit'));

      await tapAndFlush(tester, addFilesButton(),
          until: find.textContaining('這次新增'));

      final tile = tester.widget<MoodleFileTile>(find.byType(MoodleFileTile));
      expect(tile.onTap, isNull);
    });

    testWidgets('已經交上去的那一列點得開', (tester) async {
      await pump(tester, submittable(), fixtureStatus('status_draft'));

      final tile = tester.widget<MoodleFileTile>(find.byType(MoodleFileTile));
      expect(tile.onTap, isNotNull);
    });
  });

  group('移除檔案', () {
    testWidgets('把伺服器上的檔案清光不給存：那等於把繳交檔案全部刪掉', (tester) async {
      await pump(tester, noDrafts(), fixtureStatus('status_draft'));

      await tester.tap(find.byTooltip(R.current.assignRemoveFile));
      await tester.pumpAndSettle();

      // 一次在檔案卡裡，一次在動作列那顆鈕上面。
      expect(find.text(R.current.assignFilesEmptiedWebOnly), findsNWidgets(2));
      expect(enabled(tester, saveButton(R.current.assignSubmit)), isFalse);
    });

    testWidgets('那一列不會消失：改成刪除線加「儲存後會從 Moodle 移除」，而且撤得回來', (tester) async {
      await pump(tester, noDrafts(), fixtureStatus('status_draft'));

      await tester.tap(find.byTooltip(R.current.assignRemoveFile));
      await tester.pumpAndSettle();

      expect(find.byType(MoodleFileTile), findsOneWidget);
      expect(tester.widget<MoodleFileTile>(find.byType(MoodleFileTile)).dimmed,
          isTrue);
      expect(find.text(R.current.assignFileWillBeRemoved), findsOneWidget);
      expect(find.text(R.current.assignFileOnServer), findsNothing);

      await tester.tap(find.byTooltip(R.current.assignRestoreFile));
      await tester.pumpAndSettle();

      expect(find.text(R.current.assignFileOnServer), findsOneWidget);
      expect(find.text(R.current.assignFilesEmptiedWebOnly), findsNothing);
    });

    testWidgets('只移除其中一個：卡片裡就講出會刪掉幾個，而且儲存前一定跳確認框', (tester) async {
      FilePickService.instance = _FakePickService([makeFile('extra.pdf')]);
      // 有草稿階段的作業本來不跳確認框，這一趟跳是因為儲存會真的刪掉檔案。
      await pump(tester, submittable(), fixtureStatus('status_draft'));
      await tapAndFlush(tester, addFilesButton(),
          until: find.textContaining('這次新增'));

      await tester.tap(find.byTooltip(R.current.assignRemoveFile).first);
      await tester.pumpAndSettle();

      final warning = sprintf(R.current.assignRemoveFilesWarning, [1]);
      expect(find.text(warning), findsOneWidget);
      // 清單沒有被清空，所以擋不住儲存——真正的守門是那個確認框。
      expect(find.text(R.current.assignFilesEmptiedWebOnly), findsNothing);
      expect(enabled(tester, saveButton(R.current.assignSaveDraft)), isTrue);

      await tester.tap(saveButton(R.current.assignSaveDraft));
      await tester.pumpAndSettle();

      // 卡片裡那一句還在，對話框裡再講一次——這一頁本來不會為草稿存檔跳框。
      expect(find.text(R.current.sure), findsOneWidget);
      expect(find.textContaining(warning), findsNWidgets(2));
      await tester.tap(find.text(R.current.cancel).last);
      await tester.pumpAndSettle();
    });
  });

  /// 作答時限。這一段守的是本規格最容易被默默改壞的一條：**時限到期不可以
  /// 讓儲存鈕變灰**。伺服器照收，只標記遲交（`caneditsubmission`）；本地擋下
  /// 來就是把已經寫好的東西鎖死在畫面上。
  group('作答時限', () {
    int nowUnix() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

    /// 有時限的繳交狀態。[startedSecondsAgo] 為 null 代表還沒按過開始。
    MoodleAssignSubmissionStatus timed({
      int? startedSecondsAgo,
      int timeLimit = 3600,
    }) =>
        MoodleAssignSubmissionStatus(
          lastattempt: MoodleAssignLastAttempt(
            submission: MoodleAssignSubmission(
              status: startedSecondsAgo == null ? 'new' : 'draft',
              timestarted:
                  startedSecondsAgo == null ? 0 : nowUnix() - startedSecondsAgo,
            ),
            canedit: true,
            gradingstatus: 'notgraded',
            timelimit: timeLimit,
          ),
        );

    testWidgets('還沒開始：動作列是「開始作答」，不是儲存', (tester) async {
      await pump(tester, submittable(), timed());

      expect(find.text(R.current.assignStartAttempt), findsOneWidget);
      expect(find.text(R.current.assignSaveDraft), findsNothing);
      expect(enabled(tester, saveButton(R.current.assignStartAttempt)), isTrue);
    });

    testWidgets('還沒開始：表頭先講清楚時限多長、不能暫停', (tester) async {
      await pump(tester, submittable(), timed());

      expect(
          find.textContaining(
              sprintf(R.current.assignTimeLimitNotice, ['1:00:00'])),
          findsOneWidget);
    });

    testWidgets('站台沒開放在 App 內開始：鈕停用，說出原因並給網頁出口', (tester) async {
      MoodleWebApiConnector.siteInfo = MoodleProfileEntity(functions: [
        MoodleProfileFunctions(
            name: MoodleWebApiConnector.saveSubmissionFunction, version: '4.5'),
      ]);
      await pump(tester, submittable(), timed());

      expect(
          enabled(tester, saveButton(R.current.assignStartAttempt)), isFalse);
      expect(find.text(R.current.assignTimerNotAvailable), findsOneWidget);
      expect(find.text(R.current.assignOpenInWeb), findsOneWidget);
    });

    testWidgets('計時中：表頭有倒數，動作列回到一般的儲存鈕', (tester) async {
      await pump(tester, submittable(), timed(startedSecondsAgo: 60));

      expect(find.text(R.current.assignStartAttempt), findsNothing);
      expect(find.text(R.current.assignSaveDraft), findsOneWidget);
    });

    testWidgets('時限已過：表頭改口說會被標記為遲交', (tester) async {
      await pump(
          tester, submittable(), timed(startedSecondsAgo: 7200, timeLimit: 60));

      expect(find.text(R.current.assignTimeExpiredStillEditable), findsWidgets);
    });

    testWidgets('時限已過而且有變更：儲存鈕仍然可以按（R1，本規格最怕被改壞的一條）', (tester) async {
      await pump(
          tester, submittable(), timed(startedSecondsAgo: 7200, timeLimit: 60));

      await tester.enterText(find.byType(TextField), '遲交也要交');
      await tester.pump();

      expect(enabled(tester, saveButton(R.current.assignSaveDraft)), isTrue,
          reason: '伺服器照收只標記遲交，本地擋下來就是把寫好的東西鎖死');
    });

    testWidgets('時限已過但什麼都沒改：擋下來的理由是「沒有變更」，不是時限', (tester) async {
      await pump(
          tester, submittable(), timed(startedSecondsAgo: 7200, timeLimit: 60));

      expect(enabled(tester, saveButton(R.current.assignSaveDraft)), isFalse);
      expect(find.text(R.current.assignBlockedNoChanges), findsOneWidget);
    });

    /// 按下「開始作答」之後動作列要換人。這一段守的是：**狀態欄位講不出來的
    /// 兩件事，不可以讓畫面退回「還沒開始」**——那顆鈕再按幾次都是同一個結果，
    /// 儲存鈕永遠出不來，這一頁就交不出作業了。
    Future<void> startAttempt(WidgetTester tester) async {
      await tester.tap(saveButton(R.current.assignStartAttempt));
      await tester.pumpAndSettle();
      await tester.tap(find.text(R.current.sure));
      await tester.pumpAndSettle();
    }

    testWidgets('timelimitnotenabled：站台把時限關了，動作列直接變回儲存', (tester) async {
      MoodleRepository.instance = _StubStartRepository(
          const MoodleAssignStartAttempt(
              outcome: AssignStartOutcome.noTimeLimit));
      await pump(tester, submittable(), timed());

      await startAttempt(tester);

      // timelimit 還是 3600、timestarted 還是 0：只有那一則 warning 講得出來。
      expect(find.text(R.current.assignStartAttempt), findsNothing);
      expect(find.text(R.current.assignSaveDraft), findsOneWidget);
      expect(
          find.textContaining(
              sprintf(R.current.assignTimeLimitNotice, ['1:00:00'])),
          findsNothing);
    });

    testWidgets('伺服器開始了但狀態重抓失敗：照樣進儲存，並說出算不出還剩多久', (tester) async {
      MoodleRepository.instance = _StubStartRepository(
          const MoodleAssignStartAttempt(outcome: AssignStartOutcome.started));
      await pump(tester, submittable(), timed());

      await startAttempt(tester);

      expect(find.text(R.current.assignStartAttempt), findsNothing);
      expect(find.text(R.current.assignSaveDraft), findsOneWidget);
      expect(find.text(R.current.assignTimerStartedUnknown), findsOneWidget);
    });

    testWidgets('開始之後直接離開：伺服器的鐘已經在走，這件事要帶回上一頁', (tester) async {
      MoodleRepository.instance = _StubStartRepository(MoodleAssignStartAttempt(
          outcome: AssignStartOutcome.started,
          status: fixtureStatus('status_timed_started')));
      MoodleAssignSubmitResult? handed;

      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(GetMaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => handed =
                await Get.to<MoodleAssignSubmitResult>(
                    () => CourseAssignSubmitPage(
                          assignment: submittable(),
                          status: timed(),
                          courseName: '作業系統',
                          openWebView: (title, url) async {},
                        )),
            child: const Text('go'),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      await startAttempt(tester);
      await tester.tap(find.byIcon(LucideIcons.chevronLeft));
      await tester.pumpAndSettle();

      expect(find.byType(CourseAssignSubmitPage), findsNothing);
      expect(handed, isNotNull, reason: '草稿沒有任何痕跡記得這一趟寫入，回 null 上一頁就會停在「還沒開始」');
      expect(handed!.status, isNotNull);
      expect(handed!.submitted, isFalse);
    });

    testWidgets('沒按過開始就離開：什麼都沒寫過，不要謊報一趟寫入', (tester) async {
      MoodleAssignSubmitResult? handed;
      var popped = false;

      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(GetMaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              handed = await Get.to<MoodleAssignSubmitResult>(
                  () => CourseAssignSubmitPage(
                        assignment: submittable(),
                        status: timed(),
                        courseName: '作業系統',
                        openWebView: (title, url) async {},
                      ));
              popped = true;
            },
            child: const Text('go'),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.chevronLeft));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
      expect(handed, isNull);
    });
  });

  group('重新開放的那一次', () {
    testWidgets('又有草稿階段時兩件事都要講：不影響上一次的成績，但還要按送出評分', (tester) async {
      final status = fixtureStatus('status_reopened');
      await pump(tester, submittable(), status);

      final attempt =
          MoodleAssignAttemptUtils.attemptLabel(submittable(), status).current;
      expect(
          find.text(
              sprintf(R.current.assignConsequenceReopenedDraft, [attempt])),
          findsOneWidget);
      expect(find.text(sprintf(R.current.assignConsequenceReopened, [attempt])),
          findsNothing);
    });

    testWidgets('沒有草稿階段時維持原本那一句：存檔就是繳交，沒有第二步', (tester) async {
      final status = fixtureStatus('status_reopened');
      await pump(tester, noDrafts(), status);

      final attempt =
          MoodleAssignAttemptUtils.attemptLabel(noDrafts(), status).current;
      expect(find.text(sprintf(R.current.assignConsequenceReopened, [attempt])),
          findsOneWidget);
    });
  });

  /// 表頭不捲動又沒有高度上限：六個區塊全開時在 360x640 加一個中文輸入法
  /// 的鍵盤，工作區會被壓到零，Column 還會直接溢位。
  group('鍵盤升起時的表頭', () {
    testWidgets('收成一行：不溢位，工作區還在，讓位的是可以晚點再看的那幾行', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(GetMaterialApp(
        home: CourseAssignSubmitPage(
          assignment: submittable()..teamsubmission = 1,
          status: fixtureStatus('status_reopened'),
          courseName: '作業系統',
          openWebView: (title, url) async {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(R.current.assignTeamNotice), findsNothing);
      expect(
          find.textContaining(R.current.assignConsequenceDraft), findsNothing);
      expect(tester.getSize(find.byType(ListView)).height, greaterThan(100),
          reason: '工作區被壓到零就等於這一頁交不出作業');
    });
  });

  /// R2：移除與沿用上一次動的是伺服器上的那一份，不是編輯中的草稿，
  /// 所以這一頁連選單都沒有——在編輯器裡跑 copy 會讓畫面上每一個
  /// 已經填好的值變成過期的。
  group('這一頁沒有溢位選單', () {
    testWidgets('app bar 上沒有那三顆點，也沒有移除／沿用的字樣', (tester) async {
      await pump(tester, submittable(), fixtureStatus('status_draft'));

      expect(find.byIcon(LucideIcons.ellipsisVertical), findsNothing);
      expect(find.text(R.current.assignRemoveSubmission), findsNothing);
      expect(find.text(R.current.assignCopyPrevious), findsNothing);
    });
  });
}

/// 「開始作答」永遠回同一個結果，不碰網路。
/// 這一頁 initState 就會去問一次線上文字的原文。測試裡一律接住那一趟，
/// 否則它會真的打網路；預設回 null＝那一趟失敗，走「還原絕對網址」的退路。
class _NoNetworkRepo extends MoodleRepository {
  AssignOnlineTextEdit? editText;

  @override
  Future<AssignOnlineTextEdit?> fetchOnlineTextForEdit({
    required MoodleAssignment assignment,
  }) async =>
      editText;
}

/// 記下 `save_submission` 到底有沒有被送出去。
class _RecordingSaveRepo extends _NoNetworkRepo {
  AssignSubmissionDraft? saved;

  @override
  Future<Result<MoodleAssignSubmitResult>> saveAssignSubmission({
    required MoodleAssignment assignment,
    required MoodleAssignSubmissionStatus status,
    required AssignSubmissionDraft draft,
    void Function(AssignTransferProgress progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    saved = draft;
    return Ok(MoodleAssignSubmitResult(status: status, submitted: false));
  }
}

class _StubStartRepository extends _NoNetworkRepo {
  _StubStartRepository(this.attempt);

  final MoodleAssignStartAttempt attempt;
  int calls = 0;

  @override
  Future<Result<MoodleAssignStartAttempt>> startAssignAttempt({
    required MoodleAssignment assignment,
  }) async {
    calls++;
    return Ok(attempt);
  }
}

/// 挑選器叫不起來。
class _ThrowingPickService implements FilePickService {
  @override
  Future<List<File>> pick({
    required int limit,
    List<String> extensions = const [],
  }) async =>
      throw const FilePickFailure(FilePickFailureReason.unavailable);
}

/// 一直不完成的寫入：測進行中的畫面。
class _PendingRepo extends _NoNetworkRepo {
  final completer = Completer<Result<MoodleAssignSubmitResult>>();
  void Function(AssignTransferProgress progress)? onProgress;
  CancelToken? cancelToken;
  AssignSubmissionDraft? draft;

  @override
  Future<Result<MoodleAssignSubmitResult>> saveAssignSubmission({
    required MoodleAssignment assignment,
    required MoodleAssignSubmissionStatus status,
    required AssignSubmissionDraft draft,
    void Function(AssignTransferProgress progress)? onProgress,
    CancelToken? cancelToken,
  }) {
    this.draft = draft;
    this.onProgress = onProgress;
    this.cancelToken = cancelToken;
    return completer.future;
  }
}
