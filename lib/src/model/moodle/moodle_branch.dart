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
      {required this.name,
      required this.type,
      required this.key,
      required this.classs,
      required this.requiresajaxloading,
      required this.icon,
      required this.title,
      required this.hidden,
      required this.haschildren,
      required this.children});

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
  late List<String> classes;

  @JsonKey(name: 'alt')
  String alt;

  MainIcon(
      {this.component = "",
      this.pix = "",
      List<String>? classes,
      this.alt = ""}) {
    this.classes = classes ?? [];
  }

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

  String? contentAfterLink;

  bool? isExpanded;

  Children(
      {this.name = "",
      this.type = 0,
      this.key = "",
      this.classs = "",
      this.requiresajaxloading = false,
      this.title = "",
      this.link = "",
      this.hidden = false,
      this.haschildren = false,
      this.contentAfterLink,
      this.isExpanded,
      required this.icon});

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
  late List<String> classes;

  @JsonKey(name: 'alt')
  String alt;

  @JsonKey(name: 'title')
  String title;

  SubIcon(
      {this.component = "",
      this.pix = "",
      List<String>? classes,
      this.alt = "",
      this.title = ""}) {
    this.classes = classes ?? [];
  }

  factory SubIcon.fromJson(Map<String, dynamic> srcJson) =>
      _$SubIconFromJson(srcJson);
}
