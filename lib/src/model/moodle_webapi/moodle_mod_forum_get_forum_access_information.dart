import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'moodle_mod_forum_get_forum_access_information.g.dart';

/// `mod_forum_get_forum_access_information` 的回應。
///
/// 整份回應是 `load_capability_def('mod_forum')` 在執行期攤出來的：欄位集合
/// 跟著站台的 Moodle 版本走，每一格都是 VALUE_OPTIONAL。所以全部宣告成
/// `bool?`，**缺席 ＝不知道 ⇒ 保守**（附件不給、刪除不畫）。
///
/// **沒有 `caneditownpost` 這個欄位**：`mod/forum/db/access.php` 根本沒有
/// `mod/forum:editownpost` 這個 capability——「能不能編輯自己的貼文」由
/// 擁有權 ∧ 時間窗 ∧ 非 mailnow 決定，只有 post_exporter 的
/// `capabilities.edit` 答得出來。
///
/// [candeleteownpost] 是**必要非充分**：false ⇒ 一定刪不掉（可以永遠不畫刪除
/// 鈕）；true 什麼都證明不了（還要 ownpost ∧ 時間窗 ∧ 非 mailnow ∧ 沒有回覆
/// ∧ 沒有被評分）。
///
/// [canstartdiscussion] 沒有讀取點：App 不提供「發表新主題」。它也比伺服器
/// 端的 `forum_user_can_post_discussion` 弱（不含討論串鎖定與群組模式），
/// 就算哪天要用也不能單獨拿它當閘門。
@JsonSerializable()
class MoodleForumAccess {
  /// 回覆路徑的附件閘門。純 capability，**不含** `maxattachments == 0` 與
  /// `maxbytes == 1`，那兩個要自己從 forum record 補。
  @JsonKey(name: 'cancreateattachment')
  bool? cancreateattachment;

  @JsonKey(name: 'candeleteownpost')
  bool? candeleteownpost;

  @JsonKey(name: 'canreplypost')
  bool? canreplypost;

  @JsonKey(name: 'canstartdiscussion')
  bool? canstartdiscussion;

  MoodleForumAccess({
    this.cancreateattachment,
    this.candeleteownpost,
    this.canreplypost,
    this.canstartdiscussion,
  });

  factory MoodleForumAccess.fromJson(Map<String, dynamic> json) =>
      _$MoodleForumAccessFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleForumAccessToJson(this);

  @override
  String toString() => jsonEncode(this);
}
