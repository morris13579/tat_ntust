import 'dart:convert';

import 'package:flutter_app/debug/log/Log.dart';
import 'package:json_annotation/json_annotation.dart';

part 'moodle_branch.g.dart';

@JsonSerializable()
class MoodleBranchJson extends Object {
  @JsonKey(name: 'name')
  String name;

  @JsonKey(name: 'type')
  int type;

  @JsonKey(name: 'key')
  String key;

  @JsonKey(name: 'class')
  String classs;

  @JsonKey(name: 'requiresajaxloading')
  bool requiresajaxloading;

  @JsonKey(name: 'icon')
  MainIcon icon;

  @JsonKey(name: 'title')
  String title;

  @JsonKey(name: 'hidden')
  bool hidden;

  @JsonKey(name: 'haschildren')
  bool haschildren;

  @JsonKey(name: 'children')
  List<Children> children;

  /*
    children: (json['children'] as List)
        ?.map((e) => (e == null || e == "")
            ? null
            : Children.fromJson(e as Map<String, dynamic>))
        ?.toList(),
   */

  MoodleBranchJson(
      {this.name,
      this.type,
      this.key,
      this.classs,
      this.requiresajaxloading,
      this.icon,
      this.title,
      this.hidden,
      this.haschildren,
      this.children});

  factory MoodleBranchJson.fromJson(Map<String, dynamic> srcJson) =>
      _$MoodleBranchJsonFromJson(srcJson);
}

@JsonSerializable()
class MainIcon extends Object {
  @JsonKey(name: 'component')
  String component;

  @JsonKey(name: 'pix')
  String pix;

  @JsonKey(name: 'classes')
  List<String> classes;

  @JsonKey(name: 'alt')
  String alt;

  MainIcon(
    this.component,
    this.pix,
    this.classes,
    this.alt,
  );

  factory MainIcon.fromJson(Map<String, dynamic> srcJson) =>
      _$MainIconFromJson(srcJson);
}

@JsonSerializable()
class Children extends Object {
  @JsonKey(name: 'name')
  String name;

  @JsonKey(name: 'type')
  int type;

  @JsonKey(name: 'key')
  String key;

  @JsonKey(name: 'class')
  String classs;

  @JsonKey(name: 'requiresajaxloading')
  bool requiresajaxloading;

  @JsonKey(name: 'icon')
  SubIcon icon;

  @JsonKey(name: 'title')
  String title;

  @JsonKey(name: 'link')
  String link;

  @JsonKey(name: 'hidden')
  bool hidden;

  @JsonKey(name: 'haschildren')
  bool haschildren;

  Children(
    this.name,
    this.type,
    this.key,
    this.classs,
    this.requiresajaxloading,
    this.icon,
    this.title,
    this.link,
    this.hidden,
    this.haschildren,
  );

  factory Children.fromJson(Map<String, dynamic> srcJson) =>
      _$ChildrenFromJson(srcJson);
}

@JsonSerializable()
class SubIcon extends Object {
  @JsonKey(name: 'component')
  String component;

  @JsonKey(name: 'pix')
  String pix;

  @JsonKey(name: 'classes')
  List<String> classes;

  @JsonKey(name: 'alt')
  String alt;

  @JsonKey(name: 'title')
  String title;

  SubIcon(
    this.component,
    this.pix,
    this.classes,
    this.alt,
    this.title,
  );

  factory SubIcon.fromJson(Map<String, dynamic> srcJson) =>
      _$SubIconFromJson(srcJson);
}
