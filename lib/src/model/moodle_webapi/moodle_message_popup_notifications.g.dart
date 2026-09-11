// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moodle_message_popup_notifications.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoodleNotificationList _$MoodleNotificationListFromJson(
        Map<String, dynamic> json) =>
    MoodleNotificationList(
      notifications: (json['notifications'] as List<dynamic>?)
              ?.map(
                  (e) => MoodleNotification.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      unreadcount: (json['unreadcount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$MoodleNotificationListToJson(
        MoodleNotificationList instance) =>
    <String, dynamic>{
      'notifications': instance.notifications.map((e) => e.toJson()).toList(),
      'unreadcount': instance.unreadcount,
    };

MoodleNotification _$MoodleNotificationFromJson(Map<String, dynamic> json) =>
    MoodleNotification(
      id: (json['id'] as num?)?.toInt() ?? 0,
      subject: json['subject'] as String? ?? '',
      text: json['text'] as String? ?? '',
      fullmessage: json['fullmessage'] as String? ?? '',
      fullmessagehtml: json['fullmessagehtml'] as String? ?? '',
      smallmessage: json['smallmessage'] as String? ?? '',
      contexturl: json['contexturl'] as String?,
      contexturlname: json['contexturlname'] as String?,
      timecreated: (json['timecreated'] as num?)?.toInt() ?? 0,
      timeread: (json['timeread'] as num?)?.toInt(),
      read: json['read'] == null ? false : _boolFromJson(json['read']),
      component: json['component'] as String?,
      eventtype: json['eventtype'] as String?,
      customdata: json['customdata'] as String?,
    );

Map<String, dynamic> _$MoodleNotificationToJson(MoodleNotification instance) =>
    <String, dynamic>{
      'id': instance.id,
      'subject': instance.subject,
      'text': instance.text,
      'fullmessage': instance.fullmessage,
      'fullmessagehtml': instance.fullmessagehtml,
      'smallmessage': instance.smallmessage,
      'contexturl': instance.contexturl,
      'contexturlname': instance.contexturlname,
      'timecreated': instance.timecreated,
      'timeread': instance.timeread,
      'read': instance.read,
      'component': instance.component,
      'eventtype': instance.eventtype,
      'customdata': instance.customdata,
    };
