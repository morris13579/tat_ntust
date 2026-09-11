import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/store/cache_store.dart';
import 'package:flutter_app/src/util/file_utils.dart';
import 'package:flutter_app/src/util/moodle_assign_submit_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprintf/sprintf.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/moodle_assign_fixtures.dart';
import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 不打網路的 [MoodleRepository]：只換掉真的會送出去的那幾步。
class _FakeRepo extends MoodleRepository {
  _FakeRepo(this.tempRoot);

  final Directory tempRoot;

  /// 依序回傳的 draft itemid；用完之後一律回 [draftId]。
  int? draftId = 900;
  MoodleApiException? draftError;
  MoodleApiException? saveError;
  MoodleApiException? submitError;
  bool downloadOk = true;

  /// [downloadOnlineFile] 落地的位元組數；預設對得上 [online] 給的 filesize。
  int downloadedBytes = 16;

  MoodleAssignSubmissionStatus? nextStatus;
  Object? refetchError;

  final List<int?> draftItemIds = [];
  final List<String> uploadedNames = [];
  final List<String> downloadedUrls = [];
  final List<String> downloadedPaths = [];
  int saveCalls = 0;
  int submitCalls = 0;
  int refetchCalls = 0;
  final List<AssignTransferProgress> progressReports = [];
  String? lastOnlineText;
  int? lastDraftItemIdOnSave;
  bool? lastAcceptStatement;
  Directory? createdTempDir;

  int get draftCalls => draftItemIds.length;

  @override
  Future<int?> writeDraftFile(
    File file, {
    required String filename,
    int? draftItemId,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    draftItemIds.add(draftItemId);
    uploadedNames.add(filename);
    final error = draftError;
    if (error != null) throw error;
    onProgress?.call(50, 100);
    return draftId;
  }

  @override
  Future<bool> writeSubmission({
    required int assignId,
    String? onlineText,
    int? draftItemId,
  }) async {
    saveCalls++;
    lastOnlineText = onlineText;
    lastDraftItemIdOnSave = draftItemId;
    final error = saveError;
    if (error != null) throw error;
    return true;
  }

  @override
  Future<bool> writeSubmitForGrading({
    required int assignId,
    required bool acceptStatement,
  }) async {
    submitCalls++;
    lastAcceptStatement = acceptStatement;
    final error = submitError;
    if (error != null) throw error;
    return true;
  }

  @override
  Future<bool> downloadOnlineFile(String fileUrl, String savePath,
      {CancelToken? cancelToken,
      void Function(int received, int total)? onProgress}) async {
    downloadedUrls.add(fileUrl);
    downloadedPaths.add(savePath);
    if (!downloadOk) return false;
    onProgress?.call(8, 16);
    File(savePath).writeAsBytesSync(List<int>.filled(downloadedBytes, 7));
    return true;
  }

  @override
  Future<MoodleAssignSubmissionStatus?> refetchSubmissionStatus(
      int assignId) async {
    refetchCalls++;
    final error = refetchError;
    if (error != null) throw error;
    return nextStatus;
  }

  @override
  Future<Directory> createSubmitTempDir() async {
    final dir = Directory('${tempRoot.path}/submit_${draftItemIds.length}');
    await dir.create(recursive: true);
    return createdTempDir = dir;
  }
}

/// [MoodleRepository.saveAssignSubmission] 的行為。這是一條寫入路徑，所以每一
/// 條測試不是在確認「有沒有送」，而是在確認「不該送的時候真的沒送」，以及
/// 「送壞了絕對不會被報成成功」。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRepo repo;
  late Directory tempDir;
  late TestStores stores;

  setUpAll(() async {
    await loadTestL10n();
  });

  setUp(() {
    stores = resetAppStatics();
    tempDir = Directory.systemTemp.createTempSync('assign_submit_repo_test');
    repo = _FakeRepo(tempDir);
    MoodleRepository.instance = repo;
    AuthSession.instance = FakeAuthSession();
    TaskUiDelegate.instance = RecordingUi();
    ConnectivityProbe.instance = FakeConnectivityProbe();
    MoodleWebApiConnector.siteInfo = MoodleProfileEntity(uploadfiles: 1);
  });

  tearDown(() {
    MoodleRepository.instance = MoodleRepository();
    AuthSession.instance = const UninstalledAuthSession();
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  MoodleAssignment submittable() => fixtureSubmittableAssignment();

  MoodleAssignSubmissionStatus canEdit() => fixtureStatus('status_can_edit');

  File makeFile(String name, {int bytes = 32}) {
    final file = File('${tempDir.path}/$name');
    file.writeAsBytesSync(List<int>.filled(bytes, 1));
    return file;
  }

  LocalDraftFile local(String name, {int bytes = 32}) =>
      LocalDraftFile(makeFile(name, bytes: bytes), name, size: bytes);

  OnlineDraftFile online(String name, {int filesize = 16}) => OnlineDraftFile(
        name,
        'https://moodle2.ntust.edu.tw/webservice/pluginfile.php/555/'
        'assignsubmission_file/submission_files/8901/$name',
        filesize: filesize,
      );

  Future<Result<MoodleAssignSubmitResult>> save({
    MoodleAssignment? assignment,
    MoodleAssignSubmissionStatus? status,
    String? onlineText,
    List<AssignDraftFile>? files,
    bool submitForGrading = false,
    bool acceptStatement = false,
  }) =>
      MoodleRepository.instance.saveAssignSubmission(
        assignment: assignment ?? submittable(),
        status: status ?? canEdit(),
        draft: AssignSubmissionDraft(
          onlineText: onlineText,
          files: files,
          submitForGrading: submitForGrading,
          acceptStatement: acceptStatement,
        ),
        onProgress: repo.progressReports.add,
      );

  String messageOf(Result<Object?> r) => (r as Failed).reason.message;

  group('只改線上文字', () {
    test('files 是 null 時一個檔案都不傳，也不送 files_filemanager', () async {
      final result = await save(onlineText: '<p>報告</p>');

      expect(result, isA<Ok<MoodleAssignSubmitResult>>());
      expect(repo.draftCalls, 0);
      expect(repo.saveCalls, 1);
      expect(repo.lastOnlineText, '<p>報告</p>');
      // 不送 files_filemanager 就是保留繳交區現有的檔案。
      expect(repo.lastDraftItemIdOnSave, isNull);
    });

    test('什麼都沒動就不發任何請求', () async {
      final result = await save();

      expect(messageOf(result), R.current.assignNothingToSubmit);
      expect(repo.saveCalls, 0);
      expect(repo.draftCalls, 0);
    });
  });

  group('draft 區', () {
    test('多個檔案串同一個 itemid：第一個不送，其餘都送第一次拿到的那個', () async {
      repo.draftId = 4242;

      final result = await save(files: [
        local('a.pdf'),
        local('b.pdf'),
        local('c.pdf'),
      ]);

      expect(result, isA<Ok<MoodleAssignSubmitResult>>());
      expect(repo.draftItemIds, [null, 4242, 4242]);
      expect(repo.uploadedNames, ['a.pdf', 'b.pdf', 'c.pdf']);
      expect(repo.lastDraftItemIdOnSave, 4242);
    });

    test('要保留的舊檔案先下載再重傳，不是被略過', () async {
      final result = await save(files: [online('old.pdf'), local('new.pdf')]);

      expect(result, isA<Ok<MoodleAssignSubmitResult>>());
      expect(repo.downloadedUrls, hasLength(1));
      expect(repo.downloadedUrls.single, contains('old.pdf'));
      // 下載回來的那一份也要進 draft 區，否則伺服器會把它 delete 掉。
      expect(repo.uploadedNames, ['old.pdf', 'new.pdf']);
    });

    test('暫存檔在成功之後被清掉', () async {
      await save(files: [online('old.pdf')]);

      expect(repo.createdTempDir, isNotNull);
      expect(repo.createdTempDir!.existsSync(), isFalse);
    });

    test('下載失敗：整批放棄、不呼叫 save_submission，暫存檔照樣清掉', () async {
      repo.downloadOk = false;

      final result = await save(files: [online('old.pdf'), local('new.pdf')]);

      expect(result, isA<Failed<MoodleAssignSubmitResult>>());
      expect(repo.saveCalls, 0);
      expect(repo.createdTempDir!.existsSync(), isFalse);
    });

    test('上傳到一半失敗就整批放棄——半套的 draft 不可以送出去', () async {
      repo.draftError = MoodleApiException(
          wsFunction: 'upload', errorcode: 'filenameexist', message: 'x');

      final result = await save(files: [local('a.pdf'), local('b.pdf')]);

      expect(messageOf(result), R.current.assignFileDuplicateName);
      expect(repo.saveCalls, 0);
    });
  });

  group('送出前的本地把關（伺服器會靜靜吃掉，所以一趟都不能發）', () {
    test('檔案數超過 maxfilesubmissions', () async {
      final result = await save(files: [
        local('a.pdf'),
        local('b.pdf'),
        local('c.pdf'),
        local('d.pdf'),
      ]);

      expect(
          messageOf(result), sprintf(R.current.assignFileCountExceeded, ['3']));
      expect(repo.draftCalls, 0);
      expect(repo.saveCalls, 0);
    });

    test('單一檔案超過 maxsubmissionsizebytes', () async {
      final result = await save(files: [local('big.pdf', bytes: 2097153)]);

      expect(
        messageOf(result),
        sprintf(R.current.assignFileTooLarge,
            ['big.pdf', FileUtils.formatBytes(2097152, 1)]),
      );
      expect(repo.draftCalls, 0);
      expect(repo.saveCalls, 0);
    });

    test('檔名重複（upload.php 會回 filenameexist）', () async {
      final result = await save(files: [
        local('a.pdf'),
        const OnlineDraftFile('A.PDF', 'https://moodle2.ntust.edu.tw/x/A.PDF'),
      ]);

      expect(messageOf(result), R.current.assignFileDuplicateName);
      expect(repo.draftCalls, 0);
    });

    test('站台關掉檔案上傳', () async {
      MoodleWebApiConnector.siteInfo = MoodleProfileEntity(uploadfiles: 0);

      final result = await save(files: [local('a.pdf')]);

      expect(messageOf(result), R.current.assignUploadDisabled);
      expect(repo.draftCalls, 0);
    });

    test('伺服器說不能編輯時連 draft 都不建（縱深防禦）', () async {
      final result = await save(
        status: fixtureStatus('status_locked'),
        onlineText: '<p>x</p>',
        files: [local('a.pdf')],
      );

      expect(messageOf(result), R.current.assignSubmitRejected);
      expect(repo.draftCalls, 0);
      expect(repo.saveCalls, 0);
    });
  });

  group('送出評分', () {
    test('submitForGrading 為 false 時不呼叫', () async {
      await save(onlineText: '<p>x</p>');

      expect(repo.submitCalls, 0);
    });

    test('沒有草稿階段的作業不送第二趟：save_submission 已經是繳交了', () async {
      // 再送一次必定回 couldnotsubmitforgrading，等於把成功報成失敗。
      final result = await save(
        assignment: fixtureNoDraftsAssignment(),
        onlineText: '<p>x</p>',
        submitForGrading: true,
        acceptStatement: true,
      );

      expect(result, isA<Ok<MoodleAssignSubmitResult>>());
      expect(repo.submitCalls, 0);
      expect(result.dataOrNull!.submitted, isTrue);
    });

    test('為 true 時呼叫，acceptStatement 原樣傳下去', () async {
      await save(
          onlineText: '<p>x</p>',
          submitForGrading: true,
          acceptStatement: true);

      expect(repo.submitCalls, 1);
      expect(repo.lastAcceptStatement, isTrue);
    });

    test('存檔成功但送出評分失敗：不報成功，但重抓到的狀態照樣帶上去', () async {
      repo.nextStatus = fixtureStatus('status_can_submit');
      repo.submitError = MoodleApiException(
          wsFunction: 'mod_assign_submit_for_grading',
          errorcode: 'couldnotsubmitforgrading',
          message: 'x');

      final result = await save(onlineText: '<p>x</p>', submitForGrading: true);

      // Failed 帶不了資料，而內容真的存進去了：畫面停在存檔前才是說謊。
      expect(result.dataOrNull!.error, R.current.assignSavedNotSubmitted);
      expect(result.dataOrNull!.submitted, isFalse);
      expect(result.dataOrNull!.status, isNotNull);
      expect(repo.saveCalls, 1);
      expect(repo.refetchCalls, 1);
      // 使用者要看到「已存成草稿」，所以那一趟重抓的結果也要進快取。
      final cached = await CacheStore.instance
          .read(MoodleRepository.submissionStatusKey(submittable().id));
      expect(cached, isNotNull);
    });
  });

  /// 存回去之前拿原文的那一趟。它跟畫面上那一份長得很像，所以型別與快取
  /// 這兩道防線都要有測試守著。
  group('fetchOnlineTextForEdit', () {
    Future<AssignOnlineTextEdit?> fetch() =>
        repo.fetchOnlineTextForEdit(assignment: submittable());

    test('拿得到原文，但 cache_moodle_assign_status 底下什麼都沒寫', () async {
      MoodleWebApiConnector.wsToken = 'token-123';
      MoodleWebApiConnector.userId = '5252';
      MoodleWebApiConnector.wsPost =
          (_) async => loadMoodleAssignFixture('status_onlinetext_inline');

      final edit = await fetch();

      expect(edit!.rawText, contains('<img'));
      // 進了快取的話，詳情頁之後每次都會把 @@PLUGINFILE@@ 畫成破圖。
      expect(
          await CacheStore.instance
              .read(MoodleRepository.submissionStatusKey(submittable().id)),
          isNull);
    });

    test('那一趟失敗回 null，不是丟例外——儲存不可以因此變成不可能', () async {
      MoodleWebApiConnector.wsToken = 'token-123';
      MoodleWebApiConnector.userId = '5252';
      MoodleWebApiConnector.wsPost = (_) async => throw MoodleApiException(
          wsFunction: MoodleWebApiConnector.submissionStatusFunction,
          errorcode: 'invalidtoken',
          message: 'x');

      expect(await fetch(), isNull);
    });
  });

  group('被伺服器拒絕（save_submission 不是原子的）', () {
    MoodleApiException rejected() => MoodleApiException(
        wsFunction: 'mod_assign_save_submission',
        errorcode: 'couldnotsavesubmission',
        message: 'Could not save submission.');

    test('送出去之後被拒：不是 Failed，而是帶著重抓狀態與訊息的 Ok', () async {
      // 一個外掛成功、另一個失敗也只回一則 warning，所以拒絕之後伺服器上
      // 到底變成什麼樣子只有重抓的狀態說得準。
      repo.saveError = rejected();
      repo.nextStatus = fixtureStatus('status_can_submit');

      final result = await save(onlineText: '<p>x</p>');

      expect(result, isA<Ok<MoodleAssignSubmitResult>>());
      final data = result.dataOrNull!;
      expect(data.error, R.current.assignSubmitRejected);
      expect(data.submitted, isFalse);
      expect(data.status, isNotNull);
      expect(repo.refetchCalls, 1);
    });

    test('還沒送出 save_submission 就失敗：照樣是 Failed，也不必重抓', () async {
      repo.draftError = MoodleApiException(
          wsFunction: 'upload', errorcode: 'virusfounduser', message: 'x');

      final result = await save(files: [local('a.pdf')]);

      expect(messageOf(result), R.current.assignFileVirusFound);
      expect(repo.saveCalls, 0);
      expect(repo.refetchCalls, 0);
    });
  });

  group('重抓不到狀態', () {
    test('把繳交前的那一筆快取刪掉，離線時不可以拿它冒充現況', () async {
      final key = MoodleRepository.submissionStatusKey(submittable().id);
      await MoodleRepository.instance
          .saveSubmissionStatus(submittable().id, canEdit());
      expect(await CacheStore.instance.read(key), isNotNull);

      repo.refetchError = Exception('boom');
      final result = await save(onlineText: '<p>x</p>');

      expect(result.dataOrNull!.status, isNull);
      expect(await CacheStore.instance.read(key), isNull);
    });
  });

  group('重傳舊檔案', () {
    test('下載回來的長度對不上 filesize：整批放棄，一個字都不寫進去', () async {
      // files_filemanager 是同步：把一頁錯誤 HTML 當成 report.pdf 傳上去，
      // 伺服器就會刪掉真的那一份。
      repo.downloadedBytes = 5;

      final result = await save(files: [online('old.pdf', filesize: 16)]);

      expect(messageOf(result), R.current.assignSubmitError);
      expect(repo.draftCalls, 0);
      expect(repo.saveCalls, 0);
    });

    test('伺服器沒給 filesize 時只要求檔案非空', () async {
      repo.downloadedBytes = 5;

      final result = await save(files: [online('old.pdf', filesize: 0)]);

      expect(result, isA<Ok<MoodleAssignSubmitResult>>());
      expect(repo.uploadedNames, ['old.pdf']);
    });

    test('進度先報 download 再報 upload：整段下載不可以說成「正在上傳」', () async {
      await save(files: [online('old.pdf')]);

      final phases = repo.progressReports
          .where((p) => p.filename == 'old.pdf')
          .map((p) => p.phase)
          .toList();
      expect(phases.first, AssignTransferPhase.download);
      expect(phases.last, AssignTransferPhase.upload);
      // 下載那一段佔前半，上傳接在後面，進度條不會倒退。
      final download = repo.progressReports
          .where((p) => p.phase == AssignTransferPhase.download);
      expect(download.every((p) => p.ratio <= 0.5), isTrue);
    });
  });

  group('成功之後', () {
    test('重抓狀態並寫回同一把快取鍵', () async {
      repo.nextStatus = fixtureStatus('status_can_submit');

      final result = await save(onlineText: '<p>x</p>');

      expect(repo.refetchCalls, 1);
      expect(result.dataOrNull!.status, isNotNull);
      expect(result.dataOrNull!.status!.canSubmit, isTrue);

      final cached = await CacheStore.instance
          .read(MoodleRepository.submissionStatusKey(submittable().id));
      expect(cached!.canSubmit, isTrue);
      expect(await stores.plain.readString('cache_moodle_assign_status'),
          isNotNull);
    });

    test('重抓失敗不會把已經成功的寫入翻成失敗', () async {
      repo.refetchError = Exception('boom');

      final result = await save(onlineText: '<p>x</p>');

      expect(result, isA<Ok<MoodleAssignSubmitResult>>());
      expect(result.dataOrNull!.status, isNull);
    });

    test('沒有草稿階段的作業，存檔就是繳交：submitted 為 true', () async {
      final result = await save(
        assignment: fixtureNoDraftsAssignment(),
        onlineText: '<p>x</p>',
        submitForGrading: false,
      );

      expect(result.dataOrNull!.submitted, isTrue);
    });

    test('有草稿階段又沒送出評分：submitted 為 false', () async {
      final result = await save(onlineText: '<p>x</p>');

      expect(result.dataOrNull!.submitted, isFalse);
    });
  });

  group('submitAssignForGrading', () {
    test('cansubmit 為 false 時連送都不送', () async {
      final result = await MoodleRepository.instance.submitAssignForGrading(
        assignment: submittable(),
        status: canEdit(),
        acceptStatement: true,
      );

      expect(messageOf(result), R.current.assignSubmitForGradingRejected);
      expect(repo.submitCalls, 0);
    });

    test('被拒絕時回帶 error 的 Ok，而且狀態仍然重抓', () async {
      repo.nextStatus = fixtureStatus('status_can_submit');
      repo.submitError = MoodleApiException(
          wsFunction: 'mod_assign_submit_for_grading',
          errorcode: 'couldnotsubmitforgrading',
          message: 'x');

      final result = await MoodleRepository.instance.submitAssignForGrading(
        assignment: submittable(),
        status: fixtureStatus('status_can_submit'),
        acceptStatement: false,
      );

      expect(
          result.dataOrNull!.error, R.current.assignSubmitForGradingRejected);
      expect(result.dataOrNull!.submitted, isFalse);
      expect(result.dataOrNull!.status, isNotNull);
      expect(repo.refetchCalls, 1);
    });

    test('成功之後重抓狀態並回 submitted', () async {
      repo.nextStatus = fixtureStatus('status_graded');

      final result = await MoodleRepository.instance.submitAssignForGrading(
        assignment: submittable(),
        status: fixtureStatus('status_can_submit'),
        acceptStatement: false,
      );

      expect(result, isA<Ok<MoodleAssignSubmitResult>>());
      expect(repo.submitCalls, 1);
      expect(repo.lastAcceptStatement, isFalse);
      expect(repo.refetchCalls, 1);
      expect(result.dataOrNull!.submitted, isTrue);
    });
  });

  group('assignSubmitFailureMessage', () {
    MoodleApiException e(String? code) =>
        MoodleApiException(wsFunction: 'x', errorcode: code, message: 'raw');

    test('每一個認得的 errorcode 都有一句中文', () {
      expect(assignSubmitFailureMessage(e('couldnotsavesubmission')),
          R.current.assignSubmitRejected);
      expect(assignSubmitFailureMessage(e('couldnotsubmitforgrading')),
          R.current.assignSubmitForGradingRejected);
      expect(assignSubmitFailureMessage(e('submissionslocked')),
          R.current.assignSubmitLocked);
      for (final code in [
        'nopermissions',
        'required_capability_exception',
        'accessexception',
      ]) {
        expect(assignSubmitFailureMessage(e(code)),
            R.current.assignSubmitNoPermission);
      }
      expect(assignSubmitFailureMessage(e('filenameexist')),
          R.current.assignFileDuplicateName);
      for (final code in [
        'fileoversized',
        'userquotalimit',
        'upload_error_ini_size',
        'upload_error_form_size',
      ]) {
        expect(assignSubmitFailureMessage(e(code)),
            R.current.assignFileTooLargeUnknown);
      }
      expect(assignSubmitFailureMessage(e('virusfounduser')),
          R.current.assignFileVirusFound);
    });

    test('認不得的 errorcode 回通用訊息，不把英文原文丟到畫面上', () {
      expect(assignSubmitFailureMessage(e('somethingnew')),
          R.current.assignSubmitError);
      expect(assignSubmitFailureMessage(e(null)), R.current.assignSubmitError);
    });
  });
}
