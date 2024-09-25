import 'package:flutter_app/generated/json/base/json_field.dart';
import 'package:flutter_app/generated/json/moodle_setting_entity.g.dart';
import 'dart:convert';
export 'package:flutter_app/generated/json/moodle_setting_entity.g.dart';

@JsonSerializable()
class MoodleSettingEntity {
	late MoodleSettingPreferences preferences;
	late List<dynamic> warnings = [];

	MoodleSettingEntity();

	factory MoodleSettingEntity.fromJson(Map<String, dynamic> json) => $MoodleSettingEntityFromJson(json);

	Map<String, dynamic> toJson() => $MoodleSettingEntityToJson(this);

	@override
	String toString() {
		return jsonEncode(this);
	}
}

@JsonSerializable()
class MoodleSettingPreferences {
	late int userid = 0;
	late int disableall = 0;
	late List<MoodleSettingPreferencesProcessors> processors = [];
	late List<MoodleSettingPreferencesComponents> components = [];

	MoodleSettingPreferences();

	factory MoodleSettingPreferences.fromJson(Map<String, dynamic> json) => $MoodleSettingPreferencesFromJson(json);

	Map<String, dynamic> toJson() => $MoodleSettingPreferencesToJson(this);

	@override
	String toString() {
		return jsonEncode(this);
	}
}

@JsonSerializable()
class MoodleSettingPreferencesProcessors {
	late String displayname = "";
	late String name = "";
	late bool hassettings = false;
	late int contextid = 0;
	late int userconfigured = 0;

	MoodleSettingPreferencesProcessors();

	factory MoodleSettingPreferencesProcessors.fromJson(Map<String, dynamic> json) => $MoodleSettingPreferencesProcessorsFromJson(json);

	Map<String, dynamic> toJson() => $MoodleSettingPreferencesProcessorsToJson(this);

	@override
	String toString() {
		return jsonEncode(this);
	}
}

@JsonSerializable()
class MoodleSettingPreferencesComponents {
	late String displayname = "";
	late List<MoodleSettingPreferencesComponentsNotifications> notifications = [];

	MoodleSettingPreferencesComponents();

	factory MoodleSettingPreferencesComponents.fromJson(Map<String, dynamic> json) => $MoodleSettingPreferencesComponentsFromJson(json);

	Map<String, dynamic> toJson() => $MoodleSettingPreferencesComponentsToJson(this);

	@override
	String toString() {
		return jsonEncode(this);
	}
}

@JsonSerializable()
class MoodleSettingPreferencesComponentsNotifications {
	late String displayname = "";
	late String preferencekey = "";
	late List<MoodleSettingPreferencesComponentsNotificationsProcessors> processors = [];

	MoodleSettingPreferencesComponentsNotifications();

	factory MoodleSettingPreferencesComponentsNotifications.fromJson(Map<String, dynamic> json) => $MoodleSettingPreferencesComponentsNotificationsFromJson(json);

	Map<String, dynamic> toJson() => $MoodleSettingPreferencesComponentsNotificationsToJson(this);

	@override
	String toString() {
		return jsonEncode(this);
	}
}

@JsonSerializable()
class MoodleSettingPreferencesComponentsNotificationsProcessors {
	late String displayname = "";
	late String name = "";
	late bool locked = false;
	late int userconfigured = 0;
	late MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedin loggedin;
	late MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff loggedoff;
	late bool enabled = false;

	MoodleSettingPreferencesComponentsNotificationsProcessors();

	factory MoodleSettingPreferencesComponentsNotificationsProcessors.fromJson(Map<String, dynamic> json) => $MoodleSettingPreferencesComponentsNotificationsProcessorsFromJson(json);

	Map<String, dynamic> toJson() => $MoodleSettingPreferencesComponentsNotificationsProcessorsToJson(this);

	@override
	String toString() {
		return jsonEncode(this);
	}
}

@JsonSerializable()
class MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedin {
	late String name = "";
	late String displayname = "";
	late bool checked = false;

	MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedin();

	factory MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedin.fromJson(Map<String, dynamic> json) => $MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedinFromJson(json);

	Map<String, dynamic> toJson() => $MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedinToJson(this);

	@override
	String toString() {
		return jsonEncode(this);
	}
}

@JsonSerializable()
class MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff {
	late String name = "";
	late String displayname = "";
	late bool checked = false;

	MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff();

	factory MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff.fromJson(Map<String, dynamic> json) => $MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoffFromJson(json);

	Map<String, dynamic> toJson() => $MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoffToJson(this);

	@override
	String toString() {
		return jsonEncode(this);
	}
}