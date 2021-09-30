// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moodle_branch.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoodleBranchJson _$MoodleBranchJsonFromJson(Map<String, dynamic> json) =>
    MoodleBranchJson(
      name: json['name'] as String,
      type: json['type'] as int,
      key: json['key'] as String,
      classs: json['class'] as String,
      requiresajaxloading: json['requiresajaxloading'] as bool,
      icon: MainIcon.fromJson(json['icon'] as Map<String, dynamic>),
      title: json['title'] as String,
      hidden: json['hidden'] as bool,
      haschildren: json['haschildren'] as bool,
      children: (json['children'] as List<dynamic>)
          .map((e) => Children.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

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

MainIcon _$MainIconFromJson(Map<String, dynamic> json) => MainIcon(
      component: json['component'] as String? ?? "",
      pix: json['pix'] as String? ?? "",
      classes:
          (json['classes'] as List<dynamic>?)?.map((e) => e as String).toList(),
      alt: json['alt'] as String? ?? "",
    );

Map<String, dynamic> _$MainIconToJson(MainIcon instance) => <String, dynamic>{
      'component': instance.component,
      'pix': instance.pix,
      'classes': instance.classes,
      'alt': instance.alt,
    };

Children _$ChildrenFromJson(Map<String, dynamic> json) => Children(
      name: json['name'] as String? ?? "",
      type: json['type'] as int? ?? 0,
      key: json['key'] as String? ?? "",
      classs: json['class'] as String? ?? "",
      requiresajaxloading: json['requiresajaxloading'] as bool? ?? false,
      title: json['title'] as String? ?? "",
      link: json['link'] as String? ?? "",
      hidden: json['hidden'] as bool? ?? false,
      haschildren: json['haschildren'] as bool? ?? false,
      contentAfterLink: json['contentAfterLink'] as String?,
      isExpanded: json['isExpanded'] as bool?,
      icon: SubIcon.fromJson(json['icon'] as Map<String, dynamic>),
    );

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
      'contentAfterLink': instance.contentAfterLink,
      'isExpanded': instance.isExpanded,
    };

SubIcon _$SubIconFromJson(Map<String, dynamic> json) => SubIcon(
      component: json['component'] as String? ?? "",
      pix: json['pix'] as String? ?? "",
      classes:
          (json['classes'] as List<dynamic>?)?.map((e) => e as String).toList(),
      alt: json['alt'] as String? ?? "",
      title: json['title'] as String? ?? "",
    );

Map<String, dynamic> _$SubIconToJson(SubIcon instance) => <String, dynamic>{
      'component': instance.component,
      'pix': instance.pix,
      'classes': instance.classes,
      'alt': instance.alt,
      'title': instance.title,
    };
