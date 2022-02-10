// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moodle_core_enrol_get_users.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoodleCoreEnrolGetUsers _$MoodleCoreEnrolGetUsersFromJson(
        Map<String, dynamic> json) =>
    MoodleCoreEnrolGetUsers(
      id: json['id'] as int? ?? 0,
      fullName: json['fullname'] as String? ?? "",
      email: json['email'] as String? ?? "",
      description: json['description'] as String? ?? "",
      descriptionFormat: json['descriptionformat'] as int? ?? 0,
      profileImageUrlSmall: json['profileimageurlsmall'] as String? ?? "",
      profileImageUrl: json['profileimageurl'] as String? ?? "",
      roles: (json['roles'] as List<dynamic>?)
          ?.map((e) => Roles.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$MoodleCoreEnrolGetUsersToJson(
        MoodleCoreEnrolGetUsers instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fullname': instance.fullName,
      'email': instance.email,
      'description': instance.description,
      'descriptionformat': instance.descriptionFormat,
      'profileimageurlsmall': instance.profileImageUrlSmall,
      'profileimageurl': instance.profileImageUrl,
      'roles': instance.roles,
    };

Roles _$RolesFromJson(Map<String, dynamic> json) => Roles(
      roleId: json['roleid'] as int? ?? 0,
      name: json['name'] as String? ?? "",
      shortname: json['shortname'] as String? ?? "",
      sortOrder: json['sortorder'] as int? ?? 0,
    );

Map<String, dynamic> _$RolesToJson(Roles instance) => <String, dynamic>{
      'roleid': instance.roleId,
      'name': instance.name,
      'shortname': instance.shortname,
      'sortorder': instance.sortOrder,
    };
