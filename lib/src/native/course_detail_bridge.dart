import 'package:flutter/foundation.dart';
import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/controller/course_member/course_member_controller.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_enrol_get_users.dart';
import 'package:flutter_app/src/native/bridge_results.dart';
import 'package:flutter_app/src/native/course_table_bridge.dart';
import 'package:flutter_app/src/repository/ntust_repository.dart';
import 'package:flutter_app/src/util/course_extra_info_utils.dart';
import 'package:flutter_app/src/util/course_grading_utils.dart';

/// 原生版的課程詳細資訊與修課學生。版面的取捨照 `course_info_page.dart`，名單照
/// `CourseMemberController`：一門課一顆，返回再進來不重查。
class CourseDetailBridge implements TatCourseDetailApi {
  static void install() => TatCourseDetailApi.setUp(CourseDetailBridge());

  final Map<String, CourseMemberController> _members = {};

  @override
  Future<CourseDetailResult> detail(String courseId, String semester) async {
    final result = await NtustRepository.instance.getCourseExtraInfo(
      courseId,
      CourseTableBridge.parseSemester(semester) ?? SemesterJson(),
    );
    final data = result.dataOrNull;
    return CourseDetailResult(
      info: data == null ? null : toInfo(data),
      error: BridgeResults.errorOf(result),
      notice: BridgeResults.noticeOf(result),
    );
  }

  @override
  Future<CourseMembers> members(String courseId, bool refresh) async {
    final controller = _members.putIfAbsent(
        courseId, () => CourseMemberController(courseId: courseId));
    await controller.load(force: refresh);
    final result = controller.members.value;
    return CourseMembers(
      members: [for (final m in controller.filter('')) _member(m)],
      error: result == null ? null : BridgeResults.errorOf(result),
      notice: result == null ? null : BridgeResults.noticeOf(result),
      signedIn: AuthSession.instance.isSignedIn,
    );
  }

  @override
  List<CourseMember> filterMembers(String courseId, String query) => [
        for (final m in _members[courseId]?.filter(query) ??
            const <MoodleCoreEnrolGetUsers>[])
          _member(m),
      ];

  @visibleForTesting
  static CourseDetailInfo toInfo(CourseExtraInfoJson info) {
    final grading = info.courseGrading.trim();
    final items = grading.isEmpty ? null : CourseGradingUtils.parse(grading);
    final subtitle = CourseExtraInfoUtils.subtitle(info);
    final objective = info.courseObject.trim();
    final members = info.allStudent.trim();
    final url = info.courseURL.trim();
    return CourseDetailInfo(
      name: info.courseName.trim(),
      subtitle: subtitle.isEmpty ? null : subtitle,
      chips: CourseExtraInfoUtils.chips(info),
      facts: [
        for (final fact in CourseExtraInfoUtils.facts(info))
          CourseInfoFact(
              label: fact.label, value: fact.value, footnote: fact.footnote),
      ],
      memberCount: members.isEmpty ? null : members,
      objective: objective.isEmpty
          ? null
          : CourseInfoProse(title: R.current.courseObject, body: objective),
      grading: items == null
          ? null
          : [
              for (final item in items)
                CourseGradingRow(label: item.label, percent: item.percentText),
            ],
      gradingText: grading.isNotEmpty && items == null ? grading : null,
      more: [
        for (final field in CourseExtraInfoUtils.moreFields(info))
          CourseInfoProse(title: field.title, body: field.body),
      ],
      courseUrl: url.isEmpty ? null : url,
    );
  }

  static CourseMember _member(MoodleCoreEnrolGetUsers member) {
    final url = member.profileImageUrlSmall.trim();
    return CourseMember(
      name: member.name.toString(),
      studentId: member.studentId.toString(),
      avatarUrl: url.isEmpty ? null : url,
    );
  }
}
