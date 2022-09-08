import 'package:json_annotation/json_annotation.dart';

part 'announcement_json.g.dart';

@JsonSerializable()
class AnnouncementJson {
  @JsonKey(name: "count_down")
  int countDown;

  @JsonKey(name: "list")
  List<AnnouncementInfoJson> list;

  AnnouncementJson({
    required this.countDown,
    required this.list,
  });

  factory AnnouncementJson.fromJson(Map<String, dynamic> srcJson) =>
      _$AnnouncementJsonFromJson(srcJson);

  Map<String, dynamic> toJson() => _$AnnouncementJsonToJson(this);

  @override
  String toString() {
    String s = "";
    for (var i in list) {
      s += i.toString();
    }
    return s;
  }
}

@JsonSerializable()
class AnnouncementInfoJson {
  @JsonKey(name: "title")
  String title;
  @JsonKey(name: "content")
  String content;
  @JsonKey(name: "start_time")
  DateTime startTime;
  @JsonKey(name: "end_time")
  DateTime endTime;
  @JsonKey(name: "test")
  bool test;

  AnnouncementInfoJson({
    required this.title,
    required this.content,
    required this.startTime,
    required this.endTime,
    required this.test,
  });

  factory AnnouncementInfoJson.fromJson(Map<String, dynamic> srcJson) =>
      _$AnnouncementInfoJsonFromJson(srcJson);

  Map<String, dynamic> toJson() => _$AnnouncementInfoJsonToJson(this);

  @override
  String toString() {
    return "title: $title\n"
        "content: $content\n"
        "startTime: $startTime\n"
        "endTime: $endTime\n";
  }
}
