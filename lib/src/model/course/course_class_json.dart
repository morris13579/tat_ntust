import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:quiver/core.dart';
import 'package:sprintf/sprintf.dart';

part 'course_class_json.g.dart';

@JsonSerializable()
class CourseMainJson {
  String name;
  String id;
  String href;
  String note; //備註
  String credits; //學分
  String hours; //時數
  String category; //類別 (必修...)
  Map<Day, String> time; //時間

  CourseMainJson(
      {this.name = "",
      this.href = "",
      this.id = "",
      this.credits = "",
      this.hours = "",
      this.note = "",
      this.category = "",
      this.time = const {}});

  bool get isEmpty {
    return name.isEmpty &&
        href.isEmpty &&
        note.isEmpty &&
        credits.isEmpty &&
        hours.isEmpty &&
        category.isEmpty;
  }

  @override
  String toString() {
    return sprintf(
        "name    :%s \n"
        "id      :%s \n"
        "href    :%s \n"
        "credits :%s \n"
        "hours   :%s \n"
        "note    :%s \n",
        [name, id, href, credits, hours, note]);
  }

  factory CourseMainJson.fromJson(Map<String, dynamic> json) =>
      _$CourseMainJsonFromJson(json);

  Map<String, dynamic> toJson() => _$CourseMainJsonToJson(this);
}

@JsonSerializable()
class CourseExtraJson {
  String id;
  String name;
  String href; //課程名稱用於取得英文
  String category; //類別 (必修...)
  String selectNumber; //選課人數
  String withdrawNumber; //徹選人數
  String openClass; //開課班級(計算學分用)

  CourseExtraJson(
      {this.id = "",
      this.openClass = "",
      this.name = "",
      this.category = "",
      this.selectNumber = "",
      this.withdrawNumber = "",
      this.href = ""});

  bool get isEmpty {
    return id.isEmpty &&
        name.isEmpty &&
        category.isEmpty &&
        selectNumber.isEmpty &&
        withdrawNumber.isEmpty &&
        openClass.isEmpty;
  }

  @override
  String toString() {
    return sprintf(
        "id             :%s \n"
        "name           :%s \n"
        "category       :%s \n"
        "selectNumber   :%s \n"
        "withdrawNumber :%s \n"
        "openClass :%s \n",
        [id, name, category, selectNumber, withdrawNumber, openClass]);
  }

  factory CourseExtraJson.fromJson(Map<String, dynamic> json) =>
      _$CourseExtraJsonFromJson(json);

  Map<String, dynamic> toJson() => _$CourseExtraJsonToJson(this);
}

@JsonSerializable()
class ClassJson {
  String name;
  String href;

  ClassJson({this.name = "", this.href = ""});

  bool get isEmpty {
    return name.isEmpty && href.isEmpty;
  }

  @override
  String toString() {
    return sprintf("name : %s \n" "href : %s \n", [name, href]);
  }

  factory ClassJson.fromJson(Map<String, dynamic> json) =>
      _$ClassJsonFromJson(json);

  Map<String, dynamic> toJson() => _$ClassJsonToJson(this);
}

@JsonSerializable()
class ClassroomJson {
  String name;
  String href;
  bool mainUse;

  ClassroomJson({this.name = "", this.href = "", this.mainUse = false});

  bool get isEmpty {
    return name.isEmpty && href.isEmpty;
  }

  @override
  String toString() {
    return sprintf("name    : %s \n" "href    : %s \n" "mainUse : %s \n",
        [name, href, mainUse.toString()]);
  }

  factory ClassroomJson.fromJson(Map<String, dynamic> json) =>
      _$ClassroomJsonFromJson(json);

  Map<String, dynamic> toJson() => _$ClassroomJsonToJson(this);
}

@JsonSerializable()
class TeacherJson {
  String name;
  String href;

  TeacherJson({this.name = "", this.href = ""});

  bool get isEmpty {
    return name.isEmpty && href.isEmpty;
  }

  @override
  String toString() {
    return sprintf("name : %s \n" "href : %s \n", [name, href]);
  }

  factory TeacherJson.fromJson(Map<String, dynamic> json) =>
      _$TeacherJsonFromJson(json);

  Map<String, dynamic> toJson() => _$TeacherJsonToJson(this);
}

@JsonSerializable()
class SemesterJson {
  String year;
  String semester;
  String urlPath;

  SemesterJson({this.year = "", this.semester = "", this.urlPath = ""});

  factory SemesterJson.fromJson(Map<String, dynamic> json) =>
      _$SemesterJsonFromJson(json);

  Map<String, dynamic> toJson() => _$SemesterJsonToJson(this);

  bool get isValid {
    try {
      int.parse(year);
      if (semester != "H") int.parse(semester);
      return true;
    } catch (e) {
      return false;
    }
  }

  bool get isEmpty {
    return year.isEmpty && semester.isEmpty;
  }

  @override
  String toString() {
    return sprintf("year     : %s \n" "semester : %s \n", [year, semester]);
  }

  @override
  bool operator ==(dynamic other) {
    try {
      return (int.parse(other.semester) == int.parse(semester) &&
          int.parse(other.year) == int.parse(year) &&
          other is SemesterJson);
    } catch (e) {
      return other.semester == semester &&
          other.year == year &&
          other is SemesterJson;
    }
  }

  @override
  int get hashCode => hash2(semester.hashCode, year.hashCode);
}

@JsonSerializable()
class ClassmateJson {
  String className; //電子一甲
  String studentEnglishName;
  String studentName;
  String studentId;
  String href;
  bool isSelect; //是否撤選

  ClassmateJson(
      {this.className = "",
      this.studentEnglishName = "",
      this.studentName = "",
      this.studentId = "",
      this.isSelect = false,
      this.href = ""});

  bool get isEmpty {
    return className.isEmpty &&
        studentEnglishName.isEmpty &&
        studentName.isEmpty &&
        studentId.isEmpty &&
        href.isEmpty;
  }

  @override
  String toString() {
    return sprintf(
        "className           : %s \n"
        "studentEnglishName  : %s \n"
        "studentName         : %s \n"
        "studentId           : %s \n"
        "href                : %s \n"
        "isSelect            : %s \n",
        [
          className,
          studentEnglishName,
          studentName,
          studentId,
          href,
          isSelect.toString()
        ]);
  }

  String getName() {
    String? name;
    if (LanguageUtils.getLangIndex() == LangEnum.en) {
      name = studentEnglishName;
    }
    name = name ?? studentName;
    name = (name.contains(RegExp(r"\w"))) ? name : studentName;
    return name;
  }

  factory ClassmateJson.fromJson(Map<String, dynamic> json) =>
      _$ClassmateJsonFromJson(json);

  Map<String, dynamic> toJson() => _$ClassmateJsonToJson(this);
}
