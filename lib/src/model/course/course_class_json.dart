import 'package:flutter_app/src/model/course_table/course_time.dart';
import 'package:json_annotation/json_annotation.dart';
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
  bool select;

  CourseMainJson(
      {this.name = "",
      this.href = "",
      this.id = "",
      this.credits = "",
      this.hours = "",
      this.note = "",
      this.category = "",
      this.select = true,
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

/// 一個學期。只有 year 與 semester 兩個欄位。
///
/// 不要加回 `urlPath`（選課系統課表網頁的相對路徑）：它會跟著課表存進硬碟，
/// 舊版留下的值會在重新整理時被讀回來，送進已經對不上學校新版 HTML 的
/// 解析路徑。
@JsonSerializable()
class SemesterJson {
  String year;
  String semester;

  SemesterJson({this.year = "", this.semester = ""});

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

  /// 學期字串正規化：能當成整數看的就用整數的字面值，
  /// 讓 "1" 與 "01" 視為同一個學期；暑期的 "H" 這種就照原樣比。
  static String _normalize(String v) => int.tryParse(v)?.toString() ?? v;

  /// 相等性以「數值意義」為準：學校的頁面有時送 "1" 有時送 "01"，
  /// 兩者指的是同一個學期。
  ///
  /// 型別檢查必須擺在最前面，否則跟別的型別比較時會先存取 `other.semester`
  /// 而讓 NoSuchMethodError 從 `==` 逸出。
  @override
  bool operator ==(Object other) {
    if (other is! SemesterJson) return false;
    return _normalize(other.semester) == _normalize(semester) &&
        _normalize(other.year) == _normalize(year);
  }

  /// 必須與 [operator ==] 用同一套正規化，否則 "1" 與 "01" 相等卻雜湊不同，
  /// 違反 Dart 的雜湊契約。
  @override
  int get hashCode => Object.hash(_normalize(semester), _normalize(year));
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

  factory ClassmateJson.fromJson(Map<String, dynamic> json) =>
      _$ClassmateJsonFromJson(json);

  Map<String, dynamic> toJson() => _$ClassmateJsonToJson(this);
}
