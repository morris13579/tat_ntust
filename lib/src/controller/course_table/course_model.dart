import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/model/course/course_query_filter.dart';
import 'package:flutter_app/src/repository/ntust_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/my_toast.dart';
import 'package:sprintf/sprintf.dart';

/// 課表頁的資料操作。
///
/// **住在 controller 層而不是 lib/ui。** 放在 lib/ui 底下會讓 CourseController
/// 讀它變成 controller -> ui 的上行邊。手動選學期的對話框走 [TaskUiDelegate]。
class CourseModel {
  /// 取學期清單。
  ///
  /// [refreshIfIncomplete] 是給學期下拉選單用的：上一次可能只拿到當前學期
  /// （成績系統沒答），那份清單非空但只有一項。閘門若只看 `isEmpty`，選單
  /// 就會從此永遠只剩那一個學期。
  ///
  /// 只有下拉選單開這個開關，[getCourseTable] 的內部呼叫不開：那條路只需要
  /// `semesterAt(0)`，每次載入課表都重抓一次會多一顆進度框。
  Future<List<SemesterJson>> getSemesterList(
      {bool refreshIfIncomplete = false}) async {
    final cached = Model.instance.getSemesterList();
    final shouldFetch = cached.isEmpty ||
        (refreshIfIncomplete && !Model.instance.isSemesterListComplete());

    if (shouldFetch) {
      final result = await NtustRepository.instance.getSemesterList();
      final list = result.dataOrNull;
      if (list != null && list.isNotEmpty) {
        // [Stale] 代表歷年來源沒有貢獻。還是要存起來，課表得有學期才跑得
        // 動；但標成不完整，下次打開選單時再試一次。
        Model.instance.setSemesterJsonList(list, complete: result is Ok);
      } else if (Model.instance.getSemesterList().isEmpty) {
        // 三個來源全都沒有資料時才讓使用者手動選。repository 用 retry: none
        // 就是為了把這個決定留給呼叫端。
        //
        // 手上已經有一份（殘缺的）清單時不彈這個框：重試失敗就安靜留著
        // 舊的，不然離線時每開一次選單就被問一次要選哪個學期。
        final manual = await TaskUiDelegate.instance.chooseSemester();
        if (manual != null) {
          Model.instance.setSemesterJsonList([manual]);
        }
      }
    }
    return Model.instance.getSemesterList();
  }

  /// 啟動後的背景預載。
  ///
  /// 學期清單是純記憶體的，所以每次冷啟動都要重抓一次；而抓它要跑成績系統
  /// 的 headless WebView 加一次 Moodle 呼叫，使用者第一次點開學期下拉選單時
  /// 得站在那裡等。先在背景跑掉就不用等。
  ///
  /// **不可以有任何 UI。** 使用者沒有要求登入，所以走 `background: true`：
  /// 不開進度框，登入也只做安靜的那一段。失敗就安靜失敗——真的要用到清單時
  /// [getSemesterList] 會自己再抓一次，那時才是使用者主動要求的。
  Future<void> preloadSemesterList() async {
    if (Model.instance.getSemesterList().isNotEmpty) return;
    final result =
        await NtustRepository.instance.getSemesterList(background: true);
    final list = result.dataOrNull;
    if (list == null || list.isEmpty) return;
    Model.instance.setSemesterJsonList(list, complete: result is Ok);
  }

  CourseTableJson? getCourseSettingInfo() {
    CourseTableJson? courseTable = Model.instance.getCourseSetting().info;
    return courseTable;
  }

  List<CourseTableJson> getCacheCourseTableList() {
    return Model.instance.getCourseTableList();
  }

  Future<void> saveFavoriteCourse(CourseTableJson info) async {
    await saveCourse(info);
    // 學期清單是純記憶體的（CourseTableStore.clearSemesters 就是一行
    // `semesters = []`），這個 await 只是讓宣告與行為一致，沒有
    // 「沒等完就讀到舊快取」的競速。
    await Model.instance.clearSemesterJsonList(); //須清除已儲存學期
  }

  Future<void> removeFavoriteCourse(CourseTableJson info) async {
    Model.instance.removeCourseTable(info);
    await Model.instance.saveCourseTableList();
  }

  Future<CourseTableJson> getCourseTable(
      {SemesterJson? semesterSetting, bool refresh = false}) async {
    String studentId = Model.instance.getAccount();
    SemesterJson? semesterJson;

    if (semesterSetting == null) {
      await getSemesterList();
      semesterJson = Model.instance.getSemesterJsonItem(0);
    } else {
      semesterJson = semesterSetting;
    }

    if (semesterJson == null) {
      throw Exception();
    }

    if (!semesterJson.isValid) {
      MyToast.show(
          sprintf(R.current.selectSemesterWarning, [semesterJson.year]));
      SemesterJson? select =
          await TaskUiDelegate.instance.chooseSemester(allowNull: true);
      if (select == null) {
        throw Exception();
      }
      semesterJson.year = select.year;
      semesterJson.semester = select.semester;
      var s = Model.instance.getSemesterList();
      List<SemesterJson> v = [];
      for (var i in s) {
        if (!v.contains(i)) {
          v.add(i);
        }
      }
      Model.instance.setSemesterJsonList(v);
    }

    CourseTableJson? courseTable;
    if (!refresh) {
      //是否要去找暫存的
      // 要用上面剛解析好的 semesterJson，不是未解析的 semesterSetting：
      // Model.getCourseTable 對 null 直接回傳 null，快取會必定 miss。
      courseTable =
          Model.instance.getCourseTable(studentId, semesterJson); //去取找是否已經暫存
    }
    if (courseTable == null) {
      // 代表沒有暫存的需要爬蟲
      final result = await NtustRepository.instance
          .getCourseTable(studentId, semesterJson);
      courseTable = result.dataOrNull;
      if (courseTable == null) {
        throw Exception();
      }
    }
    return courseTable;
  }

  Future<List<CourseMainInfoJson>> getQueryCourse(
      SemesterJson semester, CourseQueryFilter filter) async {
    final result =
        await NtustRepository.instance.searchCourse(semester, filter);
    // 失敗回空清單，呼叫端把空清單當成「查無結果」。
    return result.dataOrNull ?? [];
  }

  /// 儲存目前顯示的課表。
  ///
  /// **兩份副本要一起寫。** setting blob 記的是「目前顯示哪一張」，
  /// course_table_list 是各學期的快取；快取命中路徑回傳的是 course_table_list
  /// 內的同一個實例，刪課、加課只改到記憶體。只寫 setting blob 的話磁碟上的
  /// course_table_list 會留著被刪掉的課，等 setting blob 被清掉（解析失敗或
  /// 登出）就會從那份陳舊快取命中，刪掉的課又回來了。
  Future<void> saveCourse(CourseTableJson table) async {
    Model.instance.getCourseSetting().info = table; //儲存課表
    await Model.instance.saveCourseSetting();
    if (table.studentId == Model.instance.getAccount()) {
      Model.instance.addCourseTable(table);
      await Model.instance.saveCourseTableList();
    }
  }
}
