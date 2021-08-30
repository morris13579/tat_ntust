// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moodle_branch.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoodleBranchJson _$MoodleBranchJsonFromJson(Map<String, dynamic> json) {
  return MoodleBranchJson(
    name: json['name'] as String,
    type: json['type'] as int,
    key: json['key'] as String,
    classs: json['class'] as String,
    requiresajaxloading: json['requiresajaxloading'] as bool,
    icon: json['icon'] == null
        ? null
        : MainIcon.fromJson(json['icon'] as Map<String, dynamic>),
    title: json['title'] as String,
    hidden: json['hidden'] as bool,
    haschildren: json['haschildren'] as bool,
    children: (json['children'] as List)
        ?.map((e) => (e == null || e == "")
            ? null
            : Children.fromJson(e as Map<String, dynamic>))
        ?.toList(),
  );
}

Map<String, dynamic> _$MoodleBranchJsonToJson(MoodleBranchJson instance) =>
    <String, dynamic>{
      'name': instance.name,
      'type': instance.type,
      'key': instance.key,
      'class': instance.classs,
      'requiresajaxloading': instance.requiresajaxloading,
      'icon': instance.icon,
      'title': instance.title,
      'hidden': instance.hidden,
      'haschildren': instance.haschildren,
      'children': instance.children,
    };

MainIcon _$MainIconFromJson(Map<String, dynamic> json) {
  return MainIcon(
    json['component'] as String,
    json['pix'] as String,
    (json['classes'] as List)?.map((e) => e as String)?.toList(),
    json['alt'] as String,
  );
}

Map<String, dynamic> _$MainIconToJson(MainIcon instance) => <String, dynamic>{
      'component': instance.component,
      'pix': instance.pix,
      'classes': instance.classes,
      'alt': instance.alt,
    };

Children _$ChildrenFromJson(Map<String, dynamic> json) {
  return Children(
    json['name'] as String,
    json['type'] as int,
    json['key'] as String,
    json['class'] as String,
    json['requiresajaxloading'] as bool,
    json['icon'] == null
        ? null
        : SubIcon.fromJson(json['icon'] as Map<String, dynamic>),
    json['title'] as String,
    json['link'] as String,
    json['hidden'] as bool,
    json['haschildren'] as bool,
  );
}

Map<String, dynamic> _$ChildrenToJson(Children instance) => <String, dynamic>{
      'name': instance.name,
      'type': instance.type,
      'key': instance.key,
      'class': instance.classs,
      'requiresajaxloading': instance.requiresajaxloading,
      'icon': instance.icon,
      'title': instance.title,
      'link': instance.link,
      'hidden': instance.hidden,
      'haschildren': instance.haschildren,
    };

SubIcon _$SubIconFromJson(Map<String, dynamic> json) {
  return SubIcon(
    json['component'] as String,
    json['pix'] as String,
    (json['classes'] as List)?.map((e) => e as String)?.toList(),
    json['alt'] as String,
    json['title'] as String,
  );
}

Map<String, dynamic> _$SubIconToJson(SubIcon instance) => <String, dynamic>{
      'component': instance.component,
      'pix': instance.pix,
      'classes': instance.classes,
      'alt': instance.alt,
      'title': instance.title,
    };
