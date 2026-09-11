// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moodle_mod_forum_get_discussion_posts.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoodleModForumGetDiscussionPosts _$MoodleModForumGetDiscussionPostsFromJson(
        Map<String, dynamic> json) =>
    MoodleModForumGetDiscussionPosts(
      posts: (json['posts'] as List<dynamic>?)
              ?.map((e) => MoodleForumPost.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$MoodleModForumGetDiscussionPostsToJson(
        MoodleModForumGetDiscussionPosts instance) =>
    <String, dynamic>{
      'posts': instance.posts.map((e) => e.toJson()).toList(),
    };

MoodleForumPost _$MoodleForumPostFromJson(Map<String, dynamic> json) =>
    MoodleForumPost(
      id: (json['id'] as num?)?.toInt() ?? 0,
      subject: json['subject'] as String? ?? '',
      message: json['message'] as String? ?? '',
      messageformat: (json['messageformat'] as num?)?.toInt() ?? 1,
      replysubject: json['replysubject'] as String? ?? '',
      capabilities: json['capabilities'] == null
          ? null
          : MoodleForumPostCapabilities.fromJson(
              json['capabilities'] as Map<String, dynamic>),
      author: json['author'] == null
          ? null
          : MoodleForumAuthor.fromJson(json['author'] as Map<String, dynamic>),
      discussionid: (json['discussionid'] as num?)?.toInt() ?? 0,
      hasparent: json['hasparent'] as bool? ?? false,
      parentid: (json['parentid'] as num?)?.toInt(),
      timecreated: (json['timecreated'] as num?)?.toInt(),
      timemodified: (json['timemodified'] as num?)?.toInt(),
      isdeleted: json['isdeleted'] as bool? ?? false,
      isprivatereply: json['isprivatereply'] as bool? ?? false,
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) => MoodleForumFile.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      messageinlinefiles: (json['messageinlinefiles'] as List<dynamic>?)
              ?.map((e) => MoodleForumFile.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$MoodleForumPostToJson(MoodleForumPost instance) =>
    <String, dynamic>{
      'id': instance.id,
      'subject': instance.subject,
      'message': instance.message,
      'messageformat': instance.messageformat,
      'replysubject': instance.replysubject,
      'capabilities': instance.capabilities?.toJson(),
      'author': instance.author?.toJson(),
      'discussionid': instance.discussionid,
      'hasparent': instance.hasparent,
      'parentid': instance.parentid,
      'timecreated': instance.timecreated,
      'timemodified': instance.timemodified,
      'isdeleted': instance.isdeleted,
      'isprivatereply': instance.isprivatereply,
      'attachments': instance.attachments.map((e) => e.toJson()).toList(),
      'messageinlinefiles':
          instance.messageinlinefiles.map((e) => e.toJson()).toList(),
    };

MoodleForumPostCapabilities _$MoodleForumPostCapabilitiesFromJson(
        Map<String, dynamic> json) =>
    MoodleForumPostCapabilities(
      reply: json['reply'] as bool? ?? false,
      edit: json['edit'] as bool? ?? false,
      delete: json['delete'] as bool? ?? false,
    );

Map<String, dynamic> _$MoodleForumPostCapabilitiesToJson(
        MoodleForumPostCapabilities instance) =>
    <String, dynamic>{
      'reply': instance.reply,
      'edit': instance.edit,
      'delete': instance.delete,
    };

MoodleForumAuthor _$MoodleForumAuthorFromJson(Map<String, dynamic> json) =>
    MoodleForumAuthor(
      id: (json['id'] as num?)?.toInt(),
      fullname: json['fullname'] as String? ?? '',
      isdeleted: json['isdeleted'] as bool? ?? false,
    );

Map<String, dynamic> _$MoodleForumAuthorToJson(MoodleForumAuthor instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fullname': instance.fullname,
      'isdeleted': instance.isdeleted,
    };

MoodleForumFile _$MoodleForumFileFromJson(Map<String, dynamic> json) =>
    MoodleForumFile(
      filename: json['filename'] as String? ?? '',
      filepath: json['filepath'] as String? ?? '/',
      filesize: (json['filesize'] as num?)?.toInt() ?? 0,
      url: json['url'] as String? ?? '',
      isimage: json['isimage'] as bool? ?? false,
    );

Map<String, dynamic> _$MoodleForumFileToJson(MoodleForumFile instance) =>
    <String, dynamic>{
      'filename': instance.filename,
      'filepath': instance.filepath,
      'filesize': instance.filesize,
      'url': instance.url,
      'isimage': instance.isimage,
    };
