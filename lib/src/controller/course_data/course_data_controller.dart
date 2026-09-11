import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_gradereport_get_grade_items.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:get/get.dart';

/// 一門課的四個 Moodle 分頁共用的狀態。抽出來由頁面持有，四個請求才能在進入
/// 頁面時一起發出去（`PageView` 懶載入，各自 initState 會每滑一頁等一次）。
class CourseDataController {
  CourseDataController(this.courseId);

  final String courseId;

  /// null 代表還在載入，與 `ResultView` 的約定一致。
  final directory = Rxn<Result<List<MoodleCoreCourseGetContents>>>();
  final announcements = Rxn<Result<MoodleModForumGetForumDiscussions>>();
  final score = Rxn<Result<MoodleUserGradesEntity>>();
  final assignments = Rxn<Result<List<MoodleAssignment>>>();

  /// 每份作業的繳交狀態（key 是 assign id）；清單與詳情頁讀同一顆。
  final Map<int, Rxn<Result<MoodleAssignSubmissionStatus>>> _statuses = {};

  Rxn<Result<MoodleAssignSubmissionStatus>> statusOf(int assignId) =>
      _statuses.putIfAbsent(assignId, Rxn.new);

  /// 四個一起抓。它們都會先解析同一個課程的內部 id，所以 `MoodleRepository`
  /// 那邊必須有 in-flight 去重，否則同一個請求會打四次。
  Future<void> loadAll() => Future.wait([
        loadDirectory(),
        loadAnnouncements(),
        loadScore(),
        loadAssignments(),
      ]);

  Future<void> loadDirectory() async {
    directory.value = null;
    directory.value =
        await MoodleRepository.instance.getCourseDirectory(courseId);
  }

  Future<void> loadAnnouncements() async {
    announcements.value = null;
    announcements.value =
        await MoodleRepository.instance.getAnnouncements(courseId);
  }

  Future<void> loadScore() async {
    score.value = null;
    score.value = await MoodleRepository.instance.getCourseScore(courseId);
  }

  /// 先拿清單，再為每份作業背景抓狀態（不彈框、不開登入頁）。
  Future<void> loadAssignments() async {
    assignments.value = null;
    final result = await MoodleRepository.instance.getAssignments(courseId);
    assignments.value = result;
    final list = result.dataOrNull;
    if (list == null) return;
    await Future.wait(list.map((a) => loadStatus(a.id)));
  }

  Future<void> loadStatus(int assignId) async {
    final state = statusOf(assignId);
    state.value = null;
    state.value = await MoodleRepository.instance
        .getSubmissionStatus(assignId, background: true);
  }

  void dispose() {
    directory.close();
    announcements.close();
    score.close();
    assignments.close();
    for (final s in _statuses.values) {
      s.close();
    }
  }
}
