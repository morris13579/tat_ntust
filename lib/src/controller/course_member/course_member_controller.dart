import 'package:flutter_app/src/model/moodle_webapi/moodle_core_enrol_get_users.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:get/get.dart';

/// 修課學生名單的狀態。
///
/// 這支 Moodle API 慢，所以它獨占一個畫面，也獨占一個 controller：課程詳細
/// 資訊那一頁不再因為有人開了課程就順手打它。
///
/// 由課程頁持有而不是名單頁自己 new 一顆：名單頁被 pop 掉之後 controller 還
/// 活著，返回再進來就直接畫上一次的結果。
class CourseMemberController {
  CourseMemberController({required this.courseId});

  final String courseId;

  final members = Rxn<Result<List<MoodleCoreEnrolGetUsers>>>();

  /// 已經有可以顯示的資料了。
  bool get hasData => members.value?.hasData ?? false;

  /// [force] 為 false 時，手上已經有資料就不重打。
  Future<void> load({bool force = false}) async {
    if (!force && hasData) return;
    members.value = null;
    members.value = await MoodleRepository.instance.getMembers(courseId);
  }

  /// 本地過濾，不打 API：名單一次就全抓回來了，打字不該再等網路。
  List<MoodleCoreEnrolGetUsers> filter(String query) {
    final all = members.value?.dataOrNull ?? const <MoodleCoreEnrolGetUsers>[];
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) return all;
    return all.where((member) {
      // name／studentId 是 model 上沒有標型別的 getter。
      final name = member.name.toString().toLowerCase();
      final studentId = member.studentId.toString().toLowerCase();
      return name.contains(keyword) || studentId.contains(keyword);
    }).toList();
  }

  void dispose() {
    members.close();
  }
}
