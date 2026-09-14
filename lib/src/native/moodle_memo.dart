import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions.dart';
import 'package:flutter_app/src/repository/result.dart';

/// 課程 Moodle 幾個原生畫面之間共用、抓過就留著的東西：從清單點進詳情頁不必再抓一次，
/// 詳情頁寫進伺服器的新狀態，回到清單也看得到。
class MoodleMemo {
  /// 課號 → 作業清單。
  final Map<String, List<MoodleAssignment>> assignments = {};

  /// assign id → 繳交狀態。
  final Map<int, Result<MoodleAssignSubmissionStatus>> statuses = {};

  /// discussion id → 清單上的那一列。討論串抓不到回覆時，至少把第一篇畫出來。
  final Map<int, Discussions> discussions = {};
}
