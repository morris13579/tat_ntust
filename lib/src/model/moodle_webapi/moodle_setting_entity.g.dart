// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moodle_setting_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoodleSettingEntity _$MoodleSettingEntityFromJson(Map<String, dynamic> json) =>
    MoodleSettingEntity(
      preferences: MoodleSettingPreferences.fromJson(
          json['preferences'] as Map<String, dynamic>),
      warnings: json['warnings'] as List<dynamic>? ?? [],
    );

Map<String, dynamic> _$MoodleSettingEntityToJson(
        MoodleSettingEntity instance) =>
    <String, dynamic>{
      'preferences': instance.preferences.toJson(),
      'warnings': instance.warnings,
    };

MoodleSettingPreferences _$MoodleSettingPreferencesFromJson(
        Map<String, dynamic> json) =>
    MoodleSettingPreferences(
      userid: (json['userid'] as num?)?.toInt() ?? 0,
      disableall: (json['disableall'] as num?)?.toInt() ?? 0,
      processors: (json['processors'] as List<dynamic>?)
              ?.map((e) => MoodleSettingPreferencesProcessors.fromJson(
                  e as Map<String, dynamic>))
              .toList() ??
          [],
      components: (json['components'] as List<dynamic>?)
              ?.map((e) => MoodleSettingPreferencesComponents.fromJson(
                  e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$MoodleSettingPreferencesToJson(
        MoodleSettingPreferences instance) =>
    <String, dynamic>{
      'userid': instance.userid,
      'disableall': instance.disableall,
      'processors': instance.processors.map((e) => e.toJson()).toList(),
      'components': instance.components.map((e) => e.toJson()).toList(),
    };

MoodleSettingPreferencesProcessors _$MoodleSettingPreferencesProcessorsFromJson(
        Map<String, dynamic> json) =>
    MoodleSettingPreferencesProcessors(
      displayname: json['displayname'] as String? ?? '',
      name: json['name'] as String? ?? '',
      hassettings: json['hassettings'] as bool? ?? false,
      contextid: (json['contextid'] as num?)?.toInt() ?? 0,
      userconfigured: (json['userconfigured'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$MoodleSettingPreferencesProcessorsToJson(
        MoodleSettingPreferencesProcessors instance) =>
    <String, dynamic>{
      'displayname': instance.displayname,
      'name': instance.name,
      'hassettings': instance.hassettings,
      'contextid': instance.contextid,
      'userconfigured': instance.userconfigured,
    };

MoodleSettingPreferencesComponents _$MoodleSettingPreferencesComponentsFromJson(
        Map<String, dynamic> json) =>
    MoodleSettingPreferencesComponents(
      displayname: json['displayname'] as String? ?? '',
      notifications: (json['notifications'] as List<dynamic>?)
              ?.map((e) =>
                  MoodleSettingPreferencesComponentsNotifications.fromJson(
                      e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$MoodleSettingPreferencesComponentsToJson(
        MoodleSettingPreferencesComponents instance) =>
    <String, dynamic>{
      'displayname': instance.displayname,
      'notifications': instance.notifications.map((e) => e.toJson()).toList(),
    };

MoodleSettingPreferencesComponentsNotifications
    _$MoodleSettingPreferencesComponentsNotificationsFromJson(
            Map<String, dynamic> json) =>
        MoodleSettingPreferencesComponentsNotifications(
          displayname: json['displayname'] as String? ?? '',
          preferencekey: json['preferencekey'] as String? ?? '',
          processors: (json['processors'] as List<dynamic>?)
                  ?.map((e) =>
                      MoodleSettingPreferencesComponentsNotificationsProcessors
                          .fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [],
        );

Map<String, dynamic> _$MoodleSettingPreferencesComponentsNotificationsToJson(
        MoodleSettingPreferencesComponentsNotifications instance) =>
    <String, dynamic>{
      'displayname': instance.displayname,
      'preferencekey': instance.preferencekey,
      'processors': instance.processors.map((e) => e.toJson()).toList(),
    };

MoodleSettingPreferencesComponentsNotificationsProcessors
    _$MoodleSettingPreferencesComponentsNotificationsProcessorsFromJson(
            Map<String, dynamic> json) =>
        MoodleSettingPreferencesComponentsNotificationsProcessors(
          displayname: json['displayname'] as String? ?? '',
          name: json['name'] as String? ?? '',
          locked: json['locked'] as bool? ?? false,
          userconfigured: (json['userconfigured'] as num?)?.toInt() ?? 0,
          loggedin: json['loggedin'] == null
              ? null
              : MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedin
                  .fromJson(json['loggedin'] as Map<String, dynamic>),
          loggedoff: json['loggedoff'] == null
              ? null
              : MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff
                  .fromJson(json['loggedoff'] as Map<String, dynamic>),
          enabled: json['enabled'] as bool? ?? false,
        );

Map<String,
    dynamic> _$MoodleSettingPreferencesComponentsNotificationsProcessorsToJson(
        MoodleSettingPreferencesComponentsNotificationsProcessors instance) =>
    <String, dynamic>{
      'displayname': instance.displayname,
      'name': instance.name,
      'locked': instance.locked,
      'userconfigured': instance.userconfigured,
      'loggedin': instance.loggedin?.toJson(),
      'loggedoff': instance.loggedoff?.toJson(),
      'enabled': instance.enabled,
    };

MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedin
    _$MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedinFromJson(
            Map<String, dynamic> json) =>
        MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedin(
          name: json['name'] as String? ?? '',
          displayname: json['displayname'] as String? ?? '',
          checked: json['checked'] as bool? ?? false,
        );

Map<String, dynamic>
    _$MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedinToJson(
            MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedin
                instance) =>
        <String, dynamic>{
          'name': instance.name,
          'displayname': instance.displayname,
          'checked': instance.checked,
        };

MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff
    _$MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoffFromJson(
            Map<String, dynamic> json) =>
        MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff(
          name: json['name'] as String? ?? '',
          displayname: json['displayname'] as String? ?? '',
          checked: json['checked'] as bool? ?? false,
        );

Map<String, dynamic>
    _$MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoffToJson(
            MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff
                instance) =>
        <String, dynamic>{
          'name': instance.name,
          'displayname': instance.displayname,
          'checked': instance.checked,
        };
