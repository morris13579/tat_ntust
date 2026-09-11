import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'moodle_mod_forum_draft_area.g.dart';

/// `mod_forum_prepare_draft_area_for_post` 的回應。`area` 是 `attachment`
/// （附件）或 `post`（內嵌圖片），兩者回的東西不一樣。
///
/// `areaoptions` 是伺服器把 PHP 關聯陣列攤成 `[{name, value}]`，`value` 是
/// PARAM_RAW（數字會是字串），所以 [maxbytes] / [maxfiles] 由
/// [MoodleForumDraftArea.fromJson] 之外的 [intOptionOf] 自己挑出來。
class MoodleForumDraftArea {
  const MoodleForumDraftArea({
    required this.draftitemid,
    this.files = const [],
    this.maxbytes = 0,
    this.maxfiles = 0,
    this.messagetext = "",
  });

  final int draftitemid;

  final List<MoodleForumDraftFile> files;

  /// 伺服器**解析過**的有效上限（已含 `$COURSE->maxbytes`）——這是 App 唯一
  /// 拿得到真實課程層級上限的地方。0 ＝解不出來，當成不知道。
  final int maxbytes;

  /// `$forum->maxattachments`。0 ＝解不出來。
  final int maxfiles;

  /// 貼文原文，`@@PLUGINFILE@@` 已經被伺服器換成 draft 區的絕對網址。
  /// **只有 `area == 'post'` 才有內容**，附件那一區固定是 null ⇒ 空字串。
  ///
  /// 它是 `usercontextid` 唯一可靠的來源，所以存檔時的 draft 網址前綴一定要
  /// 從這裡讀出來（見 `MoodleDraftUrlUtils.draftPrefixIn`），不可以自己組。
  final String messagetext;

  /// `areaoptions` 裡的一個整數設定。`value` 是 PARAM_RAW，數字可能是字串，
  /// 解不出來回 0（不知道）。
  static int intOptionOf(dynamic areaoptions, String name) {
    if (areaoptions is! List) return 0;
    for (final e in areaoptions) {
      if (e is! Map || e['name']?.toString() != name) continue;
      final value = e['value'];
      if (value is num) return value.toInt();
      return int.tryParse('$value') ?? 0;
    }
    return 0;
  }
}

/// draft 區裡的一個檔案。
///
/// **這是 `external_files`，網址欄位叫 `fileurl`**，而討論串貼文的
/// `attachments[]` 走 `stored_file_exporter`、欄位叫 `url`。同一頁上兩種形狀，
/// **不可以**共用 `MoodleForumFile`——共用的話 draft 區的檔案會全部拿到空
/// 網址，畫面上只是「列得出來但點不開」，不會拋。
@JsonSerializable()
class MoodleForumDraftFile {
  @JsonKey(name: 'filename', defaultValue: "")
  String filename;

  @JsonKey(name: 'filepath', defaultValue: "/")
  String filepath;

  @JsonKey(name: 'filesize', defaultValue: 0)
  int filesize;

  @JsonKey(name: 'fileurl', defaultValue: "")
  String fileurl;

  @JsonKey(name: 'mimetype', defaultValue: "")
  String mimetype;

  MoodleForumDraftFile({
    this.filename = "",
    this.filepath = "/",
    this.filesize = 0,
    this.fileurl = "",
    this.mimetype = "",
  });

  factory MoodleForumDraftFile.fromJson(Map<String, dynamic> json) =>
      _$MoodleForumDraftFileFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleForumDraftFileToJson(this);

  @override
  String toString() => jsonEncode(this);
}
