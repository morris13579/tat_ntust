import 'dart:convert';

import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:json_annotation/json_annotation.dart';

part 'moodle_mod_assign_get_submission_status.g.dart';

/// `mod_assign_get_submission_status` 的回應。只宣告有人讀的欄位——宣告出來的
/// 都會進 `cache_moodle_assign_status` 那包 blob。`plugins[]` 一律以 `type`
/// 分辨，不要看 `name`：那是隨介面語言變的本地化顯示名。
@JsonSerializable(explicitToJson: true)
class MoodleAssignSubmissionStatus {
  /// 缺席代表還沒繳交，是正常回應。
  @JsonKey(name: 'lastattempt')
  MoodleAssignLastAttempt? lastattempt;

  /// 缺席 = 學生目前看不到任何成績或回饋（隱藏、未釋出、或還沒評）。
  @JsonKey(name: 'feedback')
  MoodleAssignFeedback? feedback;

  /// 這一次以外的歷次繳交，伺服器已經 `array_pop` 掉當前那一次並反轉成新的在前。
  @JsonKey(name: 'previousattempts', defaultValue: [])
  List<MoodleAssignPreviousAttempt> previousattempts;

  MoodleAssignSubmissionStatus({
    this.lastattempt,
    this.feedback,
    List<MoodleAssignPreviousAttempt>? previousattempts,
  }) : previousattempts = previousattempts ?? <MoodleAssignPreviousAttempt>[];

  /// 沒有評分流程時 `get_grading_status` 回 graded / notgraded；
  /// 有評分流程時回流程狀態，released 才代表學生看得到。
  static const String gradingStatusGraded = 'graded';
  static const String gradingStatusReleased = 'released';

  /// 團隊作業看 `teamsubmission`，否則看自己的 `submission`。順序不能反過來：
  /// 伺服器兩筆都回，哪一筆算數要看作業設定，不能用 null 合併。
  MoodleAssignSubmission? submissionFor(MoodleAssignment a) =>
      a.isTeamSubmission
          ? (lastattempt?.teamsubmission ?? lastattempt?.submission)
          : lastattempt?.submission;

  /// 以 `gradingstatus` 為準（成績被藏起來時它照樣是 graded），
  /// 再退回 feedback 有沒有可見成績。
  bool get isGraded {
    final gs = lastattempt?.gradingstatus;
    if (gs == gradingStatusGraded || gs == gradingStatusReleased) return true;
    return feedback?.hasGrade ?? false;
  }

  /// 延長期限（Unix 秒），0 = 沒有延長。
  int get extensionDueDate => lastattempt?.extensionduedate ?? 0;

  /// 「新增／編輯繳交」那顆鈕該不該出現。伺服器已經把 cutoffdate、
  /// allowsubmissionsfromdate、延長期限、鎖定與是否選課全部算完，
  /// App 不可以自己再用日期推一次。
  bool get canEdit => lastattempt?.canedit ?? false;

  /// 「送出評分」那顆鈕該不該出現。沒開草稿的作業永遠是 false
  /// （`show_submit_button` 最後一行就是 `return submissiondrafts`）。
  bool get canSubmit => lastattempt?.cansubmit ?? false;

  /// 老師鎖了這位學生。
  bool get isLocked => lastattempt?.locked ?? false;

  bool get submissionsEnabled => lastattempt?.submissionsenabled ?? false;

  /// 秒；> 0 要走 `mod_assign_start_submission`。
  int get timeLimit => lastattempt?.timelimit ?? 0;

  bool get isBlindMarking => lastattempt?.blindmarking ?? false;

  /// 目前這一次是第幾次（0 起算）。團隊作業看群組那一筆，見 [submissionFor]。
  int attemptNumber(MoodleAssignment a) => submissionFor(a)?.attemptnumber ?? 0;

  /// 這一次開始作答的 Unix 秒；0 = 還沒按過「開始作答」。
  int timeStarted(MoodleAssignment a) => submissionFor(a)?.timestarted ?? 0;

  /// 伺服器算得出這位學生要交給哪一組。`get_submission_group()` 在
  /// 「不只一組」或「沒有組」時回 false，那時這個欄位整個缺席。
  bool get hasSubmissionGroup => (lastattempt?.submissiongroup ?? 0) > 0;

  /// 這位學生在 `teamsubmissiongroupingid` 底下的組數。0 = 沒有組，
  /// >= 2 = 跨了多組；兩種都是老師才修得好的設定，不是 App 的錯。
  int get groupCount => lastattempt?.usergroups.length ?? 0;

  /// 還沒送出的組員 id。只有 `requireallteammemberssubmit == 1` 時非空
  /// （伺服器端其餘情況直接回空陣列）。只有 id，沒有名字。
  List<int> get pendingGroupMembers =>
      lastattempt?.submissiongroupmemberswhoneedtosubmit ?? const [];

  factory MoodleAssignSubmissionStatus.fromJson(Map<String, dynamic> json) =>
      _$MoodleAssignSubmissionStatusFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleAssignSubmissionStatusToJson(this);

  @override
  String toString() => jsonEncode(this);
}

/// PARAM_BOOL 正常是 JSON bool；容忍 1/0 與 "1"/"0"，同
/// moodle_core_calendar_action_events.dart 的慣例。
bool _boolFromJson(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == '1' || v.toLowerCase() == 'true';
  return false;
}

@JsonSerializable(explicitToJson: true)
class MoodleAssignLastAttempt {
  /// 自己的那一筆。缺席 = 還沒有任何繳交紀錄（連 `new` 那一筆都沒有）。
  @JsonKey(name: 'submission')
  MoodleAssignSubmission? submission;

  /// 群組那一筆，只有團隊作業才有；見 [MoodleAssignSubmissionStatus.submissionFor]。
  @JsonKey(name: 'teamsubmission')
  MoodleAssignSubmission? teamsubmission;

  /// Unix 秒，0 = 沒有延長。整列 user flags 不存在時伺服器會送 null。
  @JsonKey(name: 'extensionduedate', defaultValue: 0)
  int extensionduedate;

  /// graded / notgraded，或評分流程的 notmarked / inmarking / readyforreview /
  /// inreview / readyforrelease / released。
  @JsonKey(name: 'gradingstatus', defaultValue: "")
  String gradingstatus;

  @JsonKey(name: 'canedit', fromJson: _boolFromJson, defaultValue: false)
  bool canedit;

  @JsonKey(name: 'cansubmit', fromJson: _boolFromJson, defaultValue: false)
  bool cansubmit;

  @JsonKey(name: 'locked', fromJson: _boolFromJson, defaultValue: false)
  bool locked;

  @JsonKey(name: 'graded', fromJson: _boolFromJson, defaultValue: false)
  bool graded;

  /// 站台／作業把 file 與 onlinetext 都關掉時是 false。
  @JsonKey(
      name: 'submissionsenabled', fromJson: _boolFromJson, defaultValue: false)
  bool submissionsenabled;

  @JsonKey(name: 'blindmarking', fromJson: _boolFromJson, defaultValue: false)
  bool blindmarking;

  /// VALUE_OPTIONAL，缺席是 0。**這一欄才是套過 override 的作答時限**；
  /// `get_assignments` 的同名欄位是原始欄位值，見那邊的註解。
  @JsonKey(name: 'timelimit', defaultValue: 0)
  int timelimit;

  /// 這位學生在 `teamsubmissiongroupingid` 底下的全部組別；伺服器一定會送。
  /// 空的 = 沒有組，超過一個 = 跨組，兩種伺服器都算不出要交給誰。
  @JsonKey(name: 'usergroups', defaultValue: [])
  List<int> usergroups;

  /// VALUE_OPTIONAL：`get_submission_group()` 回 false 時整個欄位缺席，
  /// 所以 null 是有意義的（不是 0），不要給 defaultValue。
  @JsonKey(name: 'submissiongroup')
  int? submissiongroup;

  /// 還沒送出的組員 id；`requireallteammemberssubmit == 0` 時伺服器回空陣列。
  @JsonKey(name: 'submissiongroupmemberswhoneedtosubmit', defaultValue: [])
  List<int> submissiongroupmemberswhoneedtosubmit;

  /// 「這一筆繳交的擁有者可不可以編輯」；團隊作業時問的是整組那一筆。
  @JsonKey(name: 'caneditowner', fromJson: _boolFromJson, defaultValue: false)
  bool caneditowner;

  MoodleAssignLastAttempt({
    this.submission,
    this.teamsubmission,
    this.extensionduedate = 0,
    this.gradingstatus = "",
    this.canedit = false,
    this.cansubmit = false,
    this.locked = false,
    this.graded = false,
    this.submissionsenabled = false,
    this.blindmarking = false,
    this.timelimit = 0,
    List<int>? usergroups,
    this.submissiongroup,
    List<int>? submissiongroupmemberswhoneedtosubmit,
    this.caneditowner = false,
  })  : usergroups = usergroups ?? <int>[],
        submissiongroupmemberswhoneedtosubmit =
            submissiongroupmemberswhoneedtosubmit ?? <int>[];

  factory MoodleAssignLastAttempt.fromJson(Map<String, dynamic> json) =>
      _$MoodleAssignLastAttemptFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleAssignLastAttemptToJson(this);

  @override
  String toString() => jsonEncode(this);
}

@JsonSerializable(explicitToJson: true)
class MoodleAssignSubmission {
  /// Unix 秒。submitted 時等於繳交時間；draft 時只是最後一次存草稿。
  @JsonKey(name: 'timemodified', defaultValue: 0)
  int timemodified;

  /// new / reopened / draft / submitted；new 與 reopened 都不算繳交。
  @JsonKey(name: 'status', defaultValue: "")
  String status;

  @JsonKey(name: 'plugins', defaultValue: [])
  List<MoodleAssignPlugin> plugins;

  /// 第幾次，0 起算。老師重開一次（`add_attempt`）就加一，移除繳交**不會**減。
  @JsonKey(name: 'attemptnumber', defaultValue: 0)
  int attemptnumber;

  /// VALUE_OPTIONAL：按過 `mod_assign_start_submission` 才有，缺席是 0。
  @JsonKey(name: 'timestarted', defaultValue: 0)
  int timestarted;

  MoodleAssignSubmission({
    this.timemodified = 0,
    this.status = "",
    List<MoodleAssignPlugin>? plugins,
    this.attemptnumber = 0,
    this.timestarted = 0,
  }) : plugins = plugins ?? <MoodleAssignPlugin>[];

  static const String statusNew = 'new';
  static const String statusReopened = 'reopened';
  static const String statusDraft = 'draft';
  static const String statusSubmitted = 'submitted';

  bool get isSubmitted => status == statusSubmitted;

  bool get isDraft => status == statusDraft;

  /// 老師重開了一次而學生還沒動它：內容是空的，`previousattempts` 才有東西。
  bool get isReopened => status == statusReopened;

  /// 連一筆真的繳交都還沒有；`remove_submission` 之後第一次也會回到這裡。
  bool get isNew => status == statusNew;

  /// 繳交的檔案（file 外掛）。
  List<MoodleAssignFile> get files => [
        for (final p in plugins)
          if (p.type == 'file') ...p.allFiles
      ];

  /// 線上文字裡內嵌的那幾個檔案。onlinetext 外掛只有
  /// `submissions_onlinetext` 一個 filearea，所以整包攤平不會混到別人的。
  List<MoodleAssignFile> get onlineTextFiles => [
        for (final p in plugins)
          if (p.type == 'onlinetext') ...p.allFiles
      ];

  /// 線上文字（onlinetext 外掛），HTML；沒有就空字串。
  String get onlineText {
    for (final p in plugins) {
      if (p.type == 'onlinetext') return p.editorText('onlinetext');
    }
    return "";
  }

  factory MoodleAssignSubmission.fromJson(Map<String, dynamic> json) =>
      _$MoodleAssignSubmissionFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleAssignSubmissionToJson(this);

  @override
  String toString() => jsonEncode(this);
}

/// `previousattempts[]` 的一筆。伺服器已經把目前這一次 `array_pop` 掉，
/// 並反轉成新的在前，所以這裡永遠不含當前那一次。
@JsonSerializable(explicitToJson: true)
class MoodleAssignPreviousAttempt {
  @JsonKey(name: 'attemptnumber', defaultValue: 0)
  int attemptnumber;

  /// 那一次的繳交內容；理論上一定在，仍當成可缺席。
  @JsonKey(name: 'submission')
  MoodleAssignSubmission? submission;

  /// 那一次的成績；還沒評過就缺席。
  @JsonKey(name: 'grade')
  MoodleAssignPreviousGrade? grade;

  MoodleAssignPreviousAttempt({
    this.attemptnumber = 0,
    this.submission,
    this.grade,
  });

  factory MoodleAssignPreviousAttempt.fromJson(Map<String, dynamic> json) =>
      _$MoodleAssignPreviousAttemptFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleAssignPreviousAttemptToJson(this);

  @override
  String toString() => jsonEncode(this);
}

/// 一次舊繳交的成績。跟 [MoodleAssignGrade] 分開是因為它多一個
/// `gradefordisplay`，而那一欄是 PARAM_RAW 的 HTML 片段，
/// connector 的 `submissionStatusOf` 會先 [HtmlUtils.clean] 過。
@JsonSerializable(explicitToJson: true)
class MoodleAssignPreviousGrade {
  /// 形如 "85.00000"；"-1.00000" 是 ASSIGN_GRADE_NOT_SET。
  @JsonKey(name: 'grade', defaultValue: "")
  String grade;

  /// 伺服器回的是 HTML 片段，connector 已還原成純文字，這裡只進 Text。
  @JsonKey(name: 'gradefordisplay', defaultValue: "")
  String gradefordisplay;

  MoodleAssignPreviousGrade({
    this.grade = "",
    this.gradefordisplay = "",
  });

  bool get isSet => (double.tryParse(grade) ?? -1) >= 0;

  bool get hasDisplay => gradefordisplay.trim().isNotEmpty;

  factory MoodleAssignPreviousGrade.fromJson(Map<String, dynamic> json) =>
      _$MoodleAssignPreviousGradeFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleAssignPreviousGradeToJson(this);

  @override
  String toString() => jsonEncode(this);
}

@JsonSerializable(explicitToJson: true)
class MoodleAssignPlugin {
  /// file / onlinetext / comments / editpdf ……只能用這個欄位分辨。
  @JsonKey(name: 'type', defaultValue: "")
  String type;

  @JsonKey(name: 'fileareas', defaultValue: [])
  List<MoodleAssignFileArea> fileareas;

  @JsonKey(name: 'editorfields', defaultValue: [])
  List<MoodleAssignEditorField> editorfields;

  MoodleAssignPlugin({
    this.type = "",
    List<MoodleAssignFileArea>? fileareas,
    List<MoodleAssignEditorField>? editorfields,
  })  : fileareas = fileareas ?? <MoodleAssignFileArea>[],
        editorfields = editorfields ?? <MoodleAssignEditorField>[];

  List<MoodleAssignFile> get allFiles =>
      [for (final a in fileareas) ...a.files];

  /// 名為 [fieldName] 的編輯欄位文字，沒有就空字串。
  String editorText(String fieldName) {
    for (final f in editorfields) {
      if (f.name == fieldName) return f.text;
    }
    return "";
  }

  factory MoodleAssignPlugin.fromJson(Map<String, dynamic> json) =>
      _$MoodleAssignPluginFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleAssignPluginToJson(this);

  @override
  String toString() => jsonEncode(this);
}

/// 一個 file area；`area` 名稱不宣告，UI 把同外掛底下的 area 全部攤平。
@JsonSerializable(explicitToJson: true)
class MoodleAssignFileArea {
  @JsonKey(name: 'files', defaultValue: [])
  List<MoodleAssignFile> files;

  MoodleAssignFileArea({
    List<MoodleAssignFile>? files,
  }) : files = files ?? <MoodleAssignFile>[];

  factory MoodleAssignFileArea.fromJson(Map<String, dynamic> json) =>
      _$MoodleAssignFileAreaFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleAssignFileAreaToJson(this);

  @override
  String toString() => jsonEncode(this);
}

@JsonSerializable(explicitToJson: true)
class MoodleAssignEditorField {
  @JsonKey(name: 'name', defaultValue: "")
  String name;

  /// HTML（`moodlewssettingfilter=true` 時伺服器已 format_text）。
  @JsonKey(name: 'text', defaultValue: "")
  String text;

  MoodleAssignEditorField({
    this.name = "",
    this.text = "",
  });

  factory MoodleAssignEditorField.fromJson(Map<String, dynamic> json) =>
      _$MoodleAssignEditorFieldFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleAssignEditorFieldToJson(this);

  @override
  String toString() => jsonEncode(this);
}

@JsonSerializable(explicitToJson: true)
class MoodleAssignGrade {
  /// 形如 "85.00000"；"-1.00000" 是 ASSIGN_GRADE_NOT_SET（只給評語沒給分數）。
  @JsonKey(name: 'grade', defaultValue: "")
  String grade;

  MoodleAssignGrade({
    this.grade = "",
  });

  bool get isSet => (double.tryParse(grade) ?? -1) >= 0;

  factory MoodleAssignGrade.fromJson(Map<String, dynamic> json) =>
      _$MoodleAssignGradeFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleAssignGradeToJson(this);

  @override
  String toString() => jsonEncode(this);
}

/// `feedback`：學生看得到的成績與回饋。
@JsonSerializable(explicitToJson: true)
class MoodleAssignFeedback {
  /// 只有評語、沒有分數時也在，`grade` 是 "-1.00000"。
  @JsonKey(name: 'grade')
  MoodleAssignGrade? grade;

  /// 伺服器回的是 HTML 片段（如 `85.00&nbsp;/&nbsp;100.00`），connector 的
  /// `submissionStatusOf` 已 HtmlUtils.clean 成純文字，這裡只進 Text。
  @JsonKey(name: 'gradefordisplay', defaultValue: "")
  String gradefordisplay;

  /// Unix 秒；成績簿沒有評分日期時是 null。
  @JsonKey(name: 'gradeddate')
  int? gradeddate;

  @JsonKey(name: 'plugins', defaultValue: [])
  List<MoodleAssignPlugin> plugins;

  MoodleAssignFeedback({
    this.grade,
    this.gradefordisplay = "",
    this.gradeddate,
    List<MoodleAssignPlugin>? plugins,
  }) : plugins = plugins ?? <MoodleAssignPlugin>[];

  bool get hasGrade =>
      gradefordisplay.trim().isNotEmpty || (grade?.isSet ?? false);

  /// 老師的文字回饋（comments 外掛），HTML；沒有就空字串。
  String get commentsHtml {
    for (final p in plugins) {
      if (p.type == 'comments') return p.editorText('comments');
    }
    return "";
  }

  /// 回饋檔案：file、editpdf 等所有非 comments 外掛的檔案。
  List<MoodleAssignFile> get files => [
        for (final p in plugins)
          if (p.type != 'comments') ...p.allFiles
      ];

  factory MoodleAssignFeedback.fromJson(Map<String, dynamic> json) =>
      _$MoodleAssignFeedbackFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleAssignFeedbackToJson(this);

  @override
  String toString() => jsonEncode(this);
}
