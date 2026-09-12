// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mail_message_json.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MailMessageJson _$MailMessageJsonFromJson(Map<String, dynamic> json) =>
    MailMessageJson(
      uid: (json['uid'] as num).toInt(),
      subject: json['subject'] as String? ?? "",
      fromName: json['fromName'] as String? ?? "",
      fromEmail: json['fromEmail'] as String? ?? "",
      dateMillis: (json['dateMillis'] as num?)?.toInt() ?? 0,
      seen: json['seen'] as bool? ?? false,
      to: (json['to'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      cc: (json['cc'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
    );

Map<String, dynamic> _$MailMessageJsonToJson(MailMessageJson instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'subject': instance.subject,
      'fromName': instance.fromName,
      'fromEmail': instance.fromEmail,
      'dateMillis': instance.dateMillis,
      'seen': instance.seen,
      'to': instance.to,
      'cc': instance.cc,
    };
