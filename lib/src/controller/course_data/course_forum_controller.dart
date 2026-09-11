import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:get/get.dart';

/// 一個討論區的狀態：主題清單；由頁面的 State 建立與 [dispose]，生命週期就是
/// 那一個頁面（同 `CourseAssignmentController`）。
class CourseForumController {
  CourseForumController({required this.forumId});

  /// forum instance id（`Modules.instance`），不是 cmid。
  final int forumId;

  final discussions = Rxn<Result<List<Discussions>>>();

  /// [keepVisible] 給討論串頁改動之後的重抓用：畫面上已經有清單時不要先清成
  /// null，否則會在使用者眼前閃一次整頁轉圈。
  Future<void> loadDiscussions({bool keepVisible = false}) async {
    if (!keepVisible || discussions.value?.dataOrNull == null) {
      discussions.value = null;
    }
    discussions.value =
        await MoodleRepository.instance.getForumDiscussions(forumId);
  }

  void dispose() {
    discussions.close();
  }
}
