import 'package:flutter_app/src/model/grade/item_name.dart';
import 'package:json_annotation/json_annotation.dart';

abstract class BaseTableData {
  @JsonKey(name: 'itemname')
  ItemNameEntity? itemName;
}