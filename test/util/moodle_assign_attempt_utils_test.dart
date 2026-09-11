import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';
import 'package:flutter_app/src/util/moodle_assign_attempt_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/moodle_assign_fixtures.dart';

/// 次數、作答時限、團隊與移除／複製的純函式規格。
///
/// [MoodleAssignAttemptUtils.actionsFor] 的對照組是 Moodle 網頁的
/// `mod/assign/classes/output/user_submission_actionmenu.php`：那一份的規則是
/// 「`canedit` 才畫編輯類的鈕、`new`/`reopened` 沒有東西可以移除、`cansubmit`
/// 是另一條獨立的閘門」。這裡逐條釘住，App 與網頁才只有一套規則。
void main() {
  // 時間一律釘死，這個檔案裡沒有任何函式讀時鐘。
  final now = DateTime(2025, 9, 10, 12);
  int unix(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

  const all = (canRemove: true, canStart: true, canCopy: true);
  const none = (canRemove: false, canStart: false, canCopy: false);

  MoodleAssignment assignment({
    int id = 4102,
    int duedate = 0,
    int cutoffdate = 0,
    int timelimit = 0,
    int teamsubmission = 0,
    int preventsubmissionnotingroup = 0,
    int maxattempts = -1,
  }) =>
      MoodleAssignment(
        id: id,
        name: 'a$id',
        duedate: duedate,
        cutoffdate: cutoffdate,
        timelimit: timelimit,
        teamsubmission: teamsubmission,
        preventsubmissionnotingroup: preventsubmissionnotingroup,
        maxattempts: maxattempts,
      );

  /// 直接組一份狀態。走值而不是 fixture 的原因：動作矩陣要掃過
  /// status × canedit × cansubmit 的組合，一格一個 fixture 不實際。
  MoodleAssignSubmissionStatus status({
    String? submissionStatus,
    bool canEdit = true,
    bool canSubmit = false,
    int timeStarted = 0,
    int timeLimit = 0,
    int attemptNumber = 0,
    bool team = false,
    List<int> userGroups = const [],
    int? submissionGroup,
  }) {
    final sub = submissionStatus == null
        ? null
        : MoodleAssignSubmission(
            status: submissionStatus,
            timestarted: timeStarted,
            attemptnumber: attemptNumber,
          );
    return MoodleAssignSubmissionStatus(
      lastattempt: MoodleAssignLastAttempt(
        submission: team ? null : sub,
        teamsubmission: team ? sub : null,
        canedit: canEdit,
        cansubmit: canSubmit,
        gradingstatus: 'notgraded',
        timelimit: timeLimit,
        usergroups: userGroups,
        submissiongroup: submissionGroup,
      ),
    );
  }

  group('actionsFor：user_submission_actionmenu 的移植', () {
    test('canedit 是 false 時一顆編輯類的鈕都不畫', () {
      final actions = MoodleAssignAttemptUtils.actionsFor(
          assignment(), status(submissionStatus: 'draft', canEdit: false),
          api: all);
      expect(actions, isEmpty);
    });

    test('canedit 是 false 但 cansubmit 是 true：送出評分照畫，那是另一條閘門', () {
      final actions = MoodleAssignAttemptUtils.actionsFor(
        assignment(),
        status(submissionStatus: 'draft', canEdit: false, canSubmit: true),
        api: all,
      );
      expect(actions, {AssignAction.submitForGrading});
    });

    test('new：只有「加入繳交」，沒有移除——網頁也不畫那一項', () {
      final actions = MoodleAssignAttemptUtils.actionsFor(
          assignment(), status(submissionStatus: 'new'),
          api: all);
      expect(actions, {AssignAction.addSubmission});
    });

    test('連 submission 都沒有時等同 new', () {
      final actions = MoodleAssignAttemptUtils.actionsFor(
          assignment(), status(submissionStatus: null),
          api: all);
      expect(actions, {AssignAction.addSubmission});
    });

    test('reopened：加開新的一次，沒有移除', () {
      final actions = MoodleAssignAttemptUtils.actionsFor(
          assignment(), status(submissionStatus: 'reopened', attemptNumber: 1),
          api: all);
      expect(actions, {AssignAction.addNewAttempt, AssignAction.copyPrevious});
      expect(actions, isNot(contains(AssignAction.removeSubmission)));
    });

    test('reopened 且站台沒開放 copy：只剩「開始新的一次」', () {
      final actions = MoodleAssignAttemptUtils.actionsFor(
        assignment(),
        status(submissionStatus: 'reopened', attemptNumber: 1),
        api: (canRemove: true, canStart: true, canCopy: false),
      );
      expect(actions, {AssignAction.addNewAttempt});
    });

    test('draft / submitted：編輯加移除', () {
      for (final s in ['draft', 'submitted']) {
        final actions = MoodleAssignAttemptUtils.actionsFor(
            assignment(), status(submissionStatus: s),
            api: all);
        expect(actions,
            {AssignAction.editSubmission, AssignAction.removeSubmission},
            reason: s);
      }
    });

    test('站台沒開放 remove 時那一項不出現，其餘不變', () {
      final actions = MoodleAssignAttemptUtils.actionsFor(
        assignment(),
        status(submissionStatus: 'submitted'),
        api: none,
      );
      expect(actions, {AssignAction.editSubmission});
    });

    test('new + 有時限 + 還沒開始：多一顆 beginTimed', () {
      final actions = MoodleAssignAttemptUtils.actionsFor(
        assignment(timelimit: 3600),
        status(submissionStatus: 'new', timeLimit: 3600),
        api: all,
      );
      expect(actions, {AssignAction.addSubmission, AssignAction.beginTimed});
    });

    test('有時限但站台沒開放 start_submission：只剩一般的入口', () {
      final actions = MoodleAssignAttemptUtils.actionsFor(
        assignment(timelimit: 3600),
        status(submissionStatus: 'new', timeLimit: 3600),
        api: (canRemove: true, canStart: false, canCopy: true),
      );
      expect(actions, {AssignAction.addSubmission});
    });

    test('時間已經在跑就不再畫 beginTimed', () {
      final actions = MoodleAssignAttemptUtils.actionsFor(
        assignment(timelimit: 3600),
        status(
            submissionStatus: 'new',
            timeLimit: 3600,
            timeStarted: unix(now) - 60),
        api: all,
      );
      expect(actions, {AssignAction.addSubmission});
    });

    test('actionsFor 不需要時鐘：過期與否不改變動作表', () {
      final expired = status(
          submissionStatus: 'draft',
          timeLimit: 60,
          timeStarted: unix(now) - 86400);
      expect(
        MoodleAssignAttemptUtils.actionsFor(assignment(timelimit: 60), expired,
            api: all),
        {AssignAction.editSubmission, AssignAction.removeSubmission},
      );
    });

    test('fixture：reopened 的那一份真的走到 addNewAttempt', () {
      final actions = MoodleAssignAttemptUtils.actionsFor(
          assignment(), fixtureStatus('status_reopened'),
          api: all);
      expect(actions, {AssignAction.addNewAttempt, AssignAction.copyPrevious});
    });
  });

  group('作答時限', () {
    test('沒有時限就是 none', () {
      expect(MoodleAssignAttemptUtils.timerState(assignment(), status(), now),
          AssignTimerState.none);
    });

    test('lastattempt.timelimit 優先於 get_assignments 那一欄（後者沒套 override）', () {
      final a = assignment(timelimit: 3600);
      final s = status(submissionStatus: 'new', timeLimit: 7200);
      expect(MoodleAssignAttemptUtils.effectiveTimeLimit(a, s), 7200);
    });

    test('lastattempt 沒送時才退回清單那一欄', () {
      final a = assignment(timelimit: 3600);
      final s = status(submissionStatus: 'new');
      expect(MoodleAssignAttemptUtils.effectiveTimeLimit(a, s), 3600);
    });

    test('timestarted 是 0 就是還沒開始', () {
      expect(
        MoodleAssignAttemptUtils.timerState(
            assignment(timelimit: 3600), status(timeLimit: 3600), now),
        AssignTimerState.notStarted,
      );
    });

    test('開始了而且還沒到終點是 running，到了是 expired', () {
      final a = assignment(timelimit: 3600);
      final running = status(
          timeLimit: 3600,
          timeStarted: unix(now) - 60,
          submissionStatus: 'draft');
      final over = status(
          timeLimit: 3600,
          timeStarted: unix(now) - 7200,
          submissionStatus: 'draft');
      expect(MoodleAssignAttemptUtils.timerState(a, running, now),
          AssignTimerState.running);
      expect(MoodleAssignAttemptUtils.timerState(a, over, now),
          AssignTimerState.expired);
    });

    test('now 傳 null 時只回答開始了沒有，不判過期', () {
      final over = status(
          timeLimit: 60,
          timeStarted: unix(now) - 86400,
          submissionStatus: 'draft');
      expect(
        MoodleAssignAttemptUtils.timerState(
            assignment(timelimit: 60), over, null),
        AssignTimerState.running,
      );
    });

    test('end_time：沒有 duedate / cutoffdate 就是 timestarted + timelimit', () {
      final started = unix(now);
      expect(
        MoodleAssignAttemptUtils.timerEndUnix(
            assignment(timelimit: 3600),
            status(
                submissionStatus: 'draft',
                timeLimit: 3600,
                timeStarted: started)),
        started + 3600,
      );
    });

    test('end_time：有 duedate 就跟它取小（timelimit_panel::end_time）', () {
      final started = unix(now);
      final due = started + 600;
      expect(
        MoodleAssignAttemptUtils.timerEndUnix(
            assignment(timelimit: 3600, duedate: due),
            status(
                submissionStatus: 'draft',
                timeLimit: 3600,
                timeStarted: started)),
        due,
      );
    });

    test('end_time：duedate 比時限晚時仍然用時限', () {
      final started = unix(now);
      expect(
        MoodleAssignAttemptUtils.timerEndUnix(
            assignment(timelimit: 3600, duedate: started + 99999),
            status(
                submissionStatus: 'draft',
                timeLimit: 3600,
                timeStarted: started)),
        started + 3600,
      );
    });

    test('end_time：沒有 duedate 才輪到 cutoffdate', () {
      final started = unix(now);
      final cutoff = started + 300;
      expect(
        MoodleAssignAttemptUtils.timerEndUnix(
            assignment(timelimit: 3600, cutoffdate: cutoff),
            status(
                submissionStatus: 'draft',
                timeLimit: 3600,
                timeStarted: started)),
        cutoff,
      );
    });

    test('end_time：duedate 在場時 cutoffdate 不參與，即使它更早', () {
      final started = unix(now);
      expect(
        MoodleAssignAttemptUtils.timerEndUnix(
            assignment(
                timelimit: 3600,
                duedate: started + 1800,
                cutoffdate: started + 60),
            status(
                submissionStatus: 'draft',
                timeLimit: 3600,
                timeStarted: started)),
        started + 1800,
      );
    });

    test('剩餘秒數過了終點是 0，不是負的', () {
      final s = status(
          submissionStatus: 'draft',
          timeLimit: 60,
          timeStarted: unix(now) - 86400);
      expect(
          MoodleAssignAttemptUtils.timeLeftSeconds(
              assignment(timelimit: 60), s, now),
          0);
    });

    test('formatDuration：超過一小時帶時，否則 MM:SS', () {
      expect(MoodleAssignAttemptUtils.formatDuration(59), '00:59');
      expect(MoodleAssignAttemptUtils.formatDuration(600), '10:00');
      expect(MoodleAssignAttemptUtils.formatDuration(3661), '1:01:01');
      expect(MoodleAssignAttemptUtils.formatDuration(-5), '00:00');
    });

    test('fixture：按過開始的那一份是 running', () {
      final s = fixtureStatus('status_timed_started');
      final a = assignment(timelimit: 3600);
      // fixture 的 timestarted 是 2025 年的固定值，用它自己的起點推現在。
      final justAfter =
          DateTime.fromMillisecondsSinceEpoch((s.timeStarted(a) + 60) * 1000);
      expect(MoodleAssignAttemptUtils.timerState(a, s, justAfter),
          AssignTimerState.running);
    });
  });

  group('attemptLabel', () {
    test('attemptnumber 是 0 起算，畫面要 1 起算', () {
      expect(
          MoodleAssignAttemptUtils.attemptLabel(
              assignment(), status(submissionStatus: 'draft')),
          (current: 1, total: -1));
    });

    test('maxattempts == -1 是不限次數', () {
      final label = MoodleAssignAttemptUtils.attemptLabel(
          assignment(maxattempts: -1),
          status(submissionStatus: 'reopened', attemptNumber: 2));
      expect(label.current, 3);
      expect(label.total, -1);
    });

    test('有上限時兩個數字都在', () {
      expect(
        MoodleAssignAttemptUtils.attemptLabel(assignment(maxattempts: 3),
            status(submissionStatus: 'reopened', attemptNumber: 1)),
        (current: 2, total: 3),
      );
    });

    test('團隊作業讀的是群組那一筆的 attemptnumber', () {
      final s = status(submissionStatus: 'draft', attemptNumber: 2, team: true);
      expect(
          MoodleAssignAttemptUtils.attemptLabel(
              assignment(teamsubmission: 1), s),
          (current: 3, total: -1));
    });
  });

  group('teamState', () {
    test('不是團隊作業就是 notTeam，即使沒有組別資訊', () {
      expect(MoodleAssignAttemptUtils.teamState(assignment(), status()),
          AssignTeamState.notTeam);
    });

    test('伺服器算得出組別就是 ok', () {
      expect(
        MoodleAssignAttemptUtils.teamState(assignment(teamsubmission: 1),
            fixtureStatus('status_team_all_must_submit')),
        AssignTeamState.ok,
      );
    });

    test('usergroups 是空的：還沒被分到組', () {
      expect(
        MoodleAssignAttemptUtils.teamState(
            assignment(teamsubmission: 1, preventsubmissionnotingroup: 1),
            fixtureStatus('status_team_prevent_no_group')),
        AssignTeamState.noGroup,
      );
    });

    test('usergroups 有兩組：伺服器算不出要交給誰', () {
      expect(
        MoodleAssignAttemptUtils.teamState(
            assignment(teamsubmission: 1, preventsubmissionnotingroup: 1),
            fixtureStatus('status_team_multiple_groups')),
        AssignTeamState.multipleGroups,
      );
    });

    test('preventsubmissionnotingroup 關著（Moodle 的預設）時兩種都是 ok', () {
      for (final f in [
        'status_team_prevent_no_group',
        'status_team_multiple_groups'
      ]) {
        expect(
          MoodleAssignAttemptUtils.teamState(
              assignment(teamsubmission: 1), fixtureStatus(f)),
          AssignTeamState.ok,
        );
      }
    });

    test('pendingGroupMembers 只有 id，而且只在要求全員送出時非空', () {
      expect(fixtureStatus('status_team_all_must_submit').pendingGroupMembers,
          [5253, 5254]);
      expect(fixtureStatus('status_team_prevent_no_group').pendingGroupMembers,
          isEmpty);
    });
  });

  group('removeConsequences', () {
    test('個人的草稿：不牽連別人、不是取消繳交、沒有時限', () {
      final c = MoodleAssignAttemptUtils.removeConsequences(
          assignment(), status(submissionStatus: 'draft'));
      expect(c, (wipesTeam: false, unsubmits: false, keepsTimer: false));
    });

    test('已經繳交的那一次：移除等於退回去重交', () {
      final c = MoodleAssignAttemptUtils.removeConsequences(
          assignment(), status(submissionStatus: 'submitted'));
      expect(c.unsubmits, isTrue);
    });

    test('團隊作業：動的是整組那一筆，每位組員都被寫回', () {
      final c = MoodleAssignAttemptUtils.removeConsequences(
        assignment(teamsubmission: 1),
        status(submissionStatus: 'submitted', team: true),
      );
      expect(c.wipesTeam, isTrue);
      expect(c.unsubmits, isTrue);
    });

    test('計時中：timestarted 不會被清掉，確認框要說', () {
      final c = MoodleAssignAttemptUtils.removeConsequences(
        assignment(timelimit: 3600),
        status(
            submissionStatus: 'draft',
            timeLimit: 3600,
            timeStarted: unix(now) - 60),
      );
      expect(c.keepsTimer, isTrue);
    });

    test('有時限但還沒開始：沒有時限可以被保留', () {
      final c = MoodleAssignAttemptUtils.removeConsequences(
        assignment(timelimit: 3600),
        status(submissionStatus: 'draft', timeLimit: 3600),
      );
      expect(c.keepsTimer, isFalse);
    });
  });

  group('previousattempts', () {
    test('伺服器已經去掉當前那一次，這裡只有舊的', () {
      final s = fixtureStatus('status_reopened');
      expect(s.previousattempts, hasLength(1));
      expect(s.previousattempts.single.attemptnumber, 0);
      expect(s.previousattempts.single.submission?.isSubmitted, isTrue);
    });

    test('gradefordisplay 走過 submissionStatusOf 就是純文字，不是 HTML 實體', () {
      final grade =
          fixtureStatus('status_reopened').previousattempts.single.grade!;
      expect(grade.gradefordisplay, isNot(contains('&nbsp;')));
      expect(grade.gradefordisplay, contains('52.00'));
      expect(grade.isSet, isTrue);
      expect(grade.hasDisplay, isTrue);
    });

    test('沒有這個欄位的舊回應解析成空陣列而不是拋', () {
      expect(fixtureStatus('status_draft').previousattempts, isEmpty);
    });
  });
}
