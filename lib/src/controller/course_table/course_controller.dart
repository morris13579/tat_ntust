import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_config.dart';
import 'package:flutter_app/src/enum/course_table_ui_state.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/userdata/user_data_json.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/task/course/course_semester_task.dart';
import 'package:flutter_app/src/task/course/course_table_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/ui/components/custom_snackbar.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:flutter_app/ui/pages/course_table/course_table_control.dart';
import 'package:flutter_app/ui/pages/course_table/custom_course_page.dart';
import 'package:flutter_app/ui/pages/course_table/modal/course_detail_dialog.dart';
import 'package:flutter_app/ui/pages/course_table/modal/favorite_dialog.dart';
import 'package:flutter_app/ui/pages/course_table/modal/semester_dialog.dart';
import 'package:flutter_app/ui/components/over_repaint_boundary.dart';
import 'package:flutter_app/ui/screen/login_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:sprintf/sprintf.dart';

import '../../task/cache_task.dart';
import '../../task/course/course_search_task.dart';

class CourseController extends GetxController {
  final RxString studentId = "".obs;
  final FocusNode studentFocus = FocusNode();
  final GlobalKey<OverRepaintBoundaryState> overRepaintKey = GlobalKey();
  final ScreenshotController screenshotController = ScreenshotController();
  final platform = const MethodChannel(AppConfig.methodChannelWidgetName);
  final GlobalKey key = GlobalKey();
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

    UserDataJson userData = Model.instance.getUserData();
    if (userData.account.isEmpty || userData.password.isEmpty) {
      isLoading.value = CourseTableUIState.loading;
      await Future.delayed(const Duration(milliseconds: 500));
      Get.offAll(() => const LoginScreen());
    } else {
      await _loadSetting();
    }
  }

  @override
  void onClose() {
    studentFocus.dispose();
    super.onClose();
  }

  void refreshSemester() {
    semesterSetting.value = courseTableData?.courseSemester ?? SemesterJson();
    semesterString.value =
        "${semesterSetting.value.year}-${semesterSetting.value.semester}";
  }

  Future<void> _loadSetting() async {
    CourseTableJson? courseTable = Model.instance.getCourseSetting().info;
    if (courseTable.isEmpty) {
      await getCourseTable();
    } else {
      _showCourseTable(courseTable);
    }
  }

  void showSemesterList() async {
    //顯示選擇學期
    if (Model.instance.getSemesterList().isEmpty) {
      TaskFlow taskFlow = TaskFlow();
      var task = CourseSemesterTask(studentId.value);
      taskFlow.addTask(task);
      if (await taskFlow.start()) {
        Model.instance.setSemesterJsonList(task.result);
      }
    }
    List<SemesterJson> semesterList = Model.instance.getSemesterList();

    Get.dialog(SemesterDialog(
        semesterList: semesterList,
        onSelected: (value) => getCourseTable(semesterSetting: value)));
  }

  Future<void> onPopupMenuSelect(int value) async {
    Map<int, Function> map = {
      0: _getCredit,
      1: _loadFavorite,
      2: _addCustomCourse,
      3: screenshot
    };

    if (!map.containsKey(value)) {
      return;
    }

    map[value]!();
  }

  Future<void> _getCredit() async {
    MyToast.show(
        "${R.current.credit}: ${courseTableData!.getTotalCredit().toString()}");
  }

  Future<void> getCourseTable(
      {SemesterJson? semesterSetting, bool refresh = false}) async {
    await Future.delayed(const Duration(microseconds: 100)); //等待頁面刷新
    String studentId = Model.instance.getAccount();
    SemesterJson? semesterJson;
    if (semesterSetting == null) {
      await _getSemesterList(studentId);
      semesterJson = Model.instance.getSemesterJsonItem(0);
    } else {
      semesterJson = semesterSetting;
    }
    if (semesterJson == null) {
      isLoading.value = CourseTableUIState.fail;
      return;
    }
    if (!semesterJson.isValid) {
      MyToast.show(
        sprintf(R.current.selectSemesterWarning, [semesterJson.year]),
        toastLength: Toast.LENGTH_LONG,
      );
      SemesterJson? select =
          await CourseSemesterTask.selectSemesterDialog(allowSelectNull: true);
      if (select == null) return;
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
      courseTable =
          Model.instance.getCourseTable(studentId, semesterSetting); //去取找是否已經暫存
    }
    if (courseTable == null) {
      //代表沒有暫存的需要爬蟲
      TaskFlow taskFlow = TaskFlow();
      final task = CourseTableTask(studentId, semesterJson);
      taskFlow.addTask(task);
      if (await taskFlow.start()) {
        courseTable = task.result;
      } else {
        isLoading.value = CourseTableUIState.fail;
      }
    }
    Model.instance.getCourseSetting().info = courseTable!; //儲存課表
    Model.instance.saveCourseSetting();
    _showCourseTable(courseTable);
  }

  Future<void> _getSemesterList(String studentId) async {
    TaskFlow taskFlow = TaskFlow();
    var task = CourseSemesterTask(studentId);
    taskFlow.addTask(task);
    if (await taskFlow.start()) {
      Model.instance.setSemesterJsonList(task.result);
    }
  }

  Future<void> _loadFavorite() async {
    List<CourseTableJson> value = Model.instance.getCourseTableList();
    if (value.isEmpty) {
      MyToast.show(R.current.noAnyFavorite);
      return;
    }
    Get.dialog(FavoriteDialog(
        value: value,
        onPressed: (index) {
          Model.instance.getCourseSetting().info = value[index]; //儲存課表
          Model.instance.saveCourseSetting();
          _showCourseTable(value[index]);
          Model.instance.clearSemesterJsonList(); //須清除已儲存學期
          Get.back();
        },
        onDelete: (index) async {
          Model.instance.removeCourseTable(value[index]);
          await Model.instance.saveCourseTableList();
        }));
  }

  //顯示課程對話框
  void showCourseDetailDialog(int section, CourseInfoJson courseInfo) {
    Get.dialog(CourseDetailDialog(
        courseInfo: courseInfo,
        time: courseTableControl.getTimeString(section),
        onDetailTap: () {
          _showCourseDetail(courseInfo, 0);
        },
        onMoodleTap: () {
          _showCourseData(courseInfo, 0);
        },
        onRemoveTap: () async {
          courseTableData!.removeCourseByCourseId(courseInfo.main.course.id);
          Model.instance.getCourseSetting().info = courseTableData!; //儲存課表
          Model.instance.saveCourseSetting();
          await _loadSetting();
        }));
  }

  void _showCourseData(CourseInfoJson courseInfo, int index) {
    CourseMainJson course = courseInfo.main.course;
    Get.back();

    if (course.id.isEmpty) {
      MyToast.show(course.name + R.current.noSupport);
      return;
    }

    RouteUtils.toCourseDataPage(courseInfo, index);
  }

  void _showCourseDetail(CourseInfoJson courseInfo, int index) {
    CourseMainJson course = courseInfo.main.course;

    if (course.id.isEmpty) {
      MyToast.show(course.name + R.current.noSupport);
      return;
    }

    RouteUtils.toCourseDetailPage(
        courseTableData!.courseSemester, courseInfo, index);
  }

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
    //如果第一次直接設成小工具
    Directory directory = await getApplicationSupportDirectory();
    String path = directory.path;
    if (!await File('$path/course_widget.png').exists()) {
      screenshot();
    }
  }

  Future screenshot() async {
    Uint8List? pngBytes = await screenshotController.capture();
    if(pngBytes == null) {
      return;
    }
    String path = (await getApplicationSupportDirectory()).path;
    File imgFile = File('$path/course_widget.png');
    await imgFile.writeAsBytes(pngBytes);
    final bool result = await platform.invokeMethod('update_weight');
    Log.d("complete $result");

    if (!result) {
      MyToast.show(R.current.settingCompleteWithError);
      return;
    }

    MyToast.show(R.current.settingComplete);
  }

  Future<void> onCustomCourseSearchSubmit(String value) async {
    FocusManager.instance.primaryFocus?.unfocus();
    CacheTask? task;

    final taskFlow = TaskFlow();
    task = CourseSearchTask(
        courseTableData!.courseSemester, value);
    taskFlow.addTask(task);
    if (await taskFlow.start()) {
      courseInfoList.value = task.result;
      if(courseInfoList.isEmpty) {
        CustomSnackBar.showCustomErrorSnackBar(title: R.current.error, message: R.current.courseSearchNotFound);
      }
    }
  }

  Future<void> _addCustomCourse() async {
    courseInfoList.clear();
    var info = await Get.to(() => const CustomCoursePage()) as CourseMainInfoJson?;
    if (info == null) {
      return;
    }
    info.course.select = false;
    if (!courseTableData!.addCourseDetailByCourseInfo(info)) {
      MyToast.show(R.current.addCustomCourseError);
    }
    Model.instance.getCourseSetting().info = courseTableData!; //儲存課表
    Model.instance.saveCourseSetting();
    _loadSetting();
  }
}
