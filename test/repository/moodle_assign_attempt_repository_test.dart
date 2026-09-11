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
import 'package:flutter_app/src/util/moodle_assign_attempt_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/moodle_assign_fixtures.dart';
import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 不打網路的 [MoodleRepository]：只換掉真的會送出去的那三步。
class _FakeRepo extends MoodleRepository {
  MoodleApiException? removeError;
  MoodleApiException? copyError;
  MoodleApiException? startError;
  MoodleAssignStartResult startResult = const MoodleAssignStartResult(
      outcome: AssignStartOutcome.started, submissionId: 8810);

  MoodleAssignSubmissionStatus? nextStatus;
  Object? refetchError;

  int removeCalls = 0;
  int copyCalls = 0;
  int startCalls = 0;
  int refetchCalls = 0;

  /// 站台開放狀況；預設三支都開，個別測試再收緊。
  AssignAvailabilityOverride availability =
      const AssignAvailabilityOverride(remove: true, start: true, copy: true);

  @override
  Future<bool> writeRemoveSubmission({required int assignId}) async {
    removeCalls++;
    final error = removeError;
    if (error != null) throw error;
    return true;
  }

  @override
  Future<bool> writeCopyPreviousAttempt({required int assignId}) async {
    copyCalls++;
    final error = copyError;
    if (error != null) throw error;
    return true;
  }

  @override
  Future<MoodleAssignStartResult> writeStartSubmission(
      {required int assignId}) async {
    startCalls++;
    final error = startError;
    if (error != null) throw error;
    return startResult;
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
  AssignAvailability currentAssignAvailability() => (
        canRemove: availability.remove,
        canStart: availability.start,
        canCopy: availability.copy,
      );
}

/// [_FakeRepo.availability] 的載體；record 沒辦法當成可變欄位的預設值。
class AssignAvailabilityOverride {
  const AssignAvailabilityOverride(
      {required this.remove, required this.start, required this.copy});

  final bool remove;
  final bool start;
  final bool copy;
}

/// 三條新寫入路徑的行為。重點不是「有沒有送出去」，而是
/// 「不該送的時候真的沒送」、「送壞了絕對不會被報成成功」，以及
/// **每一條路徑（包含被拒絕）都重抓了狀態**——移除繳交是唯一一種
/// 「停在舊快取」比「顯示錯誤」更糟的寫入：舊快取會理直氣壯地畫出
/// 已經不存在的檔案。
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
    MoodleWebApiConnector.siteInfo = MoodleProfileEntity(uploadfiles: 1);
  });

  tearDown(() {
    MoodleRepository.instance = MoodleRepository();
    AuthSession.instance = const UninstalledAuthSession();
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
  });

  MoodleAssignment submittable() => fixtureSubmittableAssignment();
  MoodleAssignment noDrafts() => fixtureNoDraftsAssignment();

  /// draft + canedit：`actionsFor` 會給出 removeSubmission。
  MoodleAssignSubmissionStatus removable() => fixtureStatus('status_draft');

  MoodleAssignSubmissionStatus reopened() => fixtureStatus('status_reopened');

  group('removeAssignSubmission', () {
    test('成功：送一次、重抓一次，回傳的是重抓的那一份', () async {
      repo.nextStatus = fixtureStatus('status_none');

      final result = await repo.removeAssignSubmission(
          assignment: submittable(), status: removable());

      expect(result, isA<Ok<MoodleAssignSubmitResult>>());
      final value = (result as Ok<MoodleAssignSubmitResult>).data;
      expect(value.error, isNull);
      expect(value.submitted, isFalse);
      expect(value.status, same(repo.nextStatus));
      expect(repo.removeCalls, 1);
      expect(repo.refetchCalls, 1);
    });

    test('retry: none——被拒絕也只送一次，不可以把破壞性寫入重跑', () async {
      repo.removeError = MoodleApiException(
          wsFunction: MoodleWebApiConnector.removeSubmissionFunction,
          errorcode: 'couldnotremovesubmission');
      repo.nextStatus = removable();

      await repo.removeAssignSubmission(
          assignment: submittable(), status: removable());

      expect(repo.removeCalls, 1);
    });

    test('被拒絕仍然是 Ok，但帶著錯誤句子，而且照樣重抓', () async {
      repo.removeError = MoodleApiException(
          wsFunction: MoodleWebApiConnector.removeSubmissionFunction,
          errorcode: 'submissionnotfoundtoremove');
      repo.nextStatus = removable();

      final result = await repo.removeAssignSubmission(
          assignment: submittable(), status: removable());

      final value = (result as Ok<MoodleAssignSubmitResult>).data;
      // 文案不可以斷言「沒有東西可以移除」——那個 code 是拿自己那一列判的。
      expect(value.error, R.current.assignRemoveRejected);
      expect(value.status, same(repo.nextStatus));
      expect(repo.refetchCalls, 1, reason: '被拒絕也要重抓');
    });

    test('重抓失敗時把快取那一筆刪掉，不留下寫入前的舊檔案清單', () async {
      final key = MoodleRepository.submissionStatusKey(submittable().id);
      await repo.saveSubmissionStatus(submittable().id, removable());
      expect(await CacheStore.instance.read(key), isNotNull);

      repo.refetchError = Exception('offline');

      final result = await repo.removeAssignSubmission(
          assignment: submittable(), status: removable());

      final value = (result as Ok<MoodleAssignSubmitResult>).data;
      expect(value.status, isNull);
      expect(await CacheStore.instance.read(key), isNull,
          reason: '寧可沒有快取，也不要一份說謊的快取');
    });

    test('狀態已經不允許移除時一趟都不送（縱深防禦）', () async {
      // reopened 沒有東西可以移除，網頁也不畫那一項。
      final result = await repo.removeAssignSubmission(
          assignment: submittable(), status: reopened());

      expect(result, isA<Failed<MoodleAssignSubmitResult>>());
      expect(repo.removeCalls, 0);
      expect(repo.refetchCalls, 0);
    });

    test('站台沒開放這一支時也不送', () async {
      repo.availability = const AssignAvailabilityOverride(
          remove: false, start: true, copy: true);

      final result = await repo.removeAssignSubmission(
          assignment: submittable(), status: removable());

      expect(result, isA<Failed<MoodleAssignSubmitResult>>());
      expect(repo.removeCalls, 0);
    });
  });

  group('copyPreviousAssignAttempt', () {
    test('成功：有草稿階段的作業複製過來還是草稿', () async {
      repo.nextStatus = fixtureStatus('status_draft');

      final result = await repo.copyPreviousAssignAttempt(
          assignment: submittable(), status: reopened());

      final value = (result as Ok<MoodleAssignSubmitResult>).data;
      expect(value.error, isNull);
      expect(value.submitted, isFalse);
      expect(repo.copyCalls, 1);
      expect(repo.refetchCalls, 1);
    });

    test('沒有草稿階段的作業：複製過來伺服器就標成 submitted', () async {
      // 狀態翻轉發生在外掛複製迴圈之前，回條也已經寄出去了。
      repo.nextStatus = fixtureStatus('status_can_submit');

      final result = await repo.copyPreviousAssignAttempt(
          assignment: noDrafts(), status: reopened());

      final value = (result as Ok<MoodleAssignSubmitResult>).data;
      expect(value.submitted, isTrue);
    });

    test('被拒絕也要重抓——狀態翻轉在複製之前，伺服器上可能是半套的', () async {
      repo.copyError = MoodleApiException(
          wsFunction: MoodleWebApiConnector.copyPreviousAttemptFunction,
          errorcode: 'couldnotcopyprevioussubmission');
      repo.nextStatus = reopened();

      final result = await repo.copyPreviousAssignAttempt(
          assignment: submittable(), status: reopened());

      final value = (result as Ok<MoodleAssignSubmitResult>).data;
      expect(value.error, R.current.assignCopyPreviousRejected);
      expect(repo.refetchCalls, 1);
      expect(repo.copyCalls, 1, reason: 'retry: none');
    });

    test('站台沒開放這一支時一趟都不送——多數站台就是這一條路', () async {
      repo.availability = const AssignAvailabilityOverride(
          remove: true, start: true, copy: false);

      final result = await repo.copyPreviousAssignAttempt(
          assignment: submittable(), status: reopened());

      expect(result, isA<Failed<MoodleAssignSubmitResult>>());
      expect(repo.copyCalls, 0);
    });

    test('狀態不是 reopened 時不送——伺服器只允許那一種', () async {
      final result = await repo.copyPreviousAssignAttempt(
          assignment: submittable(), status: removable());

      expect(result, isA<Failed<MoodleAssignSubmitResult>>());
      expect(repo.copyCalls, 0);
    });
  });

  group('startAssignAttempt', () {
    test('started：重抓狀態，否則畫面不知道 timestarted，倒數會從頭算', () async {
      repo.nextStatus = fixtureStatus('status_timed_started');

      final result = await repo.startAssignAttempt(assignment: submittable());

      final value = (result as Ok<MoodleAssignStartAttempt>).data;
      expect(value.outcome, AssignStartOutcome.started);
      expect(value.status, same(repo.nextStatus));
      expect(repo.refetchCalls, 1);
    });

    test('alreadyRunning 是接續不是失敗，一樣要重抓', () async {
      repo.startResult = const MoodleAssignStartResult(
          outcome: AssignStartOutcome.alreadyRunning, submissionId: 0);
      repo.nextStatus = fixtureStatus('status_timed_started');

      final result = await repo.startAssignAttempt(assignment: submittable());

      final value = (result as Ok<MoodleAssignStartAttempt>).data;
      expect(value.outcome, AssignStartOutcome.alreadyRunning);
      expect(value.status, isNotNull);
      expect(repo.refetchCalls, 1);
    });

    test('noTimeLimit：伺服器什麼都沒寫，不必重抓，也不是錯誤', () async {
      repo.startResult = const MoodleAssignStartResult(
          outcome: AssignStartOutcome.noTimeLimit, submissionId: 0);

      final result = await repo.startAssignAttempt(assignment: submittable());

      final value = (result as Ok<MoodleAssignStartAttempt>).data;
      expect(value.outcome, AssignStartOutcome.noTimeLimit);
      expect(value.status, isNull);
      expect(repo.refetchCalls, 0);
    });

    test('notOpen 是唯一真的失敗', () async {
      repo.startResult = const MoodleAssignStartResult(
          outcome: AssignStartOutcome.notOpen, submissionId: 0);

      final result = await repo.startAssignAttempt(assignment: submittable());

      expect(result, isA<Failed<MoodleAssignStartAttempt>>());
      expect(repo.refetchCalls, 0);
    });

    test('連線層的例外翻成失敗，而且只送一次', () async {
      repo.startError = MoodleApiException(
          wsFunction: MoodleWebApiConnector.startSubmissionFunction,
          errorcode: 'badresponse');

      final result = await repo.startAssignAttempt(assignment: submittable());

      expect(result, isA<Failed<MoodleAssignStartAttempt>>());
      expect(repo.startCalls, 1, reason: 'retry: none');
    });
  });

  group('assignSubmitFailureMessage 的新 code', () {
    test('remove 的兩個 code 都對映到同一句「沒移除成功」', () {
      for (final code in [
        'submissionnotfoundtoremove',
        'couldnotremovesubmission'
      ]) {
        expect(
            assignSubmitFailureMessage(
                MoodleApiException(wsFunction: 'x', errorcode: code)),
            R.current.assignRemoveRejected,
            reason: code);
      }
    });

    test('copy 的那一個 code 有自己的句子——伺服器的 message 是「Unknown warning type.」', () {
      expect(
        assignSubmitFailureMessage(MoodleApiException(
            wsFunction: 'x', errorcode: 'couldnotcopyprevioussubmission')),
        R.current.assignCopyPreviousRejected,
      );
    });

    test('submissionnotopen 講的是「現在不開放繳交」', () {
      expect(
        assignSubmitFailureMessage(MoodleApiException(
            wsFunction: 'x', errorcode: 'submissionnotopen')),
        R.current.assignStartNotOpen,
      );
    });

    test('認不得的 code 落回涵蓋性的那一句，不可以把伺服器的英文原文丟出去', () {
      expect(
        assignSubmitFailureMessage(MoodleApiException(
            wsFunction: 'x',
            errorcode: 'somethingtheserverinvented',
            message: 'Unknown warning type.')),
        R.current.assignSubmitError,
      );
    });
  });
}
