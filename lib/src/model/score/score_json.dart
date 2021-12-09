import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:json_annotation/json_annotation.dart';

part 'score_json.g.dart';

@JsonSerializable()
class ScoreRankJson {
  late List<SemesterScoreJson> info;

  ScoreRankJson({List<SemesterScoreJson>? info}) {
    this.info = info ?? [];
  }

  void addRankBySemester(SemesterJson semester, RankJson rank) {
    bool add = false;
    for (var i in info) {
      if (i.semester == semester) {
        i.rank = rank;
        add = true;
        break;
      }
    }
    if (!add) {
      info.add(SemesterScoreJson(
        semester: semester,
        item: [],
        rank: rank,
      ));
    }
  }

  void addScoreBySemester(SemesterJson semester, ScoreItemJson item) {
    bool add = false;
    for (var i in info) {
      if (i.semester == semester) {
        i.item.add(item);
        add = true;
        break;
      }
    }
    if (!add) {
      info.add(SemesterScoreJson(
        semester: semester,
        item: [item],
      ));
    }
  }

  Map<String, dynamic> toJson() => _$ScoreRankJsonToJson(this);

  factory ScoreRankJson.fromJson(Map<String, dynamic> srcJson) =>
      _$ScoreRankJsonFromJson(srcJson);
}

@JsonSerializable()
class SemesterScoreJson {
  SemesterJson semester;
  List<ScoreItemJson> item;
  RankJson? rank;

  SemesterScoreJson({required this.semester, required this.item, this.rank});

  Map<String, dynamic> toJson() => _$SemesterScoreJsonToJson(this);

  factory SemesterScoreJson.fromJson(Map<String, dynamic> srcJson) =>
      _$SemesterScoreJsonFromJson(srcJson);
}

@JsonSerializable()
class RankJson {
  String classRank; //班排
  String departmentRank; //系排
  String averageScore; //平均成績
  String classRankYears; //班排 (歷年)
  String departmentRankYears; //系排 (歷年)
  String averageYears; //平均成績 (歷年)

  RankJson({
    required this.classRank,
    required this.departmentRank,
    required this.averageScore,
    required this.classRankYears,
    required this.departmentRankYears,
    required this.averageYears,
  });

  Map<String, dynamic> toJson() => _$RankJsonToJson(this);

  factory RankJson.fromJson(Map<String, dynamic> srcJson) =>
      _$RankJsonFromJson(srcJson);
}

@JsonSerializable()
class ScoreItemJson {
  String courseId;
  String name;
  String credit;
  String score;
  String remark;
  String generalDimension; //通識向度
  ScoreItemJson({
    required this.courseId,
    required this.score,
    required this.name,
    required this.credit,
    required this.generalDimension,
    required this.remark,
  });

  Map<String, dynamic> toJson() => _$ScoreItemJsonToJson(this);

  factory ScoreItemJson.fromJson(Map<String, dynamic> srcJson) =>
      _$ScoreItemJsonFromJson(srcJson);
}
