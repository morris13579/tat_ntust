import 'package:json_annotation/json_annotation.dart';
part 'weight.g.dart';

@JsonSerializable()
class WeightEntity {
  @JsonKey(name: 'class')
  String class_;
  String content;
  String headers;


  WeightEntity(this.class_, this.content, this.headers);

  factory WeightEntity.fromJson(Map<String, dynamic> json) =>
      _$WeightEntityFromJson(json);

  Map<String, dynamic> toJson() => _$WeightEntityToJson(this);
}
