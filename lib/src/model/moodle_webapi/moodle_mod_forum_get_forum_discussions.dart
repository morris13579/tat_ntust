// mod_forum_get_forum_discussions 的回應。
//
// 不要改呼叫 `mod_forum_get_forum_discussions_paginated`：Moodle 3.7 標為
// 棄用（MDL-65071），4.4 已從核心移除（MDL-70483）。

import 'package:json_annotation/json_annotation.dart';

part 'moodle_mod_forum_get_forum_discussions.g.dart';

@JsonSerializable()
class MoodleModForumGetForumDiscussions {
  @JsonKey(name: 'discussions')
  late List<Discussions> discussions;

  /// 這門課有沒有公告討論區。伺服器不回這個欄位——它由 connector 填，
  /// false 時 discussions 一定是空的，畫面畫「沒有公告區」而不是錯誤。
  @JsonKey(name: 'forumFound', defaultValue: true)
  bool forumFound;

  /// 這批主題屬於哪個 forum instance。伺服器不回這個欄位——它由 connector
  /// 填（公告那條路的 forum id 本來只活在 `_findAnnouncementForumId` 裡面），
  /// 而回覆要附件就必須知道它。加性欄位：舊快取解回來是 0，那時附件入口收起
  /// 來，回覆／編輯／刪除照常。
  @JsonKey(name: 'forumId', defaultValue: 0)
  int forumId;

  MoodleModForumGetForumDiscussions({
    List<Discussions>? discussions,
    this.forumFound = true,
    this.forumId = 0,
  }) {
    this.discussions = discussions ?? [];
  }

  factory MoodleModForumGetForumDiscussions.fromJson(
          Map<String, dynamic> srcJson) =>
      _$MoodleModForumGetForumDiscussionsFromJson(srcJson);

  Map<String, dynamic> toJson() =>
      _$MoodleModForumGetForumDiscussionsToJson(this);
}

@JsonSerializable()
class Discussions extends Object {
  @JsonKey(name: 'id')
  int id;

  @JsonKey(name: 'name')
  String name;

  @JsonKey(name: 'groupid')
  int groupid;

  @JsonKey(name: 'timemodified')
  int timemodified;

  @JsonKey(name: 'usermodified')
  int usermodified;

  @JsonKey(name: 'timestart')
  int timestart;

  @JsonKey(name: 'timeend')
  int timeend;

  @JsonKey(name: 'discussion')
  int discussion;

  @JsonKey(name: 'parent')
  int parent;

  @JsonKey(name: 'userid')
  int userid;

  @JsonKey(name: 'created')
  int created;

  @JsonKey(name: 'modified')
  int modified;

  @JsonKey(name: 'mailed')
  int mailed;

  @JsonKey(name: 'subject')
  String subject;

  @JsonKey(name: 'message')
  String message;

  bool isNone;

  @JsonKey(name: 'messageformat')
  int messageformat;

  @JsonKey(name: 'messagetrust')
  int messagetrust;

  /// 伺服器這一欄是 PARAM_RAW，有附件時是字串 `"1"`、沒有時是空字串；
  /// 直接當 bool 解會讓「有附件的公告」整批解析失敗。
  @JsonKey(name: 'attachment', fromJson: hasAttachmentFromJson)
  bool attachment;

  @JsonKey(name: 'attachments')
  late List<Attachments> attachments;

  @JsonKey(name: 'totalscore')
  int totalscore;

  @JsonKey(name: 'mailnow')
  int mailnow;

  @JsonKey(name: 'userfullname')
  String userfullname;

  @JsonKey(name: 'usermodifiedfullname')
  String usermodifiedfullname;

  @JsonKey(name: 'userpictureurl')
  String userpictureurl;

  @JsonKey(name: 'usermodifiedpictureurl')
  String usermodifiedpictureurl;

  @JsonKey(name: 'numreplies')
  int numreplies;

  @JsonKey(name: 'numunread')
  int numunread;

  @JsonKey(name: 'pinned')
  bool pinned;

  Discussions({
    this.id = 0,
    this.name = "",
    this.groupid = 0,
    this.timemodified = 0,
    this.usermodified = 0,
    this.timestart = 0,
    this.timeend = 0,
    this.discussion = 0,
    this.parent = 0,
    this.userid = 0,
    this.created = 0,
    this.modified = 0,
    this.mailed = 0,
    this.subject = "",
    this.message = "",
    this.messageformat = 0,
    this.messagetrust = 0,
    this.attachment = false,
    List<Attachments>? attachments,
    this.totalscore = 0,
    this.mailnow = 0,
    this.userfullname = "",
    this.usermodifiedfullname = "",
    this.userpictureurl = "",
    this.usermodifiedpictureurl = "",
    this.numreplies = 0,
    this.numunread = 0,
    this.pinned = false,
    this.isNone = false,
  }) {
    this.attachments = attachments ?? [];
  }

  factory Discussions.fromJson(Map<String, dynamic> srcJson) =>
      _$DiscussionsFromJson(srcJson);

  Map<String, dynamic> toJson() => _$DiscussionsToJson(this);
}

@JsonSerializable()
class Attachments extends Object {
  @JsonKey(name: 'filename')
  String filename;

  @JsonKey(name: 'mimetype')
  String mimetype;

  @JsonKey(name: 'fileurl')
  String fileurl;

  Attachments({
    this.filename = "",
    this.mimetype = "",
    this.fileurl = "",
  });

  factory Attachments.fromJson(Map<String, dynamic> srcJson) =>
      _$AttachmentsFromJson(srcJson);

  Map<String, dynamic> toJson() => _$AttachmentsToJson(this);
}

bool hasAttachmentFromJson(dynamic value) => switch (value) {
      bool b => b,
      num n => n != 0,
      String s => s.isNotEmpty && s != '0',
      _ => false,
    };
