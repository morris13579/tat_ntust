import 'package:flutter_app/src/model/course/course_department.dart';

/// 通識向度。`/api/dimensions` 回的 `DimNo`。
///
/// 值域是實測的：1151 學期整包 4282 門課裡，Dimension 只出現 ''（4071 門）與
/// A-F。`0` 也在 `/api/dimensions` 的清單裡，但沒有任何一門課用它。
enum CourseDimension { a, b, c, d, e, f }

extension CourseDimensionCode on CourseDimension {
  String get code => name.toUpperCase();
}

/// 學制。querycourse 是兩個獨立的布林，不是三選一——兩個都關代表不限。
enum CourseProgramLevel { any, underGraduate, master }

/// `/api/courses` 的查詢條件。
///
/// 欄位名對齊官方前端實際送出去的 body（2026-09 實測）：
/// ```json
/// {"Semester":"1151","CourseNo":"CS3","CourseName":"","CourseTeacher":"",
///  "Dimension":"","CourseNotes":"","CampusNotes":"","ForeignLanguage":0,
///  "OnlyIntensive":0,"OnlyGeneral":0,"OnleyNTUST":0,"OnlyMaster":0,
///  "OnlyUnderGraduate":0,"OnlyNode":0,"Language":"en"}
/// ```
/// `OnleyNTUST` 的拼字錯誤是伺服器端的，不能改。
class CourseQueryFilter {
  const CourseQueryFilter({
    this.courseNo = '',
    this.department,
    this.courseName = '',
    this.teacher = '',
    this.dimension,
    this.level = CourseProgramLevel.any,
    this.foreignLanguageOnly = false,
    this.generalOnly = false,
    this.intensiveOnly = false,
    this.ntustOnly = false,
  });

  /// 課號。**前綴就是系所**：`/api/departments?collegeNo=N` 的 `DeptNo` 是課號的
  /// 前兩碼（`CS` → 資訊工程系），所以系所篩選不需要另一個參數，送 `CS` 就是
  /// 「資工系開的課」（實測 1151 學期 63 門）。
  final String courseNo;

  /// 系所。`DeptNo` 就是課號前兩碼，送出去時併進 [courseNo] 當前綴。
  /// 與使用者自己打的關鍵字互斥：兩個都填的話以關鍵字為準。
  final DepartmentJson? department;

  final String courseName;

  final String teacher;

  /// 通識向度。只有通識課有值。
  final CourseDimension? dimension;

  final CourseProgramLevel level;

  /// 英語授課（實測 1151 學期 99 門）。
  final bool foreignLanguageOnly;

  /// 通識課（實測 211 門）。
  final bool generalOnly;

  /// 密集課程（實測 29 門）。
  final bool intensiveOnly;

  /// 排除台大／台師大的三校聯盟課程（實測 2187 門）。
  final bool ntustOnly;

  bool get isEmpty =>
      courseNo.trim().isEmpty &&
      department == null &&
      courseName.trim().isEmpty &&
      teacher.trim().isEmpty &&
      dimension == null &&
      level == CourseProgramLevel.any &&
      !foreignLanguageOnly &&
      !generalOnly &&
      !intensiveOnly &&
      !ntustOnly;

  /// 除了關鍵字以外還有沒有勾選任何條件。畫面上的「篩選」籤要靠它顯示已套用。
  bool get hasRefinements =>
      department != null ||
      dimension != null ||
      level != CourseProgramLevel.any ||
      foreignLanguageOnly ||
      generalOnly ||
      intensiveOnly ||
      ntustOnly;

  CourseQueryFilter copyWith({
    String? courseNo,
    DepartmentJson? department,
    bool clearDepartment = false,
    String? courseName,
    String? teacher,
    CourseDimension? dimension,
    bool clearDimension = false,
    CourseProgramLevel? level,
    bool? foreignLanguageOnly,
    bool? generalOnly,
    bool? intensiveOnly,
    bool? ntustOnly,
  }) =>
      CourseQueryFilter(
        courseNo: courseNo ?? this.courseNo,
        department: clearDepartment ? null : (department ?? this.department),
        courseName: courseName ?? this.courseName,
        teacher: teacher ?? this.teacher,
        dimension: clearDimension ? null : (dimension ?? this.dimension),
        level: level ?? this.level,
        foreignLanguageOnly: foreignLanguageOnly ?? this.foreignLanguageOnly,
        generalOnly: generalOnly ?? this.generalOnly,
        intensiveOnly: intensiveOnly ?? this.intensiveOnly,
        ntustOnly: ntustOnly ?? this.ntustOnly,
      );

  /// 送給 `/api/courses` 的 body。[semesterCode] 是 `1151` 這種四碼。
  ///
  /// `CourseNotes` 與 `CampusNotes` 一律送空字串：官方前端也送它們，但實測填了
  /// 值反而查不到東西（`CourseNotes=合班` 回 0 筆，即使有課的 Contents 含「合班
  /// 上課」），所以不開放給呼叫端。
  Map<String, dynamic> toRequestBody({
    required String semesterCode,
    required String language,
  }) =>
      {
        'Semester': semesterCode,
        // 使用者打了關鍵字就以關鍵字為準；只選系所時送 DeptNo 當前綴。
        'CourseNo': courseNo.trim().isNotEmpty
            ? courseNo.trim()
            : (department?.no ?? ''),
        'CourseName': courseName.trim(),
        'CourseTeacher': teacher.trim(),
        'Dimension': dimension?.code ?? '',
        'CourseNotes': '',
        'CampusNotes': '',
        'ForeignLanguage': foreignLanguageOnly ? 1 : 0,
        'OnlyIntensive': intensiveOnly ? 1 : 0,
        'OnlyGeneral': generalOnly ? 1 : 0,
        'OnleyNTUST': ntustOnly ? 1 : 0,
        'OnlyMaster': level == CourseProgramLevel.master ? 1 : 0,
        'OnlyUnderGraduate': level == CourseProgramLevel.underGraduate ? 1 : 0,
        // 實測送 1 會讓伺服器回非 JSON，所以固定 0。
        'OnlyNode': 0,
        'Language': language,
      };
}
