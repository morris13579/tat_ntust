import 'package:flutter_app/src/model/grade/base_table_data.dart';
import 'package:flutter_app/src/model/grade/item_name.dart';
import 'package:flutter_app/src/model/grade/leader.dart';
import 'package:json_annotation/json_annotation.dart';
part 'table_data_type_a.g.dart';
@JsonSerializable()
class TableDataTypeAEntity extends BaseTableData {
  @JsonKey(name: 'itemname')
  ItemNameEntity? itemName;
  @override
  List<int> parentcategories;

  TableDataTypeAEntity(this.itemName, this.parentcategories);

  factory TableDataTypeAEntity.fromJson(Map<String, dynamic> json) =>
      _$TableDataTypeAEntityFromJson(json);

  Map<String, dynamic> toJson() => _$TableDataTypeAEntityToJson(this);
}
