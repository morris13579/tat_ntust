import 'package:flutter_app/generated/json/base/json_field.dart';
import 'package:flutter_app/generated/json/moodle_profile_entity.g.dart';
import 'dart:convert';
export 'package:flutter_app/generated/json/moodle_profile_entity.g.dart';

@JsonSerializable()
class MoodleProfileEntity {
	late String sitename = "";
	late String username = "";
	late String firstname = "";
	late String lastname = "";
	late String fullname = "";
	late String lang = "";
	late int userid = 0;
	late String siteurl = "";
	late String userpictureurl = "";
	late List<MoodleProfileFunctions> functions = [];
	late int downloadfiles = 0;
	late int uploadfiles = 0;
	late String release = "";
	late String version = "";
	late String mobilecssurl = "";
	late List<MoodleProfileAdvancedfeatures> advancedfeatures = [];
	late bool usercanmanageownfiles = false;
	late int userquota = 0;
	late int usermaxuploadfilesize = 0;
	late int userhomepage = 0;
	late String userprivateaccesskey = "";
	late int siteid = 0;
	late String sitecalendartype = "";
	late String usercalendartype = "";
	late bool userissiteadmin = false;
	late String theme = "";
	late int limitconcurrentlogins = 0;

	MoodleProfileEntity();

	factory MoodleProfileEntity.fromJson(Map<String, dynamic> json) => $MoodleProfileEntityFromJson(json);

	Map<String, dynamic> toJson() => $MoodleProfileEntityToJson(this);

	@override
	String toString() {
		return jsonEncode(this);
	}
}

@JsonSerializable()
class MoodleProfileFunctions {
	late String name = "";
	late String version = "";

	MoodleProfileFunctions();

	factory MoodleProfileFunctions.fromJson(Map<String, dynamic> json) => $MoodleProfileFunctionsFromJson(json);

	Map<String, dynamic> toJson() => $MoodleProfileFunctionsToJson(this);

	@override
	String toString() {
		return jsonEncode(this);
	}
}

@JsonSerializable()
class MoodleProfileAdvancedfeatures {
	late String name = "";
	late int value = 0;

	MoodleProfileAdvancedfeatures();

	factory MoodleProfileAdvancedfeatures.fromJson(Map<String, dynamic> json) => $MoodleProfileAdvancedfeaturesFromJson(json);

	Map<String, dynamic> toJson() => $MoodleProfileAdvancedfeaturesToJson(this);

	@override
	String toString() {
		return jsonEncode(this);
	}
}