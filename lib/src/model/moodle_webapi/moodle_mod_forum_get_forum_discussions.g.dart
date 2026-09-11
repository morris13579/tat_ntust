// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moodle_mod_forum_get_forum_discussions.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoodleModForumGetForumDiscussions _$MoodleModForumGetForumDiscussionsFromJson(
        Map<String, dynamic> json) =>
    MoodleModForumGetForumDiscussions(
      discussions: (json['discussions'] as List<dynamic>?)
          ?.map((e) => Discussions.fromJson(e as Map<String, dynamic>))
          .toList(),
      forumFound: json['forumFound'] as bool? ?? true,
      forumId: (json['forumId'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$MoodleModForumGetForumDiscussionsToJson(
        MoodleModForumGetForumDiscussions instance) =>
    <String, dynamic>{
      'discussions': instance.discussions,
      'forumFound': instance.forumFound,
      'forumId': instance.forumId,
    };

Discussions _$DiscussionsFromJson(Map<String, dynamic> json) => Discussions(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? "",
      groupid: (json['groupid'] as num?)?.toInt() ?? 0,
      timemodified: (json['timemodified'] as num?)?.toInt() ?? 0,
      usermodified: (json['usermodified'] as num?)?.toInt() ?? 0,
      timestart: (json['timestart'] as num?)?.toInt() ?? 0,
      timeend: (json['timeend'] as num?)?.toInt() ?? 0,
      discussion: (json['discussion'] as num?)?.toInt() ?? 0,
      parent: (json['parent'] as num?)?.toInt() ?? 0,
      userid: (json['userid'] as num?)?.toInt() ?? 0,
      created: (json['created'] as num?)?.toInt() ?? 0,
      modified: (json['modified'] as num?)?.toInt() ?? 0,
      mailed: (json['mailed'] as num?)?.toInt() ?? 0,
      subject: json['subject'] as String? ?? "",
      message: json['message'] as String? ?? "",
      messageformat: (json['messageformat'] as num?)?.toInt() ?? 0,
      messagetrust: (json['messagetrust'] as num?)?.toInt() ?? 0,
      attachment: json['attachment'] == null
          ? false
          : hasAttachmentFromJson(json['attachment']),
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((e) => Attachments.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalscore: (json['totalscore'] as num?)?.toInt() ?? 0,
      mailnow: (json['mailnow'] as num?)?.toInt() ?? 0,
      userfullname: json['userfullname'] as String? ?? "",
      usermodifiedfullname: json['usermodifiedfullname'] as String? ?? "",
      userpictureurl: json['userpictureurl'] as String? ?? "",
      usermodifiedpictureurl: json['usermodifiedpictureurl'] as String? ?? "",
      numreplies: (json['numreplies'] as num?)?.toInt() ?? 0,
      numunread: (json['numunread'] as num?)?.toInt() ?? 0,
      pinned: json['pinned'] as bool? ?? false,
      isNone: json['isNone'] as bool? ?? false,
    );

Map<String, dynamic> _$DiscussionsToJson(Discussions instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'groupid': instance.groupid,
      'timemodified': instance.timemodified,
      'usermodified': instance.usermodified,
      'timestart': instance.timestart,
      'timeend': instance.timeend,
      'discussion': instance.discussion,
      'parent': instance.parent,
      'userid': instance.userid,
      'created': instance.created,
      'modified': instance.modified,
      'mailed': instance.mailed,
      'subject': instance.subject,
      'message': instance.message,
      'isNone': instance.isNone,
      'messageformat': instance.messageformat,
      'messagetrust': instance.messagetrust,
      'attachment': instance.attachment,
      'attachments': instance.attachments,
      'totalscore': instance.totalscore,
      'mailnow': instance.mailnow,
      'userfullname': instance.userfullname,
      'usermodifiedfullname': instance.usermodifiedfullname,
      'userpictureurl': instance.userpictureurl,
      'usermodifiedpictureurl': instance.usermodifiedpictureurl,
      'numreplies': instance.numreplies,
      'numunread': instance.numunread,
      'pinned': instance.pinned,
    };

Attachments _$AttachmentsFromJson(Map<String, dynamic> json) => Attachments(
      filename: json['filename'] as String? ?? "",
      mimetype: json['mimetype'] as String? ?? "",
      fileurl: json['fileurl'] as String? ?? "",
    );

Map<String, dynamic> _$AttachmentsToJson(Attachments instance) =>
    <String, dynamic>{
      'filename': instance.filename,
      'mimetype': instance.mimetype,
      'fileurl': instance.fileurl,
    };
