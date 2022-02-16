import 'package:json_annotation/json_annotation.dart';

part 'moodle_mod_forum_get_forum_discussions_paginated.g.dart';

/// discussions : [{"id":242038,"name":"論文研討注意事項","groupid":-1,"timemodified":1631163160,"usermodified":51406,"timestart":0,"timeend":0,"discussion":153487,"parent":0,"userid":51406,"created":1631163160,"modified":1631163160,"mailed":1,"subject":"論文研討注意事項","message":"<p>各位同學好，附件是本學期論文研討的相關規定<br /></p>","messageformat":1,"messagetrust":0,"attachment":"1","attachments":[{"filename":"110_1論文研討的規定.pptx","mimetype":"application/vnd.openxmlformats-officedocument.presentationml.presentation","fileurl":"https://moodle.ntust.edu.tw/webservice/pluginfile.php/826780/mod_forum/attachment/242038/110_1%E8%AB%96%E6%96%87%E7%A0%94%E8%A8%8E%E7%9A%84%E8%A6%8F%E5%AE%9A.pptx"}],"totalscore":0,"mailnow":0,"userfullname":"M10902113@ 陳彥丞","usermodifiedfullname":"M10902113@ 陳彥丞","userpictureurl":"https://moodle.ntust.edu.tw/theme/image.php/essential/core/1631171023/u/f1","usermodifiedpictureurl":"https://moodle.ntust.edu.tw/theme/image.php/essential/core/1631171023/u/f1","numreplies":"0","numunread":0,"pinned":false}]
/// warnings : []

@JsonSerializable()
class MoodleModForumGetForumDiscussionsPaginated {
  @JsonKey(name: 'discussions')
  late List<Discussions> discussions;

  MoodleModForumGetForumDiscussionsPaginated({List<Discussions>? discussions}) {
    this.discussions = discussions ?? [];
  }

  factory MoodleModForumGetForumDiscussionsPaginated.fromJson(
          Map<String, dynamic> srcJson) =>
      _$MoodleModForumGetForumDiscussionsPaginatedFromJson(srcJson);

  Map<String, dynamic> toJson() =>
      _$MoodleModForumGetForumDiscussionsPaginatedToJson(this);
}

/// id : 242038
/// name : "論文研討注意事項"
/// groupid : -1
/// timemodified : 1631163160
/// usermodified : 51406
/// timestart : 0
/// timeend : 0
/// discussion : 153487
/// parent : 0
/// userid : 51406
/// created : 1631163160
/// modified : 1631163160
/// mailed : 1
/// subject : "論文研討注意事項"
/// message : "<p>各位同學好，附件是本學期論文研討的相關規定<br /></p>"
/// messageformat : 1
/// messagetrust : 0
/// attachment : "1"
/// attachments : [{"filename":"110_1論文研討的規定.pptx","mimetype":"application/vnd.openxmlformats-officedocument.presentationml.presentation","fileurl":"https://moodle.ntust.edu.tw/webservice/pluginfile.php/826780/mod_forum/attachment/242038/110_1%E8%AB%96%E6%96%87%E7%A0%94%E8%A8%8E%E7%9A%84%E8%A6%8F%E5%AE%9A.pptx"}]
/// totalscore : 0
/// mailnow : 0
/// userfullname : "M10902113@ 陳彥丞"
/// usermodifiedfullname : "M10902113@ 陳彥丞"
/// userpictureurl : "https://moodle.ntust.edu.tw/theme/image.php/essential/core/1631171023/u/f1"
/// usermodifiedpictureurl : "https://moodle.ntust.edu.tw/theme/image.php/essential/core/1631171023/u/f1"
/// numreplies : "0"
/// numunread : 0
/// pinned : false
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

  @JsonKey(name: 'attachment')
  String attachment;

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
    this.attachment = "",
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

/// filename : "110_1論文研討的規定.pptx"
/// mimetype : "application/vnd.openxmlformats-officedocument.presentationml.presentation"
/// fileurl : "https://moodle.ntust.edu.tw/webservice/pluginfile.php/826780/mod_forum/attachment/242038/110_1%E8%AB%96%E6%96%87%E7%A0%94%E8%A8%8E%E7%9A%84%E8%A6%8F%E5%AE%9A.pptx"

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
