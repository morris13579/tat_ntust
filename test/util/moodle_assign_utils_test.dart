import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';
import 'package:flutter_app/src/util/moodle_assign_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/moodle_assign_fixtures.dart';

/// 狀態籤、截止提示與排序的純函式規格。時間一律釘在 2025-09-10 12:00（本地）。
void main() {
  final now = DateTime(2025, 9, 10, 12);
  int unix(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;
  final past = unix(now.subtract(const Duration(days: 1)));
  final future = unix(now.add(const Duration(days: 1)));

  MoodleAssignment assignment({
    int duedate = 0,
    int cutoffdate = 0,
    int id = 1,
    int teamsubmission = 0,
    int nosubmissions = 0,
  }) =>
      MoodleAssignment(
        id: id,
        name: 'a$id',
        duedate: duedate,
        cutoffdate: cutoffdate,
        teamsubmission: teamsubmission,
        nosubmissions: nosubmissions,
      );

  MoodleAssignSubmissionStatus withStatus(String status) =>
      MoodleAssignSubmissionStatus(
        lastattempt: MoodleAssignLastAttempt(
          submission: MoodleAssignSubmission(status: status),
          gradingstatus: 'notgraded',
        ),
      );

  AssignDisplayStatus resolve(
          MoodleAssignment a, MoodleAssignSubmissionStatus s) =>
      MoodleAssignUtils.resolveStatus(a, s, now: now);

  group('resolveStatus', () {
    test('已評分 > 一切：graded 與 released 都是 graded', () {
      expect(resolve(assignment(duedate: past), fixtureStatus('status_graded')),
          AssignDisplayStatus.graded);
      expect(
          resolve(assignment(duedate: past),
              fixtureStatus('status_workflow_released')),
          AssignDisplayStatus.graded);
    });

    test('已繳交但未評分（只有評語）→ submitted，過了截止也一樣', () {
      expect(
          resolve(
              assignment(duedate: past), fixtureStatus('status_comments_only')),
          AssignDisplayStatus.submitted);
    });

    test('草稿：截止前是 draft，過了截止是 overdue', () {
      expect(
          resolve(assignment(duedate: future), fixtureStatus('status_draft')),
          AssignDisplayStatus.draft);
      expect(resolve(assignment(duedate: past), fixtureStatus('status_draft')),
          AssignDisplayStatus.overdue);
    });

    test('沒繳交：截止前 notSubmitted，過了截止 overdue', () {
      expect(resolve(assignment(duedate: future), fixtureStatus('status_none')),
          AssignDisplayStatus.notSubmitted);
      expect(resolve(assignment(duedate: past), fixtureStatus('status_none')),
          AssignDisplayStatus.overdue);
    });

    test('沒有截止日期就永遠不會逾期，cutoffdate 不算', () {
      expect(
          resolve(assignment(duedate: 0, cutoffdate: past),
              fixtureStatus('status_none')),
          AssignDisplayStatus.notSubmitted);
    });

    test('延長期限在未來時，duedate 已過也不算逾期', () {
      // status_extension 的 extensionduedate 是 2025-09-16。
      expect(
          resolve(assignment(duedate: past), fixtureStatus('status_extension')),
          AssignDisplayStatus.notSubmitted);
    });

    test('團隊作業由隊友繳交 → submitted', () {
      expect(
          resolve(assignment(duedate: future, teamsubmission: 1),
              fixtureStatus('status_team')),
          AssignDisplayStatus.submitted);
    });

    test('團隊作業兩筆都在：以群組那筆為準，自己那筆的 draft 不算', () {
      // 隊友按了繳交：群組那筆 submitted，自己那筆還停在 draft。Moodle 學生頁
      // 顯示已繳交，這裡也要。過了截止也一樣是 submitted，不是 overdue。
      final s = fixtureStatus('status_team_draft');
      expect(resolve(assignment(duedate: future, teamsubmission: 1), s),
          AssignDisplayStatus.submitted);
      expect(resolve(assignment(duedate: past, teamsubmission: 1), s),
          AssignDisplayStatus.submitted);
      // 同一份回應、非團隊作業設定 → 看自己那筆 → draft。
      expect(
          resolve(assignment(duedate: future), s), AssignDisplayStatus.draft);
    });

    test('離線評分（nosubmissions）沒有東西可以交：截止前後都是不需繳交，評了就是已評分', () {
      expect(
          resolve(assignment(duedate: past, nosubmissions: 1),
              fixtureStatus('status_none')),
          AssignDisplayStatus.noSubmissionRequired);
      expect(
          resolve(assignment(duedate: future, nosubmissions: 1),
              fixtureStatus('status_none')),
          AssignDisplayStatus.noSubmissionRequired);
      expect(
          resolve(assignment(duedate: past, nosubmissions: 1),
              fixtureStatus('status_graded')),
          AssignDisplayStatus.graded);
    });

    test('new 是 notSubmitted，reopened 有自己的一顆籤', () {
      expect(resolve(assignment(duedate: future), withStatus('new')),
          AssignDisplayStatus.notSubmitted);
      expect(resolve(assignment(duedate: future), withStatus('reopened')),
          AssignDisplayStatus.reopened);
    });

    test('reopened 過了截止照樣算逾期，跟草稿同一條規則', () {
      expect(resolve(assignment(duedate: past), withStatus('reopened')),
          AssignDisplayStatus.overdue);
    });
  });

  group('effectiveDueDate / isOverdue', () {
    test('有延長期限就用延長期限，否則 duedate', () {
      final a = assignment(duedate: past);
      expect(
          MoodleAssignUtils.effectiveDueDate(
              a, fixtureStatus('status_extension')),
          1758000000);
      expect(
          MoodleAssignUtils.effectiveDueDate(a, fixtureStatus('status_none')),
          past);
      expect(MoodleAssignUtils.effectiveDueDate(a, null), past);
    });

    test('剛好等於截止時間算逾期', () {
      expect(
          MoodleAssignUtils.isOverdue(
              assignment(duedate: unix(now)), null, now),
          isTrue);
      expect(
          MoodleAssignUtils.isOverdue(
              assignment(duedate: unix(now) + 1), null, now),
          isFalse);
      expect(MoodleAssignUtils.isOverdue(assignment(duedate: 0), null, now),
          isFalse);
    });
  });

  group('dueHint', () {
    DueHint hint(int due) => MoodleAssignUtils.dueHint(due, now);

    test('0 是沒有截止日期', () {
      expect(hint(0), (kind: DueHintKind.noDueDate, count: 0));
    });

    test('未來：天、小時、一小時內', () {
      expect(hint(unix(now.add(const Duration(days: 3, hours: 2)))),
          (kind: DueHintKind.dueInDays, count: 3));
      expect(hint(unix(now.add(const Duration(hours: 5)))),
          (kind: DueHintKind.dueInHours, count: 5));
      expect(hint(unix(now.add(const Duration(minutes: 30)))),
          (kind: DueHintKind.dueSoon, count: 0));
    });

    test('過去：天、小時、剛過', () {
      expect(hint(unix(now.subtract(const Duration(days: 2)))),
          (kind: DueHintKind.overdueDays, count: 2));
      expect(hint(unix(now.subtract(const Duration(hours: 3)))),
          (kind: DueHintKind.overdueHours, count: 3));
      expect(hint(unix(now.subtract(const Duration(minutes: 10)))),
          (kind: DueHintKind.overdueJustNow, count: 0));
    });

    test('剛好等於 now：diff 不是負的，落在 dueSoon', () {
      expect(hint(unix(now)), (kind: DueHintKind.dueSoon, count: 0));
    });
  });

  group('sortForList', () {
    test('未截止依 duedate 升冪、沒有截止排最後，已截止依 duedate 降冪', () {
      final a = assignment(
          id: 1, duedate: unix(now.subtract(const Duration(days: 1))));
      final b =
          assignment(id: 2, duedate: unix(now.add(const Duration(days: 1))));
      final c = assignment(id: 3, duedate: 0);
      final d = assignment(
          id: 4, duedate: unix(now.subtract(const Duration(days: 5))));
      final e =
          assignment(id: 5, duedate: unix(now.add(const Duration(days: 3))));
      final input = [a, b, c, d, e];

      final sorted = MoodleAssignUtils.sortForList(input, now);

      expect(sorted.map((x) => x.id), [2, 5, 3, 1, 4]);
      expect(input.map((x) => x.id), [1, 2, 3, 4, 5], reason: '不可以改動輸入');
    });

    test('同鍵維持原順序', () {
      final x = assignment(id: 1, duedate: 0);
      final y = assignment(id: 2, duedate: 0);
      final z = assignment(id: 3, duedate: future);
      final w = assignment(id: 4, duedate: future);

      expect(MoodleAssignUtils.sortForList([x, y, z, w], now).map((a) => a.id),
          [3, 4, 1, 2]);
      expect(MoodleAssignUtils.sortForList([y, x, w, z], now).map((a) => a.id),
          [4, 3, 2, 1]);
    });

    test('空清單', () {
      expect(MoodleAssignUtils.sortForList([], now), isEmpty);
    });

    test('dueOf：有延長期限的作業依延長期限排，留在未截止那一半', () {
      final ext = unix(now.add(const Duration(days: 6)));
      final a = assignment(id: 1, duedate: past); // 延長到 6 天後
      final b = assignment(id: 2, duedate: future); // 明天
      final c = assignment(id: 3, duedate: past); // 真的過了
      int dueOf(MoodleAssignment x) => x.id == 1 ? ext : x.duedate;

      expect(
          MoodleAssignUtils.sortForList([a, b, c], now, dueOf: dueOf)
              .map((x) => x.id),
          [2, 1, 3]);
      // 沒給 dueOf 時照 duedate：a 與 c 都算已截止。
      expect(MoodleAssignUtils.sortForList([a, b, c], now).map((x) => x.id),
          [2, 1, 3]);
      expect(MoodleAssignUtils.sortForList([c, b, a], now).map((x) => x.id),
          [2, 3, 1],
          reason: 'a、c 同 duedate，維持原順序');
    });
  });

  group('findById', () {
    test('命中與沒命中', () {
      final list = fixtureAssignments();
      expect(MoodleAssignUtils.findById(list, 4102)!.name, '期末專題');
      expect(MoodleAssignUtils.findById(list, 9999), isNull);
      expect(MoodleAssignUtils.findById([], 4101), isNull);
    });
  });
}
