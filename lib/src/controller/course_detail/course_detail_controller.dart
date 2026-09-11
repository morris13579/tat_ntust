import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/repository/ntust_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:get/get.dart';

/// 一門課的詳細資訊。
///
/// 只有 querycourse（免登入）這一支請求。修課學生名單搬到
/// [CourseMemberController]：那支 Moodle API 慢，不該因為有人開了課程頁就跑。
class CourseDetailController {
  CourseDetailController({required this.courseId, required this.semester});

  final String courseId;
  final SemesterJson semester;

  final info = Rxn<Result<CourseExtraInfoJson>>();

  Future<void> loadInfo() async {
    info.value = null;
    info.value =
        await NtustRepository.instance.getCourseExtraInfo(courseId, semester);
  }

  void dispose() {
    info.close();
  }
}
