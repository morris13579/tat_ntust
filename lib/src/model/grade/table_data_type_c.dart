import 'package:flutter_app/src/model/grade/base_table_data.dart';
import 'package:flutter_app/src/model/grade/item_name.dart';
import 'package:flutter_app/src/model/grade/leader.dart';
import 'package:json_annotation/json_annotation.dart';
part 'table_data_type_c.g.dart';
@JsonSerializable()
class TableDataTypeCEntity extends BaseTableData {
  LeaderEntity leader;
  @override
  List<int> parentcategories;

  TableDataTypeCEntity(this.leader, this.parentcategories);

  factory TableDataTypeCEntity.fromJson(Map<String, dynamic> json) =>
      _$TableDataTypeCEntityFromJson(json);

  Map<String, dynamic> toJson() => _$TableDataTypeCEntityToJson(this);
}
