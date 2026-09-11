import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/service/course_widget_service.dart';
import 'package:flutter_app/src/enum/course_table_ui_state.dart';
import 'package:flutter_app/src/service/store_review_service.dart';
import 'package:flutter_app/src/version/app_version.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/connector/course_connector.dart';
import 'package:flutter_app/src/model/course/course_department.dart';
import 'package:flutter_app/src/model/course/course_query_filter.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/util/my_toast.dart';
import 'package:flutter_app/src/controller/course_table/course_model.dart';
import 'package:flutter_app/src/util/course_table_control.dart';
import 'package:get/get.dart';
import 'package:screenshot/screenshot.dart';

class CourseController extends GetxController {
  final courseModel = CourseModel();
  final RxString studentId = "".obs;
  final ScreenshotController screenshotController = ScreenshotController();
  Rx<CourseTableUIState> isLoading = CourseTableUIState.loading.obs;
  CourseTableJson? courseTableData;
  RxDouble courseHeight = 60.0.obs;
  CourseTableControl courseTableControl = CourseTableControl();
  RxString semesterString = "".obs;
  RxList<CourseMainInfoJson> courseInfoList = <CourseMainInfoJson>[].obs;
  Rx<SemesterJson> semesterSetting = (SemesterJson()).obs;

  @override
  Future<void> onInit() async {
    super.onInit();

    refreshSemester();
    studentId.value = "";

    await _loadSetting();

    // 學期清單的背景預載：不 await，課表有自己的快取，不必等這一段。
    //
    // 必須用 post-frame callback——getSemesterList 這條路會碰到
    // `R.current`，那是 `S.of(Get.context!)` 的 lazy static，
    // navigator 還沒建好時會直接拋。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(courseModel.preloadSemesterList());
    });
  }

  /// Init
  Future<void> _loadSetting() async {
    CourseTableJson? courseTable = courseModel.getCourseSettingInfo();
    if (courseTable?.isEmpty == true) {
      await getCourseTable();
    } else {
      _showCourseTable(courseTable);
    }
  }

  /// Event Handler
  ///
  /// 學期下拉選單的資料來源。
  ///
  /// **只回資料，不開對話框。** controller 直接 `Get.dialog(...)` 會讓
  /// `lib/src/controller` 反向 import `lib/ui`，也就是 `tool/deps.py` 的
  /// controller -> ui 上行邊；這個檔案裡其餘「載入資料 → 由頁面決定怎麼
  /// 呈現」的方法同理。
  ///
  /// `refreshIfIncomplete: true`：使用者主動打開選單就是要看完整的歷年清單，
  /// 上一次只拿到當前學期時會再試一次。
  Future<List<SemesterJson>> loadSemesterList() =>
      courseModel.getSemesterList(refreshIfIncomplete: true);

  void refreshSemester() {
    semesterSetting.value = courseTableData?.courseSemester ?? SemesterJson();
    semesterString.value =
        "${semesterSetting.value.year}-${semesterSetting.value.semester}";
  }

  /// 目前課表的總學分。
  int get totalCredit => courseTableData?.getTotalCredit() ?? 0;

  /// 已收藏的課表。空的時候由頁面提示。
  List<CourseTableJson> get favorites => courseModel.getCacheCourseTableList();

  /// 登出時重設畫面狀態。由 SessionCleaner 的呼叫端觸發。
  ///
  /// **設成 fail 而不是 loading 是刻意的，別順手改回 loading。** 登出現在會
  /// `Get.offAll` 到登入頁，正常情況下沒人會看到這個狀態；但憑證在其他路徑上
  /// 失效時，這個 controller 可能還活著並且被重新顯示。停在 loading 就沒有
  /// 東西能把它推進下一個狀態——課表頁的 Get.put 對已註冊的 controller 是
  /// no-op，onInit/_loadSetting 不會再跑，畫面會永遠轉圈，而重新整理鈕與
  /// CourseMenu 又都包在 Visibility(visible: account.isNotEmpty) 裡。
  ///
  /// fail 會讓 BasePage 顯示 ErrorPage，帳號為空時它就是「請先登入」加登入鈕。
  void reset() {
    courseTableData = null;
    studentId.value = "";
    courseInfoList.clear();
    isLoading.value = CourseTableUIState.fail;
  }

  Future<void> getCourseTable(
      {SemesterJson? semesterSetting, bool refresh = false}) async {
    // CourseModel.getCourseTable 的三個失敗出口都是無訊息的 throw Exception()，
    // 不接住的話 _showCourseTable 不會執行，isLoading 停在 loading，課表頁
    // 就永遠轉圈。
    try {
      final courseTable = await courseModel.getCourseTable(
          semesterSetting: semesterSetting, refresh: refresh);
      await courseModel.saveCourse(courseTable);
      _showCourseTable(courseTable);
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      isLoading.value = CourseTableUIState.fail;
    }
  }

  /// 從課表上移除一門課。
  Future<void> removeCourse(CourseInfoJson courseInfo) async {
    if (courseTableData != null) {
      courseTableData!.removeCourseByCourseId(courseInfo.main.course.id);
      await courseModel.saveCourse(courseTableData!);
    }
    await _loadSetting();
  }

  /// 系所篩選的兩層資料。都是 querycourse 的公開端點，免憑證。
  Future<List<CollegeJson>> loadColleges() async =>
      await CourseConnector.getColleges() ?? [];

  Future<List<DepartmentJson>> loadDepartments(String collegeNo) async =>
      await CourseConnector.getDepartments(collegeNo) ?? [];

  /// 以課號移除。搜尋頁只拿得到課號，不是格子上的那個 CourseInfoJson。
  Future<void> removeCourseById(String courseId) async {
    if (courseTableData != null) {
      courseTableData!.removeCourseByCourseId(courseId);
      await courseModel.saveCourse(courseTableData!);
    }
    await _loadSetting();
  }

  /// 目前課表的學期。頁面導向課程詳情時要用。
  SemesterJson get currentSemester =>
      courseTableData?.courseSemester ?? SemesterJson();

  // 截圖課表Widget 設為桌面小工具
  /// 把目前的課表截圖設成 Android 桌面小工具。
  ///
  /// 只有 Android 有註冊 club.ntust.tat.widget，iOS 上呼叫必定拋
  /// MissingPluginException，所以只留使用者主動從選單觸發的路徑，不要再從
  /// 載入課表的流程自動呼叫。
  Future<void> setWidget() async {
    if (!GetPlatform.isAndroid) {
      MyToast.show(R.current.noFunction);
      return;
    }
    final pngBytes = await screenshotController.capture(pixelRatio: 2.0);
    if (pngBytes == null) {
      return;
    }
    // 寫檔與 MethodChannel 在 CourseWidgetService；controller 只負責截圖與
    // 提示。原生端回 false 代表使用者沒有把小工具加到主畫面。
    final result = await CourseWidgetService.instance.publish(pngBytes);
    if (!result) {
      MyToast.show(R.current.settingCompleteWithError);
      return;
    }
    MyToast.show(R.current.settingComplete);
  }

  /// 搜尋課程並把結果**回傳**，不寫進 [courseInfoList]。
  ///
  /// 模擬排課的搜尋頁自己管結果：它跟「導入其他課程」是兩條路，共用同一個
  /// observable 會讓其中一頁的搜尋結果跳到另一頁上。
  /// 搜尋課程。學期由呼叫端指定：模擬課表綁在自己的學年度上，不一定是目前
  /// 畫面上那一學期。
  Future<List<CourseMainInfoJson>> searchCourse(
          SemesterJson semester, CourseQueryFilter filter) =>
      courseModel.getQueryCourse(semester, filter);

  Future<void> onCustomCourseSearchSubmit(String value) async {
    FocusManager.instance.primaryFocus?.unfocus();
    var res = await courseModel.getQueryCourse(
        courseTableData!.courseSemester, CourseQueryFilter(courseNo: value));
    courseInfoList.value = res;
  }

  /// Private method
  /* Course Table */
  // 刷新畫面上課表
  void _showCourseTable(CourseTableJson? courseTable) async {
    if (courseTable == null || courseTable.isEmpty) {
      isLoading.value = CourseTableUIState.fail;
      return;
    }
    courseTableData = courseTable;
    studentId.value = courseTable.studentId;
    isLoading.value = CourseTableUIState.loading;
    courseTableControl.set(courseTable); //設定課表顯示狀態
    refreshSemester();
    await Future.delayed(const Duration(milliseconds: 50));
    isLoading.value = CourseTableUIState.success;
    // 課表載出來的這一刻是 App 最有用的時候，評分要問就問在這裡。
    // 它自己會判斷次數與間隔，多半什麼都不做；unawaited 是因為它跟課表無關。
    unawaited(StoreReviewService.instance
        .recordSuccess(await APPVersion.getAppVersion()));
  }

  /// 把使用者在自訂課程頁選好的課加進課表。
  ///
  /// 開那一頁是呼叫端的事——這裡只負責「加進去並存檔」。
  Future<void> addCustomCourse(CourseMainInfoJson info) async {
    courseInfoList.clear();
    info.course.select = false;
    if (!courseTableData!.addCourseDetailByCourseInfo(info)) {
      MyToast.show(R.current.addCustomCourseError);
    }
    await courseModel.saveCourse(courseTableData!);
    // 要 await，回傳的 Future 才真的代表「課加好而且畫面已經換成新課表」。
    await _loadSetting();
  }

  /// 套用一張收藏的課表。
  Future<void> applyFavorite(CourseTableJson info) async {
    await courseModel.saveFavoriteCourse(info);
    _showCourseTable(info);
  }

  Future<void> deleteFavorite(CourseTableJson info) =>
      courseModel.removeFavoriteCourse(info);
}
