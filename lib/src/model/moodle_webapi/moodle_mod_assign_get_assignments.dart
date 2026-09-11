import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'moodle_mod_assign_get_assignments.g.dart';

/// `mod_assign_get_assignments` 的回應。日期欄位伺服器已套過
/// `update_effective_access`，含使用者與群組的 override，App 不必再算。
/// 只宣告有人讀的欄位——未宣告的 key 不會進 `cache_moodle_assign` 那包 blob。
@JsonSerializable(explicitToJson: true)
class MoodleModAssignGetAssignments {
  @JsonKey(name: 'courses', defaultValue: [])
  List<MoodleAssignCourse> courses;

  MoodleModAssignGetAssignments({
    List<MoodleAssignCourse>? courses,
  }) : courses = courses ?? <MoodleAssignCourse>[];

  factory MoodleModAssignGetAssignments.fromJson(Map<String, dynamic> json) =>
      _$MoodleModAssignGetAssignmentsFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleModAssignGetAssignmentsToJson(this);

  @override
  String toString() => jsonEncode(this);
}

/// `courses[]` 的元素。只用來剝出 [assignments]，不快取。
@JsonSerializable(explicitToJson: true)
class MoodleAssignCourse {
  @JsonKey(name: 'assignments', defaultValue: [])
  List<MoodleAssignment> assignments;

  MoodleAssignCourse({
    List<MoodleAssignment>? assignments,
  }) : assignments = assignments ?? <MoodleAssignment>[];

  factory MoodleAssignCourse.fromJson(Map<String, dynamic> json) =>
      _$MoodleAssignCourseFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleAssignCourseToJson(this);

  @override
  String toString() => jsonEncode(this);
}

/// 一份作業（`assignments[]` 的元素），只留畫面要用的欄位。
@JsonSerializable(explicitToJson: true)
class MoodleAssignment {
  /// assign instance id；`mod_assign_get_submission_status` 的 `assignid` 吃它。
  @JsonKey(name: 'id', defaultValue: 0)
  int id;

  /// course module id；網頁的 `mod/assign/view.php?id=` 吃它。
  @JsonKey(name: 'cmid', defaultValue: 0)
  int cmid;

  /// connector 的 `assignmentsOf` 已 HtmlUtils.clean 還原成純文字。
  @JsonKey(name: 'name', defaultValue: "")
  String name;

  /// Unix 秒，0 = 沒有截止日期。
  @JsonKey(name: 'duedate', defaultValue: 0)
  int duedate;

  @JsonKey(name: 'allowsubmissionsfromdate', defaultValue: 0)
  int allowsubmissionsfromdate;

  @JsonKey(name: 'cutoffdate', defaultValue: 0)
  int cutoffdate;

  /// 1 = 沒有任何繳交外掛（離線評分）；狀態籤不該說「未繳交」或「已逾期」。
  @JsonKey(name: 'nosubmissions', defaultValue: 0)
  int nosubmissions;

  /// 1 = 團隊作業：Moodle 學生頁看的是 `teamsubmission` 那一筆，不是自己的。
  @JsonKey(name: 'teamsubmission', defaultValue: 0)
  int teamsubmission;

  /// 1 = 每一位組員都要各自送出，整組才算送出（`update_team_submission` 的
  /// allsubmitted 分支）。也只有它為 1 時
  /// `submissiongroupmemberswhoneedtosubmit` 才會非空。
  @JsonKey(name: 'requireallteammemberssubmit', defaultValue: 0)
  int requireallteammemberssubmit;

  /// 1 = 沒有分到組的人不能交（`can_edit_submission` 直接回 false）。
  @JsonKey(name: 'preventsubmissionnotingroup', defaultValue: 0)
  int preventsubmissionnotingroup;

  /// 1 = 有草稿階段：`save_submission` 只存成草稿，還要再送出評分。
  /// 0 = 存檔就是繳交（伺服器直接標成 submitted 並寄出繳交回條）。
  @JsonKey(name: 'submissiondrafts', defaultValue: 0)
  int submissiondrafts;

  /// 1 = 要學生同意繳交聲明。`save_submission` 路徑伺服器**不驗**，只有
  /// `submit_for_grading` 會擋，所以沒有草稿階段的作業必須由 App 自己要求勾選。
  @JsonKey(name: 'requiresubmissionstatement', defaultValue: 0)
  int requiresubmissionstatement;

  /// 只有 [requiresubmissionstatement] 為真時才在；是站台層級的 admin 設定
  /// 過 `format_text` 的 HTML，可能是空字串（空字串＝伺服器端不會擋）。
  @JsonKey(name: 'submissionstatement')
  String? submissionstatement;

  /// -1 = 不限次數。
  @JsonKey(name: 'maxattempts', defaultValue: -1)
  int maxattempts;

  @JsonKey(name: 'attemptreopenmethod', defaultValue: "")
  String attemptreopenmethod;

  /// 秒，> 0 代表有作答時限。
  ///
  /// **這一欄是原始欄位值，沒有套 override**（`externallib.php` 寫的是
  /// `'timelimit' => $module->timelimit`，跟隔壁的 `duedate` 走
  /// `get_instance()` 不一樣），而且它也反映不出站台層級的 `enabletimelimit`。
  /// 真正要拿來倒數的是 `lastattempt.timelimit`，這一欄只能當清單上的提示。
  @JsonKey(name: 'timelimit', defaultValue: 0)
  int timelimit;

  @JsonKey(name: 'blindmarking', defaultValue: 0)
  int blindmarking;

  /// 只收錄 enabled 且 visible 的外掛，見 [MoodleAssignConfig]。
  @JsonKey(name: 'configs', defaultValue: [])
  List<MoodleAssignConfig> configs;

  /// null = 伺服器沒送（尚未開放繳交），空字串 = 老師真的沒寫，兩者畫面不同。
  @JsonKey(name: 'intro')
  String? intro;

  @JsonKey(name: 'introattachments', defaultValue: [])
  List<MoodleAssignFile> introattachments;

  MoodleAssignment({
    this.id = 0,
    this.cmid = 0,
    this.name = "",
    this.duedate = 0,
    this.allowsubmissionsfromdate = 0,
    this.cutoffdate = 0,
    this.nosubmissions = 0,
    this.teamsubmission = 0,
    this.requireallteammemberssubmit = 0,
    this.preventsubmissionnotingroup = 0,
    this.submissiondrafts = 0,
    this.requiresubmissionstatement = 0,
    this.submissionstatement,
    this.maxattempts = -1,
    this.attemptreopenmethod = "",
    this.timelimit = 0,
    this.blindmarking = 0,
    List<MoodleAssignConfig>? configs,
    this.intro,
    List<MoodleAssignFile>? introattachments,
  })  : configs = configs ?? <MoodleAssignConfig>[],
        introattachments = introattachments ?? <MoodleAssignFile>[];

  bool get hasDueDate => duedate > 0;

  /// 有草稿階段：那顆鈕叫「儲存草稿」，還要再送出評分。
  bool get tracksDrafts => submissiondrafts != 0;

  bool get requiresStatement => requiresubmissionstatement != 0;

  bool get hasTimeLimit => timelimit > 0;

  bool get isBlindMarking => blindmarking != 0;

  /// 不要用 `isNotEmpty`：null 與空字串語意不同，見 [intro]。
  bool get hasIntro => intro != null;

  bool get isTeamSubmission => teamsubmission != 0;

  bool get requiresAllTeamMembersSubmit => requireallteammemberssubmit != 0;

  bool get preventsSubmissionNotInGroup => preventsubmissionnotingroup != 0;

  /// -1 = 不限次數。
  bool get hasAttemptLimit => maxattempts > 0;

  /// 離線評分、沒有東西要交。
  bool get noSubmissionRequired => nosubmissions != 0;

  factory MoodleAssignment.fromJson(Map<String, dynamic> json) =>
      _$MoodleAssignmentFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleAssignmentToJson(this);

  @override
  String toString() => jsonEncode(this);
}

/// `configs[]` 的一個元素。只有 enabled 且 visible 的外掛才會出現在這裡，
/// 所以「有沒有這個 plugin 的任何一列」就是「這個繳交外掛有沒有開」。
@JsonSerializable(explicitToJson: true)
class MoodleAssignConfig {
  /// file / onlinetext / comments ……
  @JsonKey(name: 'plugin', defaultValue: "")
  String plugin;

  /// assignsubmission / assignfeedback。同名外掛兩邊都有，一定要一起比對。
  @JsonKey(name: 'subtype', defaultValue: "")
  String subtype;

  @JsonKey(name: 'name', defaultValue: "")
  String name;

  /// 伺服器一律送字串，數字也是。
  @JsonKey(name: 'value', defaultValue: "")
  String value;

  MoodleAssignConfig({
    this.plugin = "",
    this.subtype = "",
    this.name = "",
    this.value = "",
  });

  factory MoodleAssignConfig.fromJson(Map<String, dynamic> json) =>
      _$MoodleAssignConfigFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleAssignConfigToJson(this);

  @override
  String toString() => jsonEncode(this);
}

/// `external_files` 的一個元素（intro 附件、繳交檔案、回饋檔案共用）。
@JsonSerializable(explicitToJson: true)
class MoodleAssignFile {
  @JsonKey(name: 'filename', defaultValue: "")
  String filename;

  /// pluginfile.php 網址，交給 `MoodleWebApiConnector.fileUrlWithToken` 加憑證。
  @JsonKey(name: 'fileurl', defaultValue: "")
  String fileurl;

  /// 檔案在 filearea 裡的資料夾，形如 `/` 或 `/sub/`。`external_files` 一定
  /// 會送；缺席退回 `/` 才拼得出 `fileurl` 的結尾，見 `MoodlePluginFileUtils`。
  @JsonKey(name: 'filepath', defaultValue: "/")
  String filepath;

  @JsonKey(name: 'mimetype', defaultValue: "")
  String mimetype;

  /// 位元組。`external_files` 的這一欄是 VALUE_OPTIONAL，缺席是 0＝未知；
  /// 重傳舊繳交檔案時用它驗下載回來的那一份，見 `_buildDraftArea`。
  @JsonKey(name: 'filesize', defaultValue: 0)
  int filesize;

  MoodleAssignFile({
    this.filename = "",
    this.fileurl = "",
    this.filepath = "/",
    this.mimetype = "",
    this.filesize = 0,
  });

  factory MoodleAssignFile.fromJson(Map<String, dynamic> json) =>
      _$MoodleAssignFileFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleAssignFileToJson(this);

  @override
  String toString() => jsonEncode(this);
}
