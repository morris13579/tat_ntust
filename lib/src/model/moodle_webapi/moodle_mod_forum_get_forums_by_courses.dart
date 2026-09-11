import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'moodle_mod_forum_get_forums_by_courses.g.dart';

/// `mod_forum_get_forums_by_courses` 的回應元素。回的是一個陣列，
/// 不是 `{forums: []}`；只宣告畫面與判斷會讀的欄位。
@JsonSerializable()
class MoodleForum {
  /// forum instance id，也就是 `mod_forum_get_forum_discussions` 的 `forumid`。
  @JsonKey(name: 'id', defaultValue: 0)
  int id;

  @JsonKey(name: 'course', defaultValue: 0)
  int course;

  /// news / general / eachuser / single / qanda / blog。公告區是 news。
  @JsonKey(name: 'type', defaultValue: "")
  String type;

  @JsonKey(name: 'name', defaultValue: "")
  String name;

  @JsonKey(name: 'cmid', defaultValue: 0)
  int cmid;

  @JsonKey(name: 'numdiscussions', defaultValue: 0)
  int numdiscussions;

  /// VALUE_OPTIONAL：伺服器算的是 `forum_user_can_post_discussion`，
  /// 但**不含發文節流**，所以 true 之後仍可能收到 forumblockingtoomanyposts。
  /// null 代表站台沒回報，一律當成不能發。
  @JsonKey(name: 'cancreatediscussions')
  bool? cancreatediscussions;

  /// 這個討論區最多能附幾個檔案。**0 ＝完全不准附件**（`forum_can_create_attachment`
  /// 的第一個 AND 條件就是 `!empty($forum->maxattachments)`）。
  @JsonKey(name: 'maxattachments', defaultValue: 0)
  int maxattachments;

  /// 附件的位元組上限。**`== 1` ＝完全不准附件**（Moodle 用 1 當那個哨兵值）；
  /// **`== 0` ＝用課程／站台預設**，而課程層級的 `$COURSE->maxbytes`
  /// **沒有任何 App 拿得到的 API**（`core_enrol_get_users_courses` 不回它），
  /// 所以新增路徑的本地上限只能是近似值，見 `MoodleForumEditUtils.effectiveMaxBytes`。
  @JsonKey(name: 'maxbytes', defaultValue: 0)
  int maxbytes;

  MoodleForum({
    this.id = 0,
    this.course = 0,
    this.type = "",
    this.name = "",
    this.cmid = 0,
    this.numdiscussions = 0,
    this.cancreatediscussions,
    this.maxattachments = 0,
    this.maxbytes = 0,
  });

  factory MoodleForum.fromJson(Map<String, dynamic> json) =>
      _$MoodleForumFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleForumToJson(this);

  @override
  String toString() => jsonEncode(this);
}
