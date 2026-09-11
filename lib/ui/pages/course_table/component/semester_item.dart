import 'package:flutter_app/src/model/course/course_class_json.dart';

/// 學期的顯示字串。只有年度、沒有學期別時不補分隔線。
String semesterLabel(SemesterJson semester) => semester.semester.isEmpty
    ? semester.year
    : '${semester.year}-${semester.semester}';
