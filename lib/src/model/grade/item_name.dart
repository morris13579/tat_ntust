import 'package:json_annotation/json_annotation.dart';
part 'item_name.g.dart';

@JsonSerializable()
class ItemNameEntity {
  @JsonKey(name: 'class')
  String class_;
  int colspan;
  String content;
  String celltype;
  String id;

  ItemNameEntity(
      this.class_, this.colspan, this.content, this.celltype, this.id);

  factory ItemNameEntity.fromJson(Map<String, dynamic> json) =>
      _$ItemNameEntityFromJson(json);

  Map<String, dynamic> toJson() => _$ItemNameEntityToJson(this);
}
