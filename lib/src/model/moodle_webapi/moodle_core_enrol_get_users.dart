import 'package:json_annotation/json_annotation.dart';

part 'moodle_core_enrol_get_users.g.dart';

@JsonSerializable()
class MoodleCoreEnrolGetUsers {
  @JsonKey(name: 'id')
  int id;

  @JsonKey(name: 'fullname')
  String fullName;

  @JsonKey(name: 'email')
  String email;

  @JsonKey(name: 'description')
  String description;

  @JsonKey(name: 'descriptionformat')
  int descriptionFormat;

  @JsonKey(name: 'profileimageurlsmall')
  String profileImageUrlSmall;

  @JsonKey(name: 'profileimageurl')
  String profileImageUrl;

  @JsonKey(name: 'roles')
  late List<Roles> roles;

  get studentId {
    List<String> c = fullName.split("@");
    return c.first.replaceAll(" ", "");
  }

  get name {
    List<String> c = fullName.split("@");
    return c.last.replaceAll(" ", "");
  }

  MoodleCoreEnrolGetUsers(
      {this.id = 0,
      this.fullName = "",
      this.email = "",
      this.description = "",
      this.descriptionFormat = 0,
      this.profileImageUrlSmall = "",
      this.profileImageUrl = "",
      List<Roles>? roles}) {
    this.roles = roles ?? [];
  }

  factory MoodleCoreEnrolGetUsers.fromJson(Map<String, dynamic> srcJson) =>
      _$MoodleCoreEnrolGetUsersFromJson(srcJson);
}

@JsonSerializable()
class Roles {
  @JsonKey(name: 'roleid')
  int roleId;

  @JsonKey(name: 'name')
  String name;

  @JsonKey(name: 'shortname')
  String shortname;

  @JsonKey(name: 'sortorder')
  int sortOrder;

  Roles({
    this.roleId = 0,
    this.name = "",
    this.shortname = "",
    this.sortOrder = 0,
  });

  factory Roles.fromJson(Map<String, dynamic> srcJson) =>
      _$RolesFromJson(srcJson);
}
