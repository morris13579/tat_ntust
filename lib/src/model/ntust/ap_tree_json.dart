import 'package:json_annotation/json_annotation.dart';

part 'ap_tree_json.g.dart';

@JsonSerializable()
class APTreeJson {
  String serviceId;
  @JsonKey(name: 'apList')
  List<APListJson> apList;

  APTreeJson(this.serviceId, this.apList);

  factory APTreeJson.fromJson(Map<String, dynamic> srcJson) =>
      _$APTreeJsonFromJson(srcJson);

  Map<String, dynamic> toJson() => _$APTreeJsonToJson(this);
}

@JsonSerializable()
class APListJson {
  @JsonKey(name: 'name')
  String name;
  @JsonKey(name: 'url')
  String url;
  @JsonKey(name: 'type')
  String type;

  APListJson({this.name = "", this.url = "", this.type = ""});

  factory APListJson.fromJson(Map<String, dynamic> srcJson) =>
      _$APListJsonFromJson(srcJson);

  Map<String, dynamic> toJson() => _$APListJsonToJson(this);
}
