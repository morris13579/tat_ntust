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

  /// 該學期修過的課號。**排除二次退選**：那些課不在課表上，成績單留著它們只是
  /// 為了記錄退選這件事，照抄進去會讓歷年課表多出幾門實際上沒在上的課。
  ///
  /// 唯一的呼叫端是「用成績還原歷年課表」（`NtustRepository._courseIdsFor`）。
  Future<List<String>> getCourseIdBySemester(SemesterJson semester) async {
    List<String> value = [];
    for (var i in info) {
      if (i.semester == semester) {
        for (var j in i.item) {
          if (j.isWithdrawn) continue;
          value.add(j.courseId);
        }
        break;
      }
    }
    return value;
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

  /// 二次退選。實測成績單上 `remark` 與 `score` 兩欄都是這四個字。
  static const String withdrawnRemark = '二次退選';

  bool get isWithdrawn =>
      remark.trim() == withdrawnRemark || score.trim() == withdrawnRemark;

  bool get isPassScore {
    return score.contains("A") || score.contains("B") || score.contains("C");
  }

  bool get isValidScore {
    return isPassScore ||
        score.contains("D") ||
        score.contains("E") ||
        score.contains("X");
  }

  /// 不及格＝已經有成績但沒過。「成績未到」與不在等第表上的成績（通過、抵免）
  /// 都不算，摘要上的門數才不會把還沒評分的課當成當掉。
  bool get isFailScore => isValidScore && !isPassScore;
}
