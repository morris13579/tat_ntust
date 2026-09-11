import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/controller/course_data/course_assignment_controller.dart';
import 'package:flutter_app/src/controller/course_data/course_data_controller.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/store/cache_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/moodle_assign_fixtures.dart';
import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 作業分頁與詳情頁兩個 controller 的狀態流轉。離線、快取預先塞好，不碰網路。
void main() {
  const courseId = 'CS3001701';
  late RecordingUi ui;

  CacheKey<List<MoodleAssignment>> assignKey() =>
      CacheKey<List<MoodleAssignment>>(
        'cache_moodle_assign',
        courseId,
        decode: (json) => (json as List)
            .map((e) =>
                MoodleAssignment.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  CacheKey<MoodleAssignSubmissionStatus> statusKey(int assignId) =>
      CacheKey<MoodleAssignSubmissionStatus>(
        'cache_moodle_assign_status',
        assignId.toString(),
        decode: (json) => MoodleAssignSubmissionStatus.fromJson(
            Map<String, dynamic>.from(json as Map)),
      );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestL10n();
  });

  setUp(() {
    resetAppStatics();
    AuthSession.instance = FakeAuthSession();
    ui = RecordingUi();
    TaskUiDelegate.instance = ui;
    ConnectivityProbe.instance = FakeConnectivityProbe(online: false);
    MoodleRepository.instance = MoodleRepository();
  });

  tearDown(() {
    AuthSession.instance = const UninstalledAuthSession();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
  });

  Future<void> seed({bool withStatus = true}) async {
    await CacheStore.instance.write(assignKey(), fixtureAssignments());
    if (withStatus) {
      await CacheStore.instance
          .write(statusKey(4101), fixtureStatus('status_graded'));
    }
  }

  group('CourseDataController', () {
    test('loadAssignments：清單 Stale，有快取的作業狀態 Stale、沒有的 Failed', () async {
      await seed();
      final controller = CourseDataController(courseId);

      await controller.loadAssignments();

      expect(
          controller.assignments.value, isA<Stale<List<MoodleAssignment>>>());
      expect(controller.assignments.value!.dataOrNull!.map((a) => a.id),
          [4101, 4102]);
      expect(controller.statusOf(4101).value,
          isA<Stale<MoodleAssignSubmissionStatus>>());
      expect(controller.statusOf(4101).value!.dataOrNull!.isGraded, isTrue);
      expect(controller.statusOf(4102).value,
          isA<Failed<MoodleAssignSubmissionStatus>>());
      // 清單本身走一般路徑，Stale 吐一則 toast；兩份作業的狀態是背景抓的，
      // 不彈框也不再各吐一則。
      expect(ui.confirmCalls, 0);
      expect(ui.toasts, hasLength(1));
      controller.dispose();
    });

    test('statusOf 重複呼叫回同一顆 Rxn', () {
      final controller = CourseDataController(courseId);

      expect(identical(controller.statusOf(1), controller.statusOf(1)), isTrue);
      expect(
          identical(controller.statusOf(1), controller.statusOf(2)), isFalse);
      controller.dispose();
    });

    test('清單失敗就不抓狀態', () async {
      final controller = CourseDataController(courseId);

      await controller.loadAssignments();

      expect(
          controller.assignments.value, isA<Failed<List<MoodleAssignment>>>());
      expect(controller.statusOf(4101).value, isNull);
      controller.dispose();
    });

    test('loadAll 也會載入作業', () async {
      await seed();
      final controller = CourseDataController(courseId);

      await controller.loadAll();

      expect(controller.assignments.value, isNotNull);
      expect(controller.assignments.value!.hasData, isTrue);
      controller.dispose();
    });

    test('dispose 會關掉所有 Rxn，包括依需求建立的狀態', () async {
      await seed();
      final controller = CourseDataController(courseId);
      await controller.loadAssignments();
      final status = controller.statusOf(4101);

      controller.dispose();

      expect(controller.assignments.subject.isClosed, isTrue);
      expect(status.subject.isClosed, isTrue);
      // 關掉之後再指派是 no-op，不會拋。
      expect(() => status.value = null, returnsNormally);
    });
  });

  group('CourseAssignmentController', () {
    test('seed 的作業本體直接是 Ok，loadAll 不會重設它', () async {
      final a = fixtureAssignments().first;
      final controller = CourseAssignmentController(
        courseId: courseId,
        assignId: a.id,
        assignment: a,
        status: Ok(fixtureStatus('status_graded')),
      );

      expect(controller.assignment.value, isA<Ok<MoodleAssignment>>());
      await controller.loadAll();

      expect(controller.assignment.value, isA<Ok<MoodleAssignment>>());
      expect(controller.status.value, isA<Ok<MoodleAssignSubmissionStatus>>());
      controller.dispose();
    });

    test('seed 的 Failed 狀態會被丟掉、Stale 會被沿用', () {
      final failed = CourseAssignmentController(
        courseId: courseId,
        assignId: 4101,
        status: const Failed(FetchFailed('x')),
      );
      expect(failed.status.value, isNull);
      failed.dispose();

      final stale = CourseAssignmentController(
        courseId: courseId,
        assignId: 4101,
        status: Stale(fixtureStatus('status_graded'), const Offline()),
      );
      expect(stale.status.value, isA<Stale<MoodleAssignSubmissionStatus>>());
      stale.dispose();
    });

    test('沒有 seed 時 loadAll 兩者都抓（離線從快取回 Stale）', () async {
      await seed();
      final controller =
          CourseAssignmentController(courseId: courseId, assignId: 4101);

      expect(controller.assignment.value, isNull);
      expect(controller.status.value, isNull);
      await controller.loadAll();

      expect(controller.assignment.value, isA<Stale<MoodleAssignment>>());
      expect(controller.assignment.value!.dataOrNull!.cmid, 93001);
      expect(
          controller.status.value, isA<Stale<MoodleAssignSubmissionStatus>>());
      controller.dispose();
    });

    test('清單裡沒有那份作業 → assignment 是 Failed', () async {
      await seed();
      final controller =
          CourseAssignmentController(courseId: courseId, assignId: 9999);

      await controller.loadAll();

      expect(controller.assignment.value, isA<Failed<MoodleAssignment>>());
      controller.dispose();
    });
  });
}
