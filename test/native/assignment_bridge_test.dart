import 'dart:io';

import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';
import 'package:flutter_app/src/native/assignment_bridge.dart';
import 'package:flutter_app/src/native/moodle_memo.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/util/moodle_assign_attempt_utils.dart';
import 'package:flutter_app/src/util/moodle_assign_submit_utils.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

class _FakeMoodle extends MoodleRepository {
  Result<MoodleAssignment> assignment = const Failed(FetchFailed());
  Result<MoodleAssignSubmissionStatus> status = const Failed(FetchFailed());
  Result<MoodleAssignSubmitResult> write = const Failed(FetchFailed());
  int assignmentCalls = 0;
  int statusCalls = 0;
  AssignSubmissionDraft? savedDraft;

  @override
  Future<Result<MoodleAssignment>> getAssignment(
      String courseId, int assignId) async {
    assignmentCalls++;
    return assignment;
  }

  @override
  Future<Result<MoodleAssignSubmissionStatus>> getSubmissionStatus(
      int assignId,
      {bool background = false}) async {
    statusCalls++;
    return status;
  }

  @override
  AssignAvailability currentAssignAvailability() =>
      (canRemove: true, canStart: true, canCopy: true);

  @override
  Future<Result<MoodleAssignSubmitResult>> submitAssignForGrading({
    required MoodleAssignment assignment,
    required MoodleAssignSubmissionStatus status,
    required bool acceptStatement,
  }) async =>
      write;

  @override
  Future<Result<MoodleAssignSubmitResult>> saveAssignSubmission({
    required MoodleAssignment assignment,
    required MoodleAssignSubmissionStatus status,
    required AssignSubmissionDraft draft,
    void Function(AssignTransferProgress progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    savedDraft = draft;
    onProgress?.call(const AssignTransferProgress(
        done: 0,
        total: 1,
        ratio: 0.5,
        phase: AssignTransferPhase.upload,
        filename: 'a.pdf'));
    return write;
  }
}

final DateTime now = DateTime(2026, 9, 16, 10);

int unix(DateTime time) => time.millisecondsSinceEpoch ~/ 1000;

MoodleAssignment fileAssignment({int drafts = 1}) => MoodleAssignment(
      id: 7,
      cmid: 70,
      name: '期末報告',
      duedate: unix(now.add(const Duration(days: 3))),
      submissiondrafts: drafts,
      intro: '<p>寫一份報告</p>',
      configs: [
        for (final (name, value) in [
          ('enabled', '1'),
          ('maxfilesubmissions', '2'),
          ('maxsubmissionsizebytes', '10'),
          ('filetypeslist', '.pdf'),
        ])
          MoodleAssignConfig(
              plugin: 'file',
              subtype: 'assignsubmission',
              name: name,
              value: value),
      ],
    );

MoodleAssignSubmissionStatus editable(
        {String state = 'new', List<MoodleAssignFile> files = const []}) =>
    MoodleAssignSubmissionStatus(
      lastattempt: MoodleAssignLastAttempt(
        submission: MoodleAssignSubmission(
          status: state,
          plugins: [
            MoodleAssignPlugin(
                type: 'file',
                fileareas: [MoodleAssignFileArea(files: files)]),
          ],
        ),
        canedit: true,
        submissionsenabled: true,
      ),
    );

/// 原生版的作業詳情與繳交。什麼時候給繳交入口、寫入之後畫面拿什麼當真相、
/// 挑回來的檔案擋不擋，全是 Dart 的判斷——壞了，原生版會拿舊快取把草稿交出去，
/// 或在伺服器已經收下之後還邀請使用者再交一次。
void main() {
  setUpAll(() async {
    await loadTestL10n();
    await initializeDateFormatting();
  });

  late _FakeMoodle moodle;
  late MoodleMemo memo;
  late AssignmentBridge bridge;
  late List<TransferProgress> progress;

  setUp(() {
    resetAppStatics();
    AuthSession.instance = FakeAuthSession();
    moodle = _FakeMoodle();
    MoodleRepository.instance = moodle;
    memo = MoodleMemo();
    progress = [];
    bridge = AssignmentBridge(memo, now: () => now, onProgress: progress.add);
  });

  tearDown(() => MoodleRepository.instance = MoodleRepository());

  group('詳情', () {
    test('清單抓過的作業與狀態直接沿用，不再抓', () async {
      memo.assignments['CS1'] = [fileAssignment()];
      memo.statuses[7] = Ok(editable());

      final detail = (await bridge.detail('CS1', 7, false)).detail!;

      expect((moodle.assignmentCalls, moodle.statusCalls), (0, 0));
      expect(detail.name, '期末報告');
      expect(detail.dueHint, '3 天後截止');
      expect(detail.entryLabel, '新增繳交');
      expect(detail.chipLabel, '未繳交');
      expect(detail.introHtml, '<p>寫一份報告</p>');
    });

    test('清單上抓失敗的狀態要重抓；重新整理兩個都重抓', () async {
      memo.assignments['CS1'] = [fileAssignment()];
      memo.statuses[7] = const Failed(FetchFailed());
      moodle.status = Ok(editable());
      moodle.assignment = Ok(fileAssignment());

      await bridge.detail('CS1', 7, false);
      expect((moodle.assignmentCalls, moodle.statusCalls), (0, 1));

      await bridge.detail('CS1', 7, true);
      expect((moodle.assignmentCalls, moodle.statusCalls), (1, 2));
    });

    test('狀態是快取：只給看，入口換成「請先重新整理」，也開不了繳交頁', () async {
      memo.assignments['CS1'] = [fileAssignment()];
      memo.statuses[7] = Stale(editable(), const FetchFailed('離線'));

      final detail = (await bridge.detail('CS1', 7, false)).detail!;

      expect(detail.needsFresh, isTrue);
      expect(detail.entryLabel, isNull);
      expect(detail.canRemove, isFalse);
      expect(detail.chipStale, isTrue);
      expect(bridge.openSubmit(7), isNull);
    });

    test('送出評分：伺服器回的新狀態直接套上，清單也看得到', () async {
      memo.assignments['CS1'] = [fileAssignment()];
      moodle.status = Ok(editable(state: 'draft'));
      await bridge.detail('CS1', 7, false);
      moodle.write = Ok(MoodleAssignSubmitResult(
          status: editable(state: 'submitted'), submitted: true));

      final result = await bridge.submitForGrading(7, false);

      expect(result.messages, ['作業已繳交']);
      expect(result.detail?.chipLabel, '待評分');
      expect(memo.statuses[7]?.dataOrNull?.lastattempt?.submission?.status,
          'submitted');
    });

    test('被拒絕又抓不到新狀態：兩句都說，並自己再抓一次', () async {
      memo.assignments['CS1'] = [fileAssignment()];
      moodle.status = Ok(editable(state: 'draft'));
      await bridge.detail('CS1', 7, false);
      moodle.write = const Ok(
          MoodleAssignSubmitResult(status: null, submitted: false, error: '被拒絕'));
      final before = moodle.statusCalls;

      final result = await bridge.submitForGrading(7, false);

      expect(result.messages, ['被拒絕', '已送出，但沒有抓到最新狀態，請重新整理確認']);
      expect(moodle.statusCalls, before + 1);
    });
  });

  group('繳交頁', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('assign_bridge_test');
      memo.assignments['CS1'] = [fileAssignment()];
    });

    tearDown(() => temp.delete(recursive: true));

    Future<String> file(String name, int bytes, {String dir = ''}) async {
      final folder = Directory('${temp.path}/$dir');
      await folder.create(recursive: true);
      final f = File('${folder.path}/$name');
      await f.writeAsBytes(List.filled(bytes, 1));
      return f.path;
    }

    test('挑回來的檔案：類型不合、太大、重名的擋掉，理由放在 messages', () async {
      moodle.status = Ok(editable());
      await bridge.detail('CS1', 7, false);
      final opened = bridge.openSubmit(7)!;
      expect(opened.pickerHint, contains('最多 2 個檔案'));
      expect(opened.canSave, isFalse);

      final state = await bridge.addFiles(7, [
        await file('a.pdf', 5),
        await file('notes.txt', 5),
        await file('big.pdf', 20),
        await file('a.pdf', 5, dir: 'again'),
      ]);

      expect(state.files.map((f) => f.name), ['a.pdf']);
      expect(state.messages, hasLength(3));
      expect(state.canSave, isTrue);
      expect(bridge.toggleFile(7, 0).files, isEmpty, reason: '剛挑的直接拿掉');
    });

    test('伺服器上的檔案只是標記移除，撤得回來；全部移除要去網頁', () async {
      moodle.status = Ok(editable(state: 'draft', files: [
        MoodleAssignFile(filename: 'old.pdf', fileurl: 'https://x/old.pdf'),
      ]));
      await bridge.detail('CS1', 7, false);
      bridge.openSubmit(7);

      final removing = bridge.toggleFile(7, 0);
      expect(removing.files.single.removing, isTrue);
      expect(removing.canSave, isFalse);
      expect(removing.blockIsError, isTrue);

      final restored = bridge.toggleFile(7, 0);
      expect(restored.files.single.removing, isFalse);
    });

    test('存檔：回報上傳進度，成功就關掉繳交頁並把新狀態帶回詳情', () async {
      moodle.status = Ok(editable());
      await bridge.detail('CS1', 7, false);
      bridge.openSubmit(7);
      await bridge.addFiles(7, [await file('a.pdf', 5)]);
      moodle.write = Ok(MoodleAssignSubmitResult(
          status: editable(state: 'draft'), submitted: false));

      final outcome = await bridge.save(7);

      expect(outcome.close, isTrue);
      expect(outcome.messages, ['草稿已儲存']);
      expect(outcome.detail?.chipLabel, '草稿');
      expect(moodle.savedDraft?.files?.map((f) => f.filename), ['a.pdf']);
      expect(progress.map((p) => p.key).toSet(), {'assign-7'});
      expect(progress.map((p) => p.label), contains('正在上傳 a.pdf'));
    });

    test('沒有草稿階段的作業存檔前要問；有草稿階段的不問', () async {
      memo.assignments['CS1'] = [fileAssignment(drafts: 0)];
      moodle.status = Ok(editable());
      await bridge.detail('CS1', 7, false);
      bridge.openSubmit(7);
      expect(bridge.saveConfirmation(7), startsWith('這份作業沒有草稿階段'));

      memo.assignments['CS1'] = [fileAssignment()];
      await bridge.detail('CS1', 7, true);
      moodle.assignment = Ok(fileAssignment());
      await bridge.detail('CS1', 7, true);
      bridge.openSubmit(7);
      expect(bridge.saveConfirmation(7), isNull);
    });
  });
}
