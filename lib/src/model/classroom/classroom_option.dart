import 'package:json_annotation/json_annotation.dart';

part 'classroom_option.g.dart';

/// 教室查詢的下拉選單項目：校區或大樓。
///
/// [code] 是送回站台的值（`HQ`、`T4`），[name] 是站台自己給的中文名稱。
/// 名稱不走 l10n——那是伺服器資料，不是 App 的字串。
@JsonSerializable()
class ClassroomOptionJson {
  final String code;
  final String name;

  const ClassroomOptionJson({required this.code, required this.name});

  factory ClassroomOptionJson.fromJson(Map<String, dynamic> srcJson) =>
      _$ClassroomOptionJsonFromJson(srcJson);

  Map<String, dynamic> toJson() => _$ClassroomOptionJsonToJson(this);
}

/// 一個校區與它底下的大樓。
///
/// 大樓清單要先在站台上選過校區才生得出來，所以兩者一起取、一起快取。
@JsonSerializable(explicitToJson: true)
class ClassroomCampusJson {
  final String code;
  final String name;
  final List<ClassroomOptionJson> buildings;

  const ClassroomCampusJson({
    required this.code,
    required this.name,
    this.buildings = const [],
  });

  factory ClassroomCampusJson.fromJson(Map<String, dynamic> srcJson) =>
      _$ClassroomCampusJsonFromJson(srcJson);

  Map<String, dynamic> toJson() => _$ClassroomCampusJsonToJson(this);
}
