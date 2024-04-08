import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

@JsonSerializable()
class TablesEntity {
  @JsonKey(name: 'courseid')
  int courseId;
  @JsonKey(name: 'userid')
  int userId;
  @JsonKey(name: 'userfullname')
  String userFullName;
  @JsonKey(name: 'maxdepth')
  int maxDepth;
  @JsonKey(name: 'tabledata')
  List<Map<String, dynamic>> tableData;

  TablesEntity(this.courseId, this.userId, this.userFullName, this.maxDepth,
      this.tableData);

  Map<String, dynamic> toJson() => <String, dynamic>{
  'courseid': courseId,
  'userid': userId,
  'userfullname': userFullName,
  'maxdepth': maxDepth,
  'tabledata': jsonEncode(tableData),
  };

  factory TablesEntity.fromJson(Map<String, dynamic> json) {
    var tableDataList = <Map<String, dynamic>>[];
    var dynamicList = json["tabledata"] as List;
    for (var item in dynamicList) {
      try {
        tableDataList.add(item as Map<String, dynamic>);
      } catch(e) {
        // item 可能是空list 沒辦法解析成map
      }
    }
    return TablesEntity(json["courseid"] as int, json["userid"] as int,
        json["userfullname"] as String, json["maxdepth"] as int, tableDataList);
  }
}
