import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'moodle_gradereport_get_grade_items.g.dart';

/// `gradereport_user_get_grade_items` 的回應。
///
/// 不要改用 `gradereport_user_get_grades_table`：它回的 `tables[0].tabledata`
/// 是元素型別不定、值為 HTML 片段的混合陣列，只能猜著剖，Moodle 一升版
/// 就靜靜壞掉。這個端點回的是結構化欄位。
///
/// 每個欄位的寬鬆程度是刻意的：非空欄位一律給 `defaultValue`，站台沒送就退回
/// 預設值；Moodle 實測會送 null 的欄位一律宣告成可為 null。曾因為把選用欄位
/// 寫成必填而整頁掛掉，不要把任何一個欄位改成必填。
@JsonSerializable(explicitToJson: true)
class MoodleGradeItemsEntity {
  @JsonKey(name: 'usergrades', defaultValue: [])
  List<MoodleUserGradesEntity> userGrades;

  /// Moodle 的「部分失敗」通道。這裡只保留原始 map，判讀交給
  /// `MoodleWebApiConnector.moodleErrorOf`（它是所有 wsfunction 的共用出口）。
  @JsonKey(name: 'warnings', defaultValue: [])
  List<dynamic> warnings;

  MoodleGradeItemsEntity({
    List<MoodleUserGradesEntity>? userGrades,
    List<dynamic>? warnings,
  })  : userGrades = userGrades ?? <MoodleUserGradesEntity>[],
        warnings = warnings ?? <dynamic>[];

  factory MoodleGradeItemsEntity.fromJson(Map<String, dynamic> srcJson) =>
      _$MoodleGradeItemsEntityFromJson(srcJson);

  Map<String, dynamic> toJson() => _$MoodleGradeItemsEntityToJson(this);

  @override
  String toString() => jsonEncode(this);
}

/// 一位使用者在一門課裡的全部成績項目。
///
/// 帶 `userid` 呼叫時 `usergrades` 只會有一筆，所以快取與 UI 直接吃這一層，
/// 不必每次都從外層剝一次。
@JsonSerializable(explicitToJson: true)
class MoodleUserGradesEntity {
  @JsonKey(name: 'courseid', defaultValue: 0)
  int courseId;

  @JsonKey(name: 'courseidnumber', defaultValue: "")
  String courseIdNumber;

  @JsonKey(name: 'userid', defaultValue: 0)
  int userId;

  @JsonKey(name: 'userfullname', defaultValue: "")
  String userFullName;

  @JsonKey(name: 'useridnumber', defaultValue: "")
  String userIdNumber;

  @JsonKey(name: 'maxdepth', defaultValue: 0)
  int maxDepth;

  @JsonKey(name: 'gradeitems', defaultValue: [])
  List<MoodleGradeItemEntity> gradeItems;

  MoodleUserGradesEntity({
    this.courseId = 0,
    this.courseIdNumber = "",
    this.userId = 0,
    this.userFullName = "",
    this.userIdNumber = "",
    this.maxDepth = 0,
    List<MoodleGradeItemEntity>? gradeItems,
  }) : gradeItems = gradeItems ?? <MoodleGradeItemEntity>[];

  factory MoodleUserGradesEntity.fromJson(Map<String, dynamic> srcJson) =>
      _$MoodleUserGradesEntityFromJson(srcJson);

  Map<String, dynamic> toJson() => _$MoodleUserGradesEntityToJson(this);

  @override
  String toString() => jsonEncode(this);
}

/// 一列成績項目。
///
/// **顯示一律用 `*formatted` 那一組**（[gradeFormatted]、[percentageFormatted]、
/// [weightFormatted]、[rangeFormatted]）。moodle2.ntust.edu.tw 實測回來的
/// [gradeRaw] 是 null 而 [gradeFormatted] 有值——Moodle 只有在使用者對該項目
/// 有 `moodle/grade:viewhidden` 之類的能力時才會填原始數值，學生 token 拿不到。
/// 拿 [gradeRaw] 去畫的話，整頁成績會全部顯示空白。
///
/// 這裡刻意**不**收 `outcomeid` / `scaleid` / `locked` / `gradeislocked` /
/// `gradeisoverridden`：實測全是 null，而它們在 Moodle 的 external 定義裡
/// 跨版本在 PARAM_INT 與 PARAM_BOOL 之間換過（有的版本送 0/1，有的送
/// true/false），宣告成任一種都會在另一種站台上炸掉。UI 也沒有用到它們，
/// 收進來只是憑空多一條會壞的路徑。json_serializable 會忽略未宣告的 key。
@JsonSerializable()
class MoodleGradeItemEntity {
  @JsonKey(name: 'id', defaultValue: 0)
  int id;

  /// 項目名稱。宣告成可為 null：Moodle 對某些自動產生的項目會送 null。
  @JsonKey(name: 'itemname')
  String? itemName;

  /// `course`（課程總分）、`category`（類別總分）、`mod`、`manual`。
  ///
  /// 判斷「課程總分」要看這個欄位（[isCourseTotal]），不要比對中文字串：
  /// 那串字是 Moodle 依**使用者的 Moodle 介面語言**產生的，跟 App 的語系無關，
  /// 介面切成英文就比不中。
  @JsonKey(name: 'itemtype', defaultValue: "")
  String itemType;

  @JsonKey(name: 'itemmodule')
  String? itemModule;

  @JsonKey(name: 'iteminstance')
  int? itemInstance;

  @JsonKey(name: 'itemnumber')
  int? itemNumber;

  @JsonKey(name: 'idnumber')
  String? idNumber;

  @JsonKey(name: 'categoryid')
  int? categoryId;

  @JsonKey(name: 'cmid')
  int? cmid;

  /// 權重。原始值可能是 int 也可能是 double，所以是 `num` 不是 `double`。
  @JsonKey(name: 'weightraw')
  num? weightRaw;

  @JsonKey(name: 'weightformatted', defaultValue: "")
  String weightFormatted;

  /// 實測是 null，畫面請用 [gradeFormatted]。留著是為了 log 與日後判讀。
  @JsonKey(name: 'graderaw')
  num? gradeRaw;

  /// Unix 秒。
  @JsonKey(name: 'gradedatesubmitted')
  int? gradeDateSubmitted;

  /// Unix 秒。實測是 null。
  @JsonKey(name: 'gradedategraded')
  int? gradeDateGraded;

  @JsonKey(name: 'gradehiddenbydate', defaultValue: false)
  bool gradeHiddenByDate;

  @JsonKey(name: 'gradeneedsupdate', defaultValue: false)
  bool gradeNeedsUpdate;

  @JsonKey(name: 'gradeishidden', defaultValue: false)
  bool gradeIsHidden;

  @JsonKey(name: 'gradeformatted', defaultValue: "")
  String gradeFormatted;

  @JsonKey(name: 'grademin')
  num? gradeMin;

  @JsonKey(name: 'grademax')
  num? gradeMax;

  @JsonKey(name: 'rangeformatted', defaultValue: "")
  String rangeFormatted;

  @JsonKey(name: 'percentageformatted', defaultValue: "")
  String percentageFormatted;

  /// 老師的回饋。這一欄**是 HTML**（[feedbackFormat] 是 Moodle 的 format id），
  /// 而且可能含 `<img>`，所以畫面上仍然要走 HtmlWidget。其餘 `*formatted`
  /// 欄位是純文字。
  @JsonKey(name: 'feedback', defaultValue: "")
  String feedback;

  @JsonKey(name: 'feedbackformat', defaultValue: 0)
  int feedbackFormat;

  MoodleGradeItemEntity({
    this.id = 0,
    this.itemName,
    this.itemType = "",
    this.itemModule,
    this.itemInstance,
    this.itemNumber,
    this.idNumber,
    this.categoryId,
    this.cmid,
    this.weightRaw,
    this.weightFormatted = "",
    this.gradeRaw,
    this.gradeDateSubmitted,
    this.gradeDateGraded,
    this.gradeHiddenByDate = false,
    this.gradeNeedsUpdate = false,
    this.gradeIsHidden = false,
    this.gradeFormatted = "",
    this.gradeMin,
    this.gradeMax,
    this.rangeFormatted = "",
    this.percentageFormatted = "",
    this.feedback = "",
    this.feedbackFormat = 0,
  });

  /// 這一列是不是「課程總分」。與使用者的 Moodle 介面語言無關。
  bool get isCourseTotal => itemType == "course";

  /// 類別總分。同樣是伺服器不送 itemname 的那一類列。
  bool get isCategoryTotal => itemType == "category";

  /// 這一列有沒有東西可以顯示。
  ///
  /// 課程總分與類別總分的 `itemname` 實測就是 null——Moodle 的網頁版是
  /// 前端自己補上「課程總分」這個字，不是伺服器送的。所以不能因為沒有
  /// 名字就把整列丟掉，那樣會把最重要的一列濾掉。
  bool get hasDisplayableContent =>
      (itemName?.trim().isNotEmpty ?? false) ||
      isCourseTotal ||
      isCategoryTotal;

  factory MoodleGradeItemEntity.fromJson(Map<String, dynamic> srcJson) =>
      _$MoodleGradeItemEntityFromJson(srcJson);

  Map<String, dynamic> toJson() => _$MoodleGradeItemEntityToJson(this);

  @override
  String toString() => jsonEncode(this);
}
