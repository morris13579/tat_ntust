// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mail_folder_json.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MailFolderJson _$MailFolderJsonFromJson(Map<String, dynamic> json) =>
    MailFolderJson(
      path: json['path'] as String,
      name: json['name'] as String,
      role: $enumDecodeNullable(_$MailFolderRoleEnumMap, json['role']) ??
          MailFolderRole.other,
      messageCount: (json['messageCount'] as num?)?.toInt() ?? -1,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? -1,
    );

Map<String, dynamic> _$MailFolderJsonToJson(MailFolderJson instance) =>
    <String, dynamic>{
      'path': instance.path,
      'name': instance.name,
      'role': _$MailFolderRoleEnumMap[instance.role]!,
      'messageCount': instance.messageCount,
      'unreadCount': instance.unreadCount,
    };

const _$MailFolderRoleEnumMap = {
  MailFolderRole.inbox: 'inbox',
  MailFolderRole.sent: 'sent',
  MailFolderRole.drafts: 'drafts',
  MailFolderRole.trash: 'trash',
  MailFolderRole.junk: 'junk',
  MailFolderRole.archive: 'archive',
  MailFolderRole.other: 'other',
};
