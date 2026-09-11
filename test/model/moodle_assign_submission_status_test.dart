import 'dart:convert';

import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/moodle_assign_fixtures.dart';

/// `mod_assign_get_submission_status` 回應的解析契約（原始 fromJson，沒有
/// 經過 connector 的 HTML 實體還原——那一層在 moodle_webapi_assign_test）。
///
/// 每一份 fixture 對應學生會遇到的一種情況：從沒開過、草稿、已評分、
/// 評分流程已釋出、只有評語沒有分數、團隊作業（兩種）、有延長期限。
void main() {
  final solo = MoodleAssignment(id: 4101);
  final team = MoodleAssignment(id: 4102, teamsubmission: 1);

  group('status_none：從沒繳交、沒有回饋', () {
    final s = rawFixtureStatus('status_none');

    test('lastattempt 在、submission 與 feedback 缺席', () {
      expect(s.lastattempt, isNotNull);
      expect(s.lastattempt!.submission, isNull);
      expect(s.lastattempt!.teamsubmission, isNull);
      expect(s.feedback, isNull);
      expect(s.submissionFor(solo), isNull);
      expect(s.isGraded, isFalse);
      expect(s.extensionDueDate, 0);
      expect(s.lastattempt!.gradingstatus, 'notgraded');
    });
  });

  group('status_draft：草稿', () {
    final s = rawFixtureStatus('status_draft');

    test('狀態、檔案與線上文字', () {
      final sub = s.submissionFor(solo)!;
      expect(sub.isDraft, isTrue);
      expect(sub.isSubmitted, isFalse);
      expect(sub.timemodified, 1756510000);
      expect(sub.files.single.filename, 'hw1_b10000000.pdf');
      expect(sub.onlineText, '<p>已附上報告</p>');
      expect(s.isGraded, isFalse);
    });
  });

  group('status_graded：已繳交且已評分', () {
    final s = rawFixtureStatus('status_graded');

    test('繳交狀態', () {
      expect(s.submissionFor(solo)!.isSubmitted, isTrue);
      expect(s.submissionFor(solo)!.timemodified, 1756600000);
      expect(s.isGraded, isTrue);
    });

    test('成績：gradefordisplay 是伺服器原文（帶 &nbsp;），模型不還原', () {
      final fb = s.feedback!;
      expect(fb.hasGrade, isTrue);
      // mod/assign/locallib.php display_grade：Real 顯示型態會接
      // '&nbsp;/&nbsp;' . 滿分。還原是 connector 的事。
      expect(fb.gradefordisplay, '85.00&nbsp;/&nbsp;100.00');
      expect(fb.gradeddate, 1756700000);
      expect(fb.grade!.isSet, isTrue);
      expect(fb.grade!.grade, '85.00000');
    });

    test('回饋：評語是 HTML，檔案來自 file 外掛，editpdf 的空 area 不貢獻任何檔案', () {
      final fb = s.feedback!;
      expect(fb.commentsHtml, contains('<strong>不錯</strong>'));
      expect(fb.files.single.filename, 'hw1_marked.pdf');
      expect(fb.plugins.map((p) => p.type), ['comments', 'file', 'editpdf']);
    });
  });

  group('status_workflow_released：評分流程已釋出、量尺成績', () {
    final s = rawFixtureStatus('status_workflow_released');

    test('released 算已評分；gradeddate 是 null 也不會拋', () {
      expect(s.lastattempt!.gradingstatus, 'released');
      expect(s.isGraded, isTrue);
      expect(s.feedback!.gradefordisplay, 'A');
      expect(s.feedback!.gradeddate, isNull);
      expect(s.feedback!.grade!.grade, '2.00000');
    });
  });

  group('status_comments_only：只有評語', () {
    final s = rawFixtureStatus('status_comments_only');

    test('feedback 在、grade 那一列在（-1 = 沒給分），但沒有可顯示的成績', () {
      expect(s.feedback, isNotNull);
      // externallib：沒有 assign_grades 那一列時連 plugins 一起 unset，所以
      // 有評語就一定有 grade，只是分數是 ASSIGN_GRADE_NOT_SET。
      expect(s.feedback!.grade, isNotNull);
      expect(s.feedback!.grade!.isSet, isFalse);
      // gradefordisplay 是 null → ""。
      expect(s.feedback!.gradefordisplay, '');
      expect(s.feedback!.hasGrade, isFalse);
      expect(s.isGraded, isFalse);
      expect(s.feedback!.commentsHtml, '<p>請補交附件</p>');
      expect(s.feedback!.files, isEmpty);
    });
  });

  group('status_team：團隊作業，只有群組那一筆', () {
    final s = rawFixtureStatus('status_team');

    test('團隊作業看 teamsubmission；未建模的群組欄位被忽略', () {
      expect(s.lastattempt!.submission, isNull);
      expect(s.submissionFor(team), isNotNull);
      expect(s.submissionFor(team)!.isSubmitted, isTrue);

      // 群組欄位現在有建模：畫面要靠它們分辨「沒有組」與「跨了多組」。
      expect(s.lastattempt!.usergroups, [12]);
      expect(s.lastattempt!.submissiongroup, 12);
      expect(s.lastattempt!.submissiongroupmemberswhoneedtosubmit, [5253]);
      expect(s.hasSubmissionGroup, isTrue);
      expect(s.groupCount, 1);
      expect(s.pendingGroupMembers, [5253]);
    });

    test('非團隊作業只看自己的那一筆，沒有就是沒有', () {
      // 伺服器只有在 teamsubmission 開著時才會回 teamsubmission，這裡是
      // 防禦：作業設定說不是團隊作業，就不拿群組那一筆充數。
      expect(s.submissionFor(solo), isNull);
    });
  });

  group('status_team_draft：團隊作業，兩筆都在', () {
    final s = rawFixtureStatus('status_team_draft');

    test('隊友代交：自己那筆是 draft、群組那筆 submitted，團隊作業以群組為準', () {
      expect(s.lastattempt!.submission!.isDraft, isTrue);
      expect(s.lastattempt!.teamsubmission!.isSubmitted, isTrue);
      expect(s.submissionFor(team)!.isSubmitted, isTrue,
          reason: 'Moodle renderer：teamsubmissionenabled 時只看 teamsubmission');
      expect(s.submissionFor(solo)!.isDraft, isTrue);
    });
  });

  group('status_extension：延長期限', () {
    test('extensionDueDate 取到 lastattempt.extensionduedate', () {
      expect(rawFixtureStatus('status_extension').extensionDueDate, 1758000000);
    });
  });

  group('MoodleAssignGrade.isSet', () {
    test('-1 是 ASSIGN_GRADE_NOT_SET；0 算有分數；空字串不算', () {
      expect(MoodleAssignGrade(grade: '-1.00000').isSet, isFalse);
      expect(MoodleAssignGrade(grade: '0.00000').isSet, isTrue);
      expect(MoodleAssignGrade(grade: '85.00000').isSet, isTrue);
      expect(MoodleAssignGrade(grade: '').isSet, isFalse);
      expect(MoodleAssignGrade(grade: 'abc').isSet, isFalse);
    });
  });

  group('寬鬆解析與快取形狀', () {
    test('空 map 全部是 null / 空，不會拋', () {
      final s = MoodleAssignSubmissionStatus.fromJson({});
      expect(s.lastattempt, isNull);
      expect(s.feedback, isNull);
      expect(s.submissionFor(solo), isNull);
      expect(s.isGraded, isFalse);
      expect(s.extensionDueDate, 0);
    });

    test('lastattempt 的純量送 null 也退回預設', () {
      final s = MoodleAssignSubmissionStatus.fromJson({
        'lastattempt': {
          'extensionduedate': null,
          'gradingstatus': null,
          'submission': null,
        },
      });
      expect(s.lastattempt!.extensionduedate, 0);
      expect(s.lastattempt!.gradingstatus, '');
      expect(s.lastattempt!.submission, isNull);
    });

    test('status_graded 經 toJson / fromJson 之後關鍵欄位不變', () {
      final s = rawFixtureStatus('status_graded');
      final back = MoodleAssignSubmissionStatus.fromJson(
          jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);

      expect(back.isGraded, isTrue);
      expect(back.submissionFor(solo)!.isSubmitted, isTrue);
      expect(
          back.submissionFor(solo)!.files.single.filename, 'hw1_b10000000.pdf');
      expect(back.submissionFor(solo)!.onlineText, '<p>已附上報告</p>');
      expect(back.feedback!.gradefordisplay, '85.00&nbsp;/&nbsp;100.00');
      expect(back.feedback!.gradeddate, 1756700000);
      expect(back.feedback!.commentsHtml, contains('<strong>不錯</strong>'));
      expect(back.feedback!.files.single.filename, 'hw1_marked.pdf');
    });

    test('升級前存下的 blob 少了新欄位：解析成安全的預設值，不是拋', () {
      // cache_moodle_assign_status 沒有版本號，舊 blob 會原封不動被讀回來。
      // 這幾個欄位缺席時必須是「沒有計時、第一次、沒有組」——也就是
      // 「什麼動作都畫不出來」的那一邊；反過來猜就會在離線時畫出
      // 一顆會打壞伺服器的鈕。詳情頁另外用「兩者都要是 Ok」再擋一層。
      final old = MoodleAssignSubmissionStatus.fromJson({
        'lastattempt': {
          'canedit': true,
          'cansubmit': false,
          'locked': false,
          'graded': false,
          'submissionsenabled': true,
          'gradingstatus': 'notgraded',
          'submission': {
            'timemodified': 1756600000,
            'status': 'draft',
            'plugins': <dynamic>[],
          },
        },
      });

      expect(old.previousattempts, isEmpty);
      expect(old.lastattempt!.usergroups, isEmpty);
      expect(old.lastattempt!.submissiongroup, isNull);
      expect(old.lastattempt!.submissiongroupmemberswhoneedtosubmit, isEmpty);
      expect(old.lastattempt!.caneditowner, isFalse);
      expect(old.lastattempt!.submission!.attemptnumber, 0);
      expect(old.lastattempt!.submission!.timestarted, 0);
      expect(old.hasSubmissionGroup, isFalse);
      expect(old.groupCount, 0);
    });

    test('快取 blob 只有畫面讀的 key：沒有 warnings，也沒有各層的 id / userid', () {
      final s = rawFixtureStatus('status_graded');

      expect(s.toJson().keys, {'lastattempt', 'feedback', 'previousattempts'});
      expect(s.lastattempt!.toJson().keys, {
        'submission',
        'teamsubmission',
        'extensionduedate',
        'gradingstatus',
        'canedit',
        'cansubmit',
        'locked',
        'graded',
        'submissionsenabled',
        'blindmarking',
        'timelimit',
        'usergroups',
        'submissiongroup',
        'submissiongroupmemberswhoneedtosubmit',
        'caneditowner',
      });
      expect(s.lastattempt!.submission!.toJson().keys, {
        'timemodified',
        'status',
        'plugins',
        'attemptnumber',
        'timestarted'
      });
      expect(s.lastattempt!.submission!.plugins.first.toJson().keys,
          {'type', 'fileareas', 'editorfields'});
      expect(s.feedback!.grade!.toJson().keys, {'grade'});
      expect(s.feedback!.plugins.first.editorfields.single.toJson().keys,
          {'name', 'text'});
    });

    test('舊快取 blob 多出來的 key（例如 warnings）照樣解得開', () {
      final s = MoodleAssignSubmissionStatus.fromJson({
        'lastattempt': {
          'submissionsenabled': true,
          'locked': false,
          'gradingstatus': 'graded',
          'submission': {'id': 1, 'userid': 2, 'status': 'submitted'},
        },
        'warnings': <dynamic>[],
      });
      expect(s.isGraded, isTrue);
      expect(s.submissionFor(solo)!.isSubmitted, isTrue);
    });
  });

  /// 這幾個旗標是「能不能交」的唯一依據，`submissions_open()` 已經把 cutoffdate、
  /// 延長期限、鎖定全部算完，所以解析錯了就等於畫錯入口。
  group('繳交閘門旗標', () {
    test('PARAM_BOOL 吃 true / 1 / "1" 三種寫法', () {
      for (final raw in [true, 1, '1']) {
        final s = MoodleAssignSubmissionStatus.fromJson({
          'lastattempt': {
            'canedit': raw,
            'cansubmit': raw,
            'locked': raw,
            'graded': raw,
            'submissionsenabled': raw,
            'blindmarking': raw,
          },
        });
        expect(s.canEdit, isTrue, reason: '$raw');
        expect(s.canSubmit, isTrue, reason: '$raw');
        expect(s.isLocked, isTrue, reason: '$raw');
        expect(s.lastattempt!.graded, isTrue, reason: '$raw');
        expect(s.submissionsEnabled, isTrue, reason: '$raw');
        expect(s.isBlindMarking, isTrue, reason: '$raw');
      }
    });

    test('false / 0 / "0" 與缺席一律是 false', () {
      for (final raw in [false, 0, '0', null]) {
        final s = MoodleAssignSubmissionStatus.fromJson({
          'lastattempt': {'canedit': raw, 'cansubmit': raw},
        });
        expect(s.canEdit, isFalse, reason: '$raw');
        expect(s.canSubmit, isFalse, reason: '$raw');
      }
    });

    test('timelimit 是 VALUE_OPTIONAL，缺席是 0', () {
      expect(
          MoodleAssignSubmissionStatus.fromJson(
              {'lastattempt': <String, dynamic>{}}).timeLimit,
          0);
      expect(
          MoodleAssignSubmissionStatus.fromJson({
            'lastattempt': {'timelimit': 900},
          }).timeLimit,
          900);
    });

    test('lastattempt 缺席（沒有 viewownsubmissionsummary）時全部回 false / 0', () {
      final s = MoodleAssignSubmissionStatus.fromJson({});

      expect(s.lastattempt, isNull);
      expect(s.canEdit, isFalse);
      expect(s.canSubmit, isFalse);
      expect(s.isLocked, isFalse);
      expect(s.submissionsEnabled, isFalse);
      expect(s.isBlindMarking, isFalse);
      expect(s.timeLimit, 0);
    });

    test('fixture：status_can_edit 可編輯但不能送出評分', () {
      final s = rawFixtureStatus('status_can_edit');

      expect(s.canEdit, isTrue);
      expect(s.submissionsEnabled, isTrue);
      expect(s.isLocked, isFalse);
      expect(s.canSubmit, isFalse);
    });

    test('fixture：status_can_submit 有草稿，兩顆鈕都在', () {
      final s = rawFixtureStatus('status_can_submit');

      expect(s.canEdit, isTrue);
      expect(s.canSubmit, isTrue);
    });

    test('fixture：status_locked 被老師鎖住', () {
      final s = rawFixtureStatus('status_locked');

      expect(s.isLocked, isTrue);
      expect(s.canEdit, isFalse);
    });

    test('fixture：status_timed 有作答時限', () {
      expect(rawFixtureStatus('status_timed').timeLimit, greaterThan(0));
    });
  });
}
