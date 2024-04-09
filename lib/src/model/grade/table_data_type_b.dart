import 'package:flutter_app/src/model/grade/base_table_data.dart';
import 'package:flutter_app/src/model/grade/item_name.dart';
import 'package:flutter_app/src/model/grade/weight.dart';
import 'package:json_annotation/json_annotation.dart';
part 'table_data_type_b.g.dart';

@JsonSerializable()
class TableDataTypeBEntity extends BaseTableData {
  @override
  @JsonKey(name: 'itemname')
  ItemNameEntity? itemName;
  WeightEntity weight;
  WeightEntity grade;
  WeightEntity range;
  WeightEntity percentage;
  WeightEntity feedback;
  @JsonKey(name: 'contributiontocoursetotal')
  WeightEntity contributionToCourseTotal;

  TableDataTypeBEntity(this.itemName, this.weight, this.grade, this.range,
      this.percentage, this.feedback, this.contributionToCourseTotal);

  factory TableDataTypeBEntity.fromJson(Map<String, dynamic> json) =>
      _$TableDataTypeBEntityFromJson(json);

  Map<String, dynamic> toJson() => _$TableDataTypeBEntityToJson(this);
}
