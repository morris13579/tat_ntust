import 'package:flutter_app/src/model/moodle_webapi/moodle_gradereport_overview_course_grades.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:get/get.dart';

/// 「Moodle 目前成績」頁的狀態，由頁面的 State 建立與 [dispose]
/// （同 `AnnouncementCenterController`）。
class MoodleCourseGradesController {
  MoodleCourseGradesController();

  final Rxn<Result<MoodleCourseGradeList>> grades = Rxn();

  /// 進頁時的第一趟是背景模式：使用者只是點了一顆圖示，不該被丟一個登入
  /// WebView；沒登入時 `Failed(NotSignedIn)` 會讓 InlineErrorView 畫登入鈕。
  Future<void> load() async {
    grades.value = null;
    grades.value =
        await MoodleRepository.instance.getCourseGrades(background: true);
  }

  /// 下拉重新整理與重試：可以開登入頁、可以彈重試框，而且不把 Rxn 設回 null
  /// （RefreshIndicator 自己在轉圈，再閃一次 LoadingPage 是兩個轉圈）。
  Future<void> refresh() async {
    grades.value =
        await MoodleRepository.instance.getCourseGrades(background: false);
  }

  void dispose() => grades.close();
}
