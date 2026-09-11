import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'moodle_setting_entity.g.dart';

/// core_message_get_user_notification_preferences 的回應。
///
/// 純量欄位一律「缺 key 就退回預設值」。
///
/// [preferences] 例外，刻意必填：缺席時要在解析當下就失敗，`getSettings()`
/// 的 try/catch 才會回 null 讓設定頁顯示錯誤，而不是等到讀 `components`
/// 時才拋在離原因很遠的地方。
@JsonSerializable(explicitToJson: true)
class MoodleSettingEntity {
  MoodleSettingPreferences preferences;
  @JsonKey(defaultValue: [])
  List<dynamic> warnings;

  MoodleSettingEntity({required this.preferences, this.warnings = const []});

  factory MoodleSettingEntity.fromJson(Map<String, dynamic> json) =>
      _$MoodleSettingEntityFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleSettingEntityToJson(this);

  @override
  String toString() => jsonEncode(this);
}

@JsonSerializable(explicitToJson: true)
class MoodleSettingPreferences {
  @JsonKey(defaultValue: 0)
  int userid;
  @JsonKey(defaultValue: 0)
  int disableall;
  @JsonKey(defaultValue: [])
  List<MoodleSettingPreferencesProcessors> processors;
  @JsonKey(defaultValue: [])
  List<MoodleSettingPreferencesComponents> components;

  MoodleSettingPreferences({
    this.userid = 0,
    this.disableall = 0,
    this.processors = const [],
    this.components = const [],
  });

  factory MoodleSettingPreferences.fromJson(Map<String, dynamic> json) =>
      _$MoodleSettingPreferencesFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleSettingPreferencesToJson(this);

  @override
  String toString() => jsonEncode(this);
}

@JsonSerializable()
class MoodleSettingPreferencesProcessors {
  @JsonKey(defaultValue: '')
  String displayname;
  @JsonKey(defaultValue: '')
  String name;
  @JsonKey(defaultValue: false)
  bool hassettings;
  @JsonKey(defaultValue: 0)
  int contextid;
  @JsonKey(defaultValue: 0)
  int userconfigured;

  MoodleSettingPreferencesProcessors({
    this.displayname = '',
    this.name = '',
    this.hassettings = false,
    this.contextid = 0,
    this.userconfigured = 0,
  });

  factory MoodleSettingPreferencesProcessors.fromJson(
          Map<String, dynamic> json) =>
      _$MoodleSettingPreferencesProcessorsFromJson(json);

  Map<String, dynamic> toJson() =>
      _$MoodleSettingPreferencesProcessorsToJson(this);

  @override
  String toString() => jsonEncode(this);
}

@JsonSerializable(explicitToJson: true)
class MoodleSettingPreferencesComponents {
  @JsonKey(defaultValue: '')
  String displayname;
  @JsonKey(defaultValue: [])
  List<MoodleSettingPreferencesComponentsNotifications> notifications;

  MoodleSettingPreferencesComponents({
    this.displayname = '',
    this.notifications = const [],
  });

  factory MoodleSettingPreferencesComponents.fromJson(
          Map<String, dynamic> json) =>
      _$MoodleSettingPreferencesComponentsFromJson(json);

  Map<String, dynamic> toJson() =>
      _$MoodleSettingPreferencesComponentsToJson(this);

  @override
  String toString() => jsonEncode(this);
}

@JsonSerializable(explicitToJson: true)
class MoodleSettingPreferencesComponentsNotifications {
  @JsonKey(defaultValue: '')
  String displayname;
  @JsonKey(defaultValue: '')
  String preferencekey;
  @JsonKey(defaultValue: [])
  List<MoodleSettingPreferencesComponentsNotificationsProcessors> processors;

  MoodleSettingPreferencesComponentsNotifications({
    this.displayname = '',
    this.preferencekey = '',
    this.processors = const [],
  });

  factory MoodleSettingPreferencesComponentsNotifications.fromJson(
          Map<String, dynamic> json) =>
      _$MoodleSettingPreferencesComponentsNotificationsFromJson(json);

  Map<String, dynamic> toJson() =>
      _$MoodleSettingPreferencesComponentsNotificationsToJson(this);

  @override
  String toString() => jsonEncode(this);
}

@JsonSerializable(explicitToJson: true)
class MoodleSettingPreferencesComponentsNotificationsProcessors {
  @JsonKey(defaultValue: '')
  String displayname;
  @JsonKey(defaultValue: '')
  String name;
  @JsonKey(defaultValue: false)
  bool locked;
  @JsonKey(defaultValue: 0)
  int userconfigured;

  /// **必須可為 null。** 臺科的 Moodle 對部分 processor 這兩個欄位就是送
  /// `null`，寫成必填會讓整個「Moodle 設定」頁變成錯誤畫面。不要比照
  /// [MoodleSettingEntity.preferences]：那個缺席代表整包回應沒有意義，
  /// 這兩個是 per-processor 的選用欄位，缺席是正常的。
  ///
  /// 目前沒有任何地方讀取它們，保留只是為了完整對映回應。
  MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedin? loggedin;
  MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff? loggedoff;
  @JsonKey(defaultValue: false)
  bool enabled;

  MoodleSettingPreferencesComponentsNotificationsProcessors({
    this.displayname = '',
    this.name = '',
    this.locked = false,
    this.userconfigured = 0,
    this.loggedin,
    this.loggedoff,
    this.enabled = false,
  });

  factory MoodleSettingPreferencesComponentsNotificationsProcessors.fromJson(
          Map<String, dynamic> json) =>
      _$MoodleSettingPreferencesComponentsNotificationsProcessorsFromJson(json);

  Map<String, dynamic> toJson() =>
      _$MoodleSettingPreferencesComponentsNotificationsProcessorsToJson(this);

  @override
  String toString() => jsonEncode(this);
}

@JsonSerializable()
class MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedin {
  @JsonKey(defaultValue: '')
  String name;
  @JsonKey(defaultValue: '')
  String displayname;
  @JsonKey(defaultValue: false)
  bool checked;

  MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedin({
    this.name = '',
    this.displayname = '',
    this.checked = false,
  });

  factory MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedin.fromJson(
          Map<String, dynamic> json) =>
      _$MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedinFromJson(
          json);

  Map<String, dynamic> toJson() =>
      _$MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedinToJson(
          this);

  @override
  String toString() => jsonEncode(this);
}

@JsonSerializable()
class MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff {
  @JsonKey(defaultValue: '')
  String name;
  @JsonKey(defaultValue: '')
  String displayname;
  @JsonKey(defaultValue: false)
  bool checked;

  MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff({
    this.name = '',
    this.displayname = '',
    this.checked = false,
  });

  factory MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff.fromJson(
          Map<String, dynamic> json) =>
      _$MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoffFromJson(
          json);

  Map<String, dynamic> toJson() =>
      _$MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoffToJson(
          this);

  @override
  String toString() => jsonEncode(this);
}
