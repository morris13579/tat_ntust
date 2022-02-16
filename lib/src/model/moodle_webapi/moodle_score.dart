import 'package:json_annotation/json_annotation.dart';

part 'moodle_score.g.dart';

@JsonSerializable()
class MoodleScoreItem {
  String name;
  String weight; //計算後權量
  String score; //成績
  String fullRange; //全距
  String percentage; //百分比
  String feedback; //回饋
  String contribute; //貢獻到課程總分
  MoodleScoreItem({
    required this.name,
    required this.weight,
    required this.score,
    required this.fullRange,
    required this.percentage,
    required this.feedback,
    required this.contribute,
  });

  factory MoodleScoreItem.fromJson(Map<String, dynamic> json) =>
      _$MoodleScoreItemFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleScoreItemToJson(this);
}
