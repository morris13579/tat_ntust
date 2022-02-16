import 'package:json_annotation/json_annotation.dart';

part 'moodle_gradereport_user_get_grades_table.g.dart';

@JsonSerializable()
class MoodleGradeReportUserGetGradesTable {
  @JsonKey(name: 'tables')
  late List<Tables> tables;

  @JsonKey(name: 'warnings')
  late List<dynamic> warnings;

  MoodleGradeReportUserGetGradesTable({
    List<Tables>? tables,
    List<dynamic>? warnings,
  }) {
    this.tables = tables ?? [];
    this.warnings = warnings ?? [];
  }

  factory MoodleGradeReportUserGetGradesTable.fromJson(
          Map<String, dynamic> srcJson) =>
      _$MoodleGradeReportUserGetGradesTableFromJson(srcJson);

  Map<String, dynamic> toJson() =>
      _$MoodleGradeReportUserGetGradesTableToJson(this);
}

@JsonSerializable()
class Tables {
  @JsonKey(name: 'courseid')
  int courseId;

  @JsonKey(name: 'userid')
  int userid;

  @JsonKey(name: 'userfullname')
  String userFullName;

  @JsonKey(name: 'maxdepth')
  int maxDepth;

  @JsonKey(name: 'tabledata')
  late List<TableData> tableData;

  Tables({
    this.courseId = 0,
    this.userid = 0,
    this.userFullName = "",
    this.maxDepth = 0,
    List<TableData>? tableData,
  }) {
    this.tableData = tableData ?? [];
  }

  factory Tables.fromJson(Map<String, dynamic> srcJson) =>
      _$TablesFromJson(srcJson);

  Map<String, dynamic> toJson() => _$TablesToJson(this);
}

@JsonSerializable()
class TableData {
  @JsonKey(name: 'itemname')
  late ItemName itemName;

  @JsonKey(name: 'leader')
  late Leader leader;

  @JsonKey(name: 'weight')
  late Weight weight;

  @JsonKey(name: 'grade')
  late Grade grade;

  @JsonKey(name: 'range')
  late Range range;

  @JsonKey(name: 'percentage')
  late Percentage percentage;

  @JsonKey(name: 'feedback')
  late Feedback feedback;

  @JsonKey(name: 'contributiontocoursetotal')
  late ContributionToCourseTotal contributiontocoursetotal;

  TableData(
      {ItemName? itemName,
      Leader? leader,
      Weight? weight,
      Grade? grade,
      Range? range,
      Percentage? percentage,
      Feedback? feedback,
      ContributionToCourseTotal? contributiontocoursetotal}) {
    this.itemName = itemName ?? ItemName();
    this.leader = leader ?? Leader();
    this.weight = weight ?? Weight();
    this.grade = grade ?? Grade();
    this.range = range ?? Range();
    this.percentage = percentage ?? Percentage();
    this.feedback = feedback ?? Feedback();
    this.contributiontocoursetotal =
        contributiontocoursetotal ?? ContributionToCourseTotal();
  }

  factory TableData.fromJson(Map<String, dynamic> srcJson) =>
      _$TableDataFromJson(srcJson);

  Map<String, dynamic> toJson() => _$TableDataToJson(this);
}

@JsonSerializable()
class ItemName {
  @JsonKey(name: 'class')
  String classs;

  @JsonKey(name: 'colspan')
  int colSpan;

  @JsonKey(name: 'content')
  String content;

  @JsonKey(name: 'celltype')
  String cellType;

  @JsonKey(name: 'id')
  String id;

  ItemName({
    this.classs = "",
    this.colSpan = 0,
    this.content = "",
    this.cellType = "",
    this.id = "",
  });

  factory ItemName.fromJson(Map<String, dynamic> srcJson) =>
      _$ItemNameFromJson(srcJson);

  Map<String, dynamic> toJson() => _$ItemNameToJson(this);
}

@JsonSerializable()
class Leader {
  @JsonKey(name: 'class')
  String classs;

  @JsonKey(name: 'rowspan')
  int rowspan;

  Leader({this.classs = "", this.rowspan = 0});

  factory Leader.fromJson(Map<String, dynamic> srcJson) =>
      _$LeaderFromJson(srcJson);

  Map<String, dynamic> toJson() => _$LeaderToJson(this);
}

@JsonSerializable()
class Weight extends Object {
  @JsonKey(name: 'class')
  String classs;

  @JsonKey(name: 'content')
  String content;

  @JsonKey(name: 'headers')
  String headers;

  Weight({
    this.classs = "",
    this.content = "",
    this.headers = "",
  });

  factory Weight.fromJson(Map<String, dynamic> srcJson) =>
      _$WeightFromJson(srcJson);

  Map<String, dynamic> toJson() => _$WeightToJson(this);
}

@JsonSerializable()
class Grade extends Object {
  @JsonKey(name: 'class')
  String classs;

  @JsonKey(name: 'content')
  String content;

  @JsonKey(name: 'headers')
  String headers;

  Grade({
    this.classs = "",
    this.content = "",
    this.headers = "",
  });

  factory Grade.fromJson(Map<String, dynamic> srcJson) =>
      _$GradeFromJson(srcJson);

  Map<String, dynamic> toJson() => _$GradeToJson(this);
}

@JsonSerializable()
class Range extends Object {
  @JsonKey(name: 'class')
  String classs;

  @JsonKey(name: 'content')
  String content;

  @JsonKey(name: 'headers')
  String headers;

  Range({
    this.classs = "",
    this.content = "",
    this.headers = "",
  });

  factory Range.fromJson(Map<String, dynamic> srcJson) =>
      _$RangeFromJson(srcJson);

  Map<String, dynamic> toJson() => _$RangeToJson(this);
}

@JsonSerializable()
class Percentage extends Object {
  @JsonKey(name: 'class')
  String classs;

  @JsonKey(name: 'content')
  String content;

  @JsonKey(name: 'headers')
  String headers;

  Percentage({
    this.classs = "",
    this.content = "",
    this.headers = "",
  });

  factory Percentage.fromJson(Map<String, dynamic> srcJson) =>
      _$PercentageFromJson(srcJson);

  Map<String, dynamic> toJson() => _$PercentageToJson(this);
}

@JsonSerializable()
class Feedback extends Object {
  @JsonKey(name: 'class')
  String classs;

  @JsonKey(name: 'content')
  String content;

  @JsonKey(name: 'headers')
  String headers;

  Feedback({
    this.classs = "",
    this.content = "",
    this.headers = "",
  });

  factory Feedback.fromJson(Map<String, dynamic> srcJson) =>
      _$FeedbackFromJson(srcJson);

  Map<String, dynamic> toJson() => _$FeedbackToJson(this);
}

@JsonSerializable()
class ContributionToCourseTotal extends Object {
  @JsonKey(name: 'class')
  String classs;

  @JsonKey(name: 'content')
  String content;

  @JsonKey(name: 'headers')
  String headers;

  ContributionToCourseTotal({
    this.classs = "",
    this.content = "",
    this.headers = "",
  });

  factory ContributionToCourseTotal.fromJson(Map<String, dynamic> srcJson) =>
      _$ContributiontocoursetotalFromJson(srcJson);

  Map<String, dynamic> toJson() => _$ContributiontocoursetotalToJson(this);
}
