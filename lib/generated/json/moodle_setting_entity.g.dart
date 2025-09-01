import 'package:flutter_app/generated/json/base/json_convert_content.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_setting_entity.dart';

MoodleSettingEntity $MoodleSettingEntityFromJson(Map<String, dynamic> json) {
  final MoodleSettingEntity moodleSettingEntity = MoodleSettingEntity();
  final MoodleSettingPreferences? preferences = jsonConvert.convert<
      MoodleSettingPreferences>(json['preferences']);
  if (preferences != null) {
    moodleSettingEntity.preferences = preferences;
  }
  final List<dynamic>? warnings = (json['warnings'] as List<dynamic>?)?.map(
          (e) => e).toList();
  if (warnings != null) {
    moodleSettingEntity.warnings = warnings;
  }
  return moodleSettingEntity;
}

Map<String, dynamic> $MoodleSettingEntityToJson(MoodleSettingEntity entity) {
  final Map<String, dynamic> data = <String, dynamic>{};
  data['preferences'] = entity.preferences.toJson();
  data['warnings'] = entity.warnings;
  return data;
}

extension MoodleSettingEntityExtension on MoodleSettingEntity {
  MoodleSettingEntity copyWith({
    MoodleSettingPreferences? preferences,
    List<dynamic>? warnings,
  }) {
    return MoodleSettingEntity()
      ..preferences = preferences ?? this.preferences
      ..warnings = warnings ?? this.warnings;
  }
}

MoodleSettingPreferences $MoodleSettingPreferencesFromJson(
    Map<String, dynamic> json) {
  final MoodleSettingPreferences moodleSettingPreferences = MoodleSettingPreferences();
  final int? userid = jsonConvert.convert<int>(json['userid']);
  if (userid != null) {
    moodleSettingPreferences.userid = userid;
  }
  final int? disableall = jsonConvert.convert<int>(json['disableall']);
  if (disableall != null) {
    moodleSettingPreferences.disableall = disableall;
  }
  final List<
      MoodleSettingPreferencesProcessors>? processors = (json['processors'] as List<
      dynamic>?)?.map(
          (e) =>
      jsonConvert.convert<MoodleSettingPreferencesProcessors>(
          e) as MoodleSettingPreferencesProcessors).toList();
  if (processors != null) {
    moodleSettingPreferences.processors = processors;
  }
  final List<
      MoodleSettingPreferencesComponents>? components = (json['components'] as List<
      dynamic>?)?.map(
          (e) =>
      jsonConvert.convert<MoodleSettingPreferencesComponents>(
          e) as MoodleSettingPreferencesComponents).toList();
  if (components != null) {
    moodleSettingPreferences.components = components;
  }
  return moodleSettingPreferences;
}

Map<String, dynamic> $MoodleSettingPreferencesToJson(
    MoodleSettingPreferences entity) {
  final Map<String, dynamic> data = <String, dynamic>{};
  data['userid'] = entity.userid;
  data['disableall'] = entity.disableall;
  data['processors'] = entity.processors.map((v) => v.toJson()).toList();
  data['components'] = entity.components.map((v) => v.toJson()).toList();
  return data;
}

extension MoodleSettingPreferencesExtension on MoodleSettingPreferences {
  MoodleSettingPreferences copyWith({
    int? userid,
    int? disableall,
    List<MoodleSettingPreferencesProcessors>? processors,
    List<MoodleSettingPreferencesComponents>? components,
  }) {
    return MoodleSettingPreferences()
      ..userid = userid ?? this.userid
      ..disableall = disableall ?? this.disableall
      ..processors = processors ?? this.processors
      ..components = components ?? this.components;
  }
}

MoodleSettingPreferencesProcessors $MoodleSettingPreferencesProcessorsFromJson(
    Map<String, dynamic> json) {
  final MoodleSettingPreferencesProcessors moodleSettingPreferencesProcessors = MoodleSettingPreferencesProcessors();
  final String? displayname = jsonConvert.convert<String>(json['displayname']);
  if (displayname != null) {
    moodleSettingPreferencesProcessors.displayname = displayname;
  }
  final String? name = jsonConvert.convert<String>(json['name']);
  if (name != null) {
    moodleSettingPreferencesProcessors.name = name;
  }
  final bool? hassettings = jsonConvert.convert<bool>(json['hassettings']);
  if (hassettings != null) {
    moodleSettingPreferencesProcessors.hassettings = hassettings;
  }
  final int? contextid = jsonConvert.convert<int>(json['contextid']);
  if (contextid != null) {
    moodleSettingPreferencesProcessors.contextid = contextid;
  }
  final int? userconfigured = jsonConvert.convert<int>(json['userconfigured']);
  if (userconfigured != null) {
    moodleSettingPreferencesProcessors.userconfigured = userconfigured;
  }
  return moodleSettingPreferencesProcessors;
}

Map<String, dynamic> $MoodleSettingPreferencesProcessorsToJson(
    MoodleSettingPreferencesProcessors entity) {
  final Map<String, dynamic> data = <String, dynamic>{};
  data['displayname'] = entity.displayname;
  data['name'] = entity.name;
  data['hassettings'] = entity.hassettings;
  data['contextid'] = entity.contextid;
  data['userconfigured'] = entity.userconfigured;
  return data;
}

extension MoodleSettingPreferencesProcessorsExtension on MoodleSettingPreferencesProcessors {
  MoodleSettingPreferencesProcessors copyWith({
    String? displayname,
    String? name,
    bool? hassettings,
    int? contextid,
    int? userconfigured,
  }) {
    return MoodleSettingPreferencesProcessors()
      ..displayname = displayname ?? this.displayname
      ..name = name ?? this.name
      ..hassettings = hassettings ?? this.hassettings
      ..contextid = contextid ?? this.contextid
      ..userconfigured = userconfigured ?? this.userconfigured;
  }
}

MoodleSettingPreferencesComponents $MoodleSettingPreferencesComponentsFromJson(
    Map<String, dynamic> json) {
  final MoodleSettingPreferencesComponents moodleSettingPreferencesComponents = MoodleSettingPreferencesComponents();
  final String? displayname = jsonConvert.convert<String>(json['displayname']);
  if (displayname != null) {
    moodleSettingPreferencesComponents.displayname = displayname;
  }
  final List<
      MoodleSettingPreferencesComponentsNotifications>? notifications = (json['notifications'] as List<
      dynamic>?)?.map(
          (e) =>
      jsonConvert.convert<
          MoodleSettingPreferencesComponentsNotifications>(
          e) as MoodleSettingPreferencesComponentsNotifications).toList();
  if (notifications != null) {
    moodleSettingPreferencesComponents.notifications = notifications;
  }
  return moodleSettingPreferencesComponents;
}

Map<String, dynamic> $MoodleSettingPreferencesComponentsToJson(
    MoodleSettingPreferencesComponents entity) {
  final Map<String, dynamic> data = <String, dynamic>{};
  data['displayname'] = entity.displayname;
  data['notifications'] = entity.notifications.map((v) => v.toJson()).toList();
  return data;
}

extension MoodleSettingPreferencesComponentsExtension on MoodleSettingPreferencesComponents {
  MoodleSettingPreferencesComponents copyWith({
    String? displayname,
    List<MoodleSettingPreferencesComponentsNotifications>? notifications,
  }) {
    return MoodleSettingPreferencesComponents()
      ..displayname = displayname ?? this.displayname
      ..notifications = notifications ?? this.notifications;
  }
}

MoodleSettingPreferencesComponentsNotifications $MoodleSettingPreferencesComponentsNotificationsFromJson(
    Map<String, dynamic> json) {
  final MoodleSettingPreferencesComponentsNotifications moodleSettingPreferencesComponentsNotifications = MoodleSettingPreferencesComponentsNotifications();
  final String? displayname = jsonConvert.convert<String>(json['displayname']);
  if (displayname != null) {
    moodleSettingPreferencesComponentsNotifications.displayname = displayname;
  }
  final String? preferencekey = jsonConvert.convert<String>(
      json['preferencekey']);
  if (preferencekey != null) {
    moodleSettingPreferencesComponentsNotifications.preferencekey =
        preferencekey;
  }
  final List<
      MoodleSettingPreferencesComponentsNotificationsProcessors>? processors = (json['processors'] as List<
      dynamic>?)
      ?.map(
          (e) =>
      jsonConvert.convert<
          MoodleSettingPreferencesComponentsNotificationsProcessors>(
          e) as MoodleSettingPreferencesComponentsNotificationsProcessors)
      .toList();
  if (processors != null) {
    moodleSettingPreferencesComponentsNotifications.processors = processors;
  }
  return moodleSettingPreferencesComponentsNotifications;
}

Map<String, dynamic> $MoodleSettingPreferencesComponentsNotificationsToJson(
    MoodleSettingPreferencesComponentsNotifications entity) {
  final Map<String, dynamic> data = <String, dynamic>{};
  data['displayname'] = entity.displayname;
  data['preferencekey'] = entity.preferencekey;
  data['processors'] = entity.processors.map((v) => v.toJson()).toList();
  return data;
}

extension MoodleSettingPreferencesComponentsNotificationsExtension on MoodleSettingPreferencesComponentsNotifications {
  MoodleSettingPreferencesComponentsNotifications copyWith({
    String? displayname,
    String? preferencekey,
    List<MoodleSettingPreferencesComponentsNotificationsProcessors>? processors,
  }) {
    return MoodleSettingPreferencesComponentsNotifications()
      ..displayname = displayname ?? this.displayname
      ..preferencekey = preferencekey ?? this.preferencekey
      ..processors = processors ?? this.processors;
  }
}

MoodleSettingPreferencesComponentsNotificationsProcessors $MoodleSettingPreferencesComponentsNotificationsProcessorsFromJson(
    Map<String, dynamic> json) {
  final MoodleSettingPreferencesComponentsNotificationsProcessors moodleSettingPreferencesComponentsNotificationsProcessors = MoodleSettingPreferencesComponentsNotificationsProcessors();
  final String? displayname = jsonConvert.convert<String>(json['displayname']);
  if (displayname != null) {
    moodleSettingPreferencesComponentsNotificationsProcessors.displayname =
        displayname;
  }
  final String? name = jsonConvert.convert<String>(json['name']);
  if (name != null) {
    moodleSettingPreferencesComponentsNotificationsProcessors.name = name;
  }
  final bool? locked = jsonConvert.convert<bool>(json['locked']);
  if (locked != null) {
    moodleSettingPreferencesComponentsNotificationsProcessors.locked = locked;
  }
  final int? userconfigured = jsonConvert.convert<int>(json['userconfigured']);
  if (userconfigured != null) {
    moodleSettingPreferencesComponentsNotificationsProcessors.userconfigured =
        userconfigured;
  }
  final MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedin? loggedin = jsonConvert
      .convert<
      MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedin>(
      json['loggedin']);
  if (loggedin != null) {
    moodleSettingPreferencesComponentsNotificationsProcessors.loggedin =
        loggedin;
  }
  final MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff? loggedoff = jsonConvert
      .convert<
      MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff>(
      json['loggedoff']);
  if (loggedoff != null) {
    moodleSettingPreferencesComponentsNotificationsProcessors.loggedoff =
        loggedoff;
  }
  final bool? enabled = jsonConvert.convert<bool>(json['enabled']);
  if (enabled != null) {
    moodleSettingPreferencesComponentsNotificationsProcessors.enabled = enabled;
  }
  return moodleSettingPreferencesComponentsNotificationsProcessors;
}

Map<String,
    dynamic> $MoodleSettingPreferencesComponentsNotificationsProcessorsToJson(
    MoodleSettingPreferencesComponentsNotificationsProcessors entity) {
  final Map<String, dynamic> data = <String, dynamic>{};
  data['displayname'] = entity.displayname;
  data['name'] = entity.name;
  data['locked'] = entity.locked;
  data['userconfigured'] = entity.userconfigured;
  data['loggedin'] = entity.loggedin.toJson();
  data['loggedoff'] = entity.loggedoff.toJson();
  data['enabled'] = entity.enabled;
  return data;
}

extension MoodleSettingPreferencesComponentsNotificationsProcessorsExtension on MoodleSettingPreferencesComponentsNotificationsProcessors {
  MoodleSettingPreferencesComponentsNotificationsProcessors copyWith({
    String? displayname,
    String? name,
    bool? locked,
    int? userconfigured,
    MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedin? loggedin,
    MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff? loggedoff,
    bool? enabled,
  }) {
    return MoodleSettingPreferencesComponentsNotificationsProcessors()
      ..displayname = displayname ?? this.displayname
      ..name = name ?? this.name
      ..locked = locked ?? this.locked
      ..userconfigured = userconfigured ?? this.userconfigured
      ..loggedin = loggedin ?? this.loggedin
      ..loggedoff = loggedoff ?? this.loggedoff
      ..enabled = enabled ?? this.enabled;
  }
}

MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedin $MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedinFromJson(
    Map<String, dynamic> json) {
  final MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedin moodleSettingPreferencesComponentsNotificationsProcessorsLoggedin = MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedin();
  final String? name = jsonConvert.convert<String>(json['name']);
  if (name != null) {
    moodleSettingPreferencesComponentsNotificationsProcessorsLoggedin.name =
        name;
  }
  final String? displayname = jsonConvert.convert<String>(json['displayname']);
  if (displayname != null) {
    moodleSettingPreferencesComponentsNotificationsProcessorsLoggedin
        .displayname = displayname;
  }
  final bool? checked = jsonConvert.convert<bool>(json['checked']);
  if (checked != null) {
    moodleSettingPreferencesComponentsNotificationsProcessorsLoggedin.checked =
        checked;
  }
  return moodleSettingPreferencesComponentsNotificationsProcessorsLoggedin;
}

Map<String,
    dynamic> $MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedinToJson(
    MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedin entity) {
  final Map<String, dynamic> data = <String, dynamic>{};
  data['name'] = entity.name;
  data['displayname'] = entity.displayname;
  data['checked'] = entity.checked;
  return data;
}

extension MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedinExtension on MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedin {
  MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedin copyWith({
    String? name,
    String? displayname,
    bool? checked,
  }) {
    return MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedin()
      ..name = name ?? this.name
      ..displayname = displayname ?? this.displayname
      ..checked = checked ?? this.checked;
  }
}

MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff $MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoffFromJson(
    Map<String, dynamic> json) {
  final MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff moodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff = MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff();
  final String? name = jsonConvert.convert<String>(json['name']);
  if (name != null) {
    moodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff.name =
        name;
  }
  final String? displayname = jsonConvert.convert<String>(json['displayname']);
  if (displayname != null) {
    moodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff
        .displayname = displayname;
  }
  final bool? checked = jsonConvert.convert<bool>(json['checked']);
  if (checked != null) {
    moodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff.checked =
        checked;
  }
  return moodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff;
}

Map<String,
    dynamic> $MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoffToJson(
    MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff entity) {
  final Map<String, dynamic> data = <String, dynamic>{};
  data['name'] = entity.name;
  data['displayname'] = entity.displayname;
  data['checked'] = entity.checked;
  return data;
}

extension MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoffExtension on MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff {
  MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff copyWith({
    String? name,
    String? displayname,
    bool? checked,
  }) {
    return MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff()
      ..name = name ?? this.name
      ..displayname = displayname ?? this.displayname
      ..checked = checked ?? this.checked;
  }
}