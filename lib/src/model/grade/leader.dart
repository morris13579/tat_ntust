import 'package:json_annotation/json_annotation.dart';
part 'leader.g.dart';

@JsonSerializable()
class LeaderEntity {
  @JsonKey(name: 'class')
  String class_;
  int rowspan;


  LeaderEntity(this.class_, this.rowspan);

  factory LeaderEntity.fromJson(Map<String, dynamic> json) =>
      _$LeaderEntityFromJson(json);

  Map<String, dynamic> toJson() => _$LeaderEntityToJson(this);
}
