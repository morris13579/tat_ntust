import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'moodle_mod_forum_get_discussion_posts.g.dart';

/// `mod_forum_get_discussion_posts` 的回應。只宣告有人讀的欄位——宣告出來的
/// 都會進 `cache_moodle_forum_posts` 那包 blob。附件與內嵌檔案走
/// `stored_file_exporter`，網址欄位叫 `url` 不是 `fileurl`，而且沒有 mimetype。
@JsonSerializable(explicitToJson: true)
class MoodleModForumGetDiscussionPosts {
  @JsonKey(name: 'posts', defaultValue: [])
  List<MoodleForumPost> posts;

  MoodleModForumGetDiscussionPosts({List<MoodleForumPost>? posts})
      : posts = posts ?? <MoodleForumPost>[];

  factory MoodleModForumGetDiscussionPosts.fromJson(
          Map<String, dynamic> json) =>
      _$MoodleModForumGetDiscussionPostsFromJson(json);

  Map<String, dynamic> toJson() =>
      _$MoodleModForumGetDiscussionPostsToJson(this);

  @override
  String toString() => jsonEncode(this);
}

@JsonSerializable(explicitToJson: true)
class MoodleForumPost {
  @JsonKey(name: 'id', defaultValue: 0)
  int id;

  @JsonKey(name: 'subject', defaultValue: "")
  String subject;

  @JsonKey(name: 'message', defaultValue: "")
  String message;

  /// FORMAT_MOODLE=0 / HTML=1 / PLAIN=2 / MARKDOWN=4。預設 **1** 是刻意的：
  /// 現行版本寫進 `cache_moodle_forum_posts` 的 blob 沒有這個 key，而它的
  /// `message` 早就是算繪好的 HTML；預設 0 會讓舊快取讀回來時再被轉一次。
  @JsonKey(name: 'messageformat', defaultValue: 1)
  int messageformat;

  /// 伺服器組好的 `"{re} {subject}"`，語系跟著站台。回覆時原樣送回去。
  @JsonKey(name: 'replysubject', defaultValue: "")
  String replysubject;

  /// 缺席刻意留 null 而不是「全部 false」：舊快取或不回這一段的站台代表
  /// 「不知道」，那時不畫回覆鈕（見 `MoodleForumUtils.canReply`）。
  @JsonKey(name: 'capabilities')
  MoodleForumPostCapabilities? capabilities;

  /// 規格上一定在，但缺席不該讓整份回應解析失敗。
  @JsonKey(name: 'author')
  MoodleForumAuthor? author;

  @JsonKey(name: 'discussionid', defaultValue: 0)
  int discussionid;

  @JsonKey(name: 'hasparent', defaultValue: false)
  bool hasparent;

  @JsonKey(name: 'parentid')
  int? parentid;

  /// `isdeleted` 的貼文伺服器不載內容，這兩個欄位是 null。
  @JsonKey(name: 'timecreated')
  int? timecreated;

  @JsonKey(name: 'timemodified')
  int? timemodified;

  @JsonKey(name: 'isdeleted', defaultValue: false)
  bool isdeleted;

  @JsonKey(name: 'isprivatereply', defaultValue: false)
  bool isprivatereply;

  @JsonKey(name: 'attachments', defaultValue: [])
  List<MoodleForumFile> attachments;

  /// `message` 裡 `@@PLUGINFILE@@` 的對照表，只有帶
  /// `includeinlineattachments=1` 才會回。
  @JsonKey(name: 'messageinlinefiles', defaultValue: [])
  List<MoodleForumFile> messageinlinefiles;

  MoodleForumPost({
    this.id = 0,
    this.subject = "",
    this.message = "",
    this.messageformat = 1,
    this.replysubject = "",
    this.capabilities,
    this.author,
    this.discussionid = 0,
    this.hasparent = false,
    this.parentid,
    this.timecreated,
    this.timemodified,
    this.isdeleted = false,
    this.isprivatereply = false,
    List<MoodleForumFile>? attachments,
    List<MoodleForumFile>? messageinlinefiles,
  })  : attachments = attachments ?? <MoodleForumFile>[],
        messageinlinefiles = messageinlinefiles ?? <MoodleForumFile>[];

  factory MoodleForumPost.fromJson(Map<String, dynamic> json) =>
      _$MoodleForumPostFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleForumPostToJson(this);

  @override
  String toString() => jsonEncode(this);
}

/// post_exporter 的 `capabilities`。建模 `reply` / `edit` / `delete`；其餘
/// （split / canreplyprivately / export / …）沒有任何畫面在讀。
///
/// 三格都是**抓取當下**算出來的快照，畫在螢幕上就開始過期：
/// - `edit` ＝ `can_edit_post()`，**含 `$CFG->maxeditingtime` 這個時間窗**，
///   而那個設定沒有任何 web service 讀得到（site_info 與
///   `tool_mobile_get_config` 都沒有），所以客戶端不可以自己算倒數。
/// - `delete` ＝ `can_delete_post()`，匯出時 `$hasreplies` 吃預設值 `false`，
///   也就是**根本沒有算回覆數**：true 的貼文照樣可能在真的刪的時候拿到
///   `couldnotdeletereplies`。
///
/// `defaultValue: false` 是刻意的：舊快取沒有這兩個 key，預設 false 就是
/// 「不畫」。
///
/// **不要改看 `urls.reply` / `urls.edit` / `urls.delete`**：`selfenrol` 為真時
/// 那些網址在不能動的時候也非 null。
@JsonSerializable()
class MoodleForumPostCapabilities {
  @JsonKey(name: 'reply', defaultValue: false)
  bool reply;

  @JsonKey(name: 'edit', defaultValue: false)
  bool edit;

  @JsonKey(name: 'delete', defaultValue: false)
  bool delete;

  MoodleForumPostCapabilities({
    this.reply = false,
    this.edit = false,
    this.delete = false,
  });

  factory MoodleForumPostCapabilities.fromJson(Map<String, dynamic> json) =>
      _$MoodleForumPostCapabilitiesFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleForumPostCapabilitiesToJson(this);

  @override
  String toString() => jsonEncode(this);
}

/// 貼文作者。`groups` 與 `urls` 沒有建模：討論串不畫頭像。
@JsonSerializable()
class MoodleForumAuthor {
  @JsonKey(name: 'id')
  int? id;

  @JsonKey(name: 'fullname', defaultValue: "")
  String fullname;

  @JsonKey(name: 'isdeleted', defaultValue: false)
  bool isdeleted;

  MoodleForumAuthor({
    this.id,
    this.fullname = "",
    this.isdeleted = false,
  });

  factory MoodleForumAuthor.fromJson(Map<String, dynamic> json) =>
      _$MoodleForumAuthorFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleForumAuthorToJson(this);

  @override
  String toString() => jsonEncode(this);
}

@JsonSerializable()
class MoodleForumFile {
  @JsonKey(name: 'filename', defaultValue: "")
  String filename;

  @JsonKey(name: 'filepath', defaultValue: "/")
  String filepath;

  @JsonKey(name: 'filesize', defaultValue: 0)
  int filesize;

  /// pluginfile 網址。stored_file_exporter 叫它 url，不是 fileurl。
  @JsonKey(name: 'url', defaultValue: "")
  String url;

  @JsonKey(name: 'isimage', defaultValue: false)
  bool isimage;

  MoodleForumFile({
    this.filename = "",
    this.filepath = "/",
    this.filesize = 0,
    this.url = "",
    this.isimage = false,
  });

  factory MoodleForumFile.fromJson(Map<String, dynamic> json) =>
      _$MoodleForumFileFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleForumFileToJson(this);

  @override
  String toString() => jsonEncode(this);
}
