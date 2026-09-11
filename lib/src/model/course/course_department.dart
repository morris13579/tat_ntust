/// querycourse 的學院。`/api/Colleges/`。
///
/// 中英文兩份名字都留著、由畫面挑一份：model 讀 `LanguageUtils` 會是
/// `tool/deps.py` 擋的 model -> util 上行邊。
class CollegeJson {
  const CollegeJson({
    required this.no,
    required this.name,
    required this.engName,
  });

  final String no;
  final String name;
  final String engName;

  factory CollegeJson.fromJson(Map<String, dynamic> json) => CollegeJson(
        no: json['CollegeNo'] as String? ?? '',
        name: json['CollegeName'] as String? ?? '',
        engName: json['CollegeEngName'] as String? ?? '',
      );
}

/// querycourse 的系所。`/api/departments?collegeNo=<no>`。
///
/// [no] 就是課號的前兩碼（`CS` → 資訊工程系），所以系所篩選不需要另一個查詢
/// 參數——把它當 `CourseNo` 送出去就是「這個系開的課」。
class DepartmentJson {
  const DepartmentJson({
    required this.no,
    required this.name,
    required this.engName,
  });

  final String no;
  final String name;
  final String engName;

  factory DepartmentJson.fromJson(Map<String, dynamic> json) => DepartmentJson(
        no: json['DeptNo'] as String? ?? '',
        name: json['Department'] as String? ?? '',
        engName: json['EngDepartment'] as String? ?? '',
      );
}
