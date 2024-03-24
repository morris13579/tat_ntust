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
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/ui/components/custom_snackbar.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:flutter_app/ui/pages/course_table/model/course_model.dart';
import 'package:flutter_app/ui/pages/course_table/model/course_table_control.dart';
import 'package:flutter_app/ui/pages/course_table/custom_course_page.dart';
import 'package:flutter_app/ui/pages/course_table/modal/course_detail_dialog.dart';
import 'package:flutter_app/ui/pages/course_table/modal/favorite_dialog.dart';
import 'package:flutter_app/ui/pages/course_table/modal/semester_dialog.dart';
import 'package:flutter_app/ui/components/over_repaint_boundary.dart';
import 'package:flutter_app/ui/screen/login/login_screen.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';


class CourseController extends GetxController {
  final courseModel = CourseModel();
  final RxString studentId = "".obs;
  final ScreenshotController screenshotController = ScreenshotController();
  final platform = const MethodChannel(AppConfig.methodChannelWidgetName);
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

  void refreshSemester() {
    semesterSetting.value = courseTableData?.courseSemester ?? SemesterJson();
    semesterString.value =
        "${semesterSetting.value.year}-${semesterSetting.value.semester}";
  }

  Future<void> _loadSetting() async {
    CourseTableJson? courseTable = courseModel.getCourseSettingInfo();
    if (courseTable?.isEmpty == true) {
      await getCourseTable();
    } else {
      _showCourseTable(courseTable);
    }
  }

  Future<void> showSemesterList() async {
    var semesterList = await courseModel.getSemesterList(studentId.value);
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
    CourseTableJson courseTable = await courseModel.getCourseTable(semesterSetting: semesterSetting, refresh: refresh);
    courseModel.saveCourse(courseTable);
    _showCourseTable(courseTable);
  }

  Future<void> _loadFavorite() async {
    List<CourseTableJson> value = courseModel.getCacheCourseTableList();
    if (value.isEmpty) {
      MyToast.show(R.current.noAnyFavorite);
      return;
    }
    Get.dialog(FavoriteDialog(
        value: value,
        onPressed: (index) {
          CourseTableJson info = value[index];
          courseModel.saveFavoriteCourse(info);
          _showCourseTable(info);
          Get.back();
        },
        onDelete: (index) => courseModel.removeFavoriteCourse(value[index])));
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
          if(courseTableData != null) {
            courseTableData!.removeCourseByCourseId(courseInfo.main.course.id);
            courseModel.saveCourse(courseTableData!);
          }
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
    Uint8List? pngBytes = await screenshotController.capture(pixelRatio: 2.0);
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
    var res = await courseModel.getQueryCourse(courseTableData!.courseSemester, value);
    courseInfoList.value = res;
    if(courseInfoList.isEmpty) {
      CustomSnackBar.showCustomErrorSnackBar(title: R.current.error, message: R.current.courseSearchNotFound);
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
    courseModel.saveCourse(courseTableData!);
    _loadSetting();
  }
}
