// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moodle_mod_forum_get_forum_discussions_paginated.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoodleModForumGetForumDiscussionsPaginated
    _$MoodleModForumGetForumDiscussionsPaginatedFromJson(
            Map<String, dynamic> json) =>
        MoodleModForumGetForumDiscussionsPaginated(
          discussions: (json['discussions'] as List<dynamic>?)
              ?.map((e) => Discussions.fromJson(e as Map<String, dynamic>))
              .toList(),
        );

Map<String, dynamic> _$MoodleModForumGetForumDiscussionsPaginatedToJson(
        MoodleModForumGetForumDiscussionsPaginated instance) =>
    <String, dynamic>{
      'discussions': instance.discussions,
    };

Discussions _$DiscussionsFromJson(Map<String, dynamic> json) => Discussions(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? "",
      groupid: json['groupid'] as int? ?? 0,
      timemodified: json['timemodified'] as int? ?? 0,
      usermodified: json['usermodified'] as int? ?? 0,
      timestart: json['timestart'] as int? ?? 0,
      timeend: json['timeend'] as int? ?? 0,
      discussion: json['discussion'] as int? ?? 0,
      parent: json['parent'] as int? ?? 0,
      userid: json['userid'] as int? ?? 0,
      created: json['created'] as int? ?? 0,
      modified: json['modified'] as int? ?? 0,
      mailed: json['mailed'] as int? ?? 0,
      subject: json['subject'] as String? ?? "",
      message: json['message'] as String? ?? "",
      messageformat: json['messageformat'] as int? ?? 0,
      messagetrust: json['messagetrust'] as int? ?? 0,
      attachment: json['attachment'] as String? ?? "",
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((e) => Attachments.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalscore: json['totalscore'] as int? ?? 0,
      mailnow: json['mailnow'] as int? ?? 0,
      userfullname: json['userfullname'] as String? ?? "",
      usermodifiedfullname: json['usermodifiedfullname'] as String? ?? "",
      userpictureurl: json['userpictureurl'] as String? ?? "",
      usermodifiedpictureurl: json['usermodifiedpictureurl'] as String? ?? "",
      numreplies: json['numreplies'] as int? ?? 0,
      numunread: json['numunread'] as int? ?? 0,
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
