import 'dart:io';
import 'dart:ui' as ui;

import 'package:auto_size_text/auto_size_text.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_config.dart';
import 'package:flutter_app/src/config/course_config.dart';
import 'package:flutter_app/src/enum/course_table_ui_state.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/userdata/user_data_json.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/task/course/course_semester_task.dart';
import 'package:flutter_app/src/task/course/course_table_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/ui/other/error_dialog.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:flutter_app/ui/pages/course_table/component/semester_item.dart';
import 'package:flutter_app/ui/pages/course_table/course_table_control.dart';
import 'package:flutter_app/ui/pages/course_table/over_repaint_boundary.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sprintf/sprintf.dart';

import '../../task/cache_task.dart';
import '../../task/course/course_search_task.dart';

class CourseController extends GetxController {
  final RxString studentId = "".obs;
  final FocusNode studentFocus = FocusNode();
  final GlobalKey<OverRepaintBoundaryState> overRepaintKey = GlobalKey();
  final platform = const MethodChannel(AppConfig.methodChannelWidgetName);
  final GlobalKey key = GlobalKey();
  Rx<CourseTableUIState> isLoading = CourseTableUIState.loading.obs;
  CourseTableJson? courseTableData;
  RxDouble courseHeight = 60.0.obs;
  CourseTableControl courseTableControl = CourseTableControl();
  RxString semesterString = "".obs;
  Rx<SemesterJson> semesterSetting = (SemesterJson()).obs;

  @override
  void onInit() {
    super.onInit();

    refreshSemester();
    studentId.value = "";

    UserDataJson userData = Model.instance.getUserData();
    if (userData.account.isEmpty || userData.password.isEmpty) {
      isLoading.value = CourseTableUIState.fail;
      RouteUtils.toLoginScreen();
    } else {
      _loadSetting();
    }
  }

  @override
  void onClose() {
    studentFocus.dispose();
    super.onClose();
  }

  void refreshSemester() {
    semesterSetting.value = courseTableData?.courseSemester ?? SemesterJson();
    semesterString.value = "${semesterSetting.value.year}-${semesterSetting.value.semester}";
  }

  void _loadSetting() {
    CourseTableJson? courseTable = Model.instance.getCourseSetting().info;
    if (courseTable.isEmpty) {
      getCourseTable();
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

    Get.dialog(
        AlertDialog(
          content: SizedBox(
            width: double.minPositive,
            child: ListView.builder(
              itemCount: semesterList.length,
              shrinkWrap: true, //使清單最小化
              itemBuilder: (BuildContext context, int index) {
                return SemesterItem(semester: semesterList[index], onPress: (value) {
                  getCourseTable(semesterSetting: value);
                });
              },
            ),
          ),
        ),
        barrierDismissible: true);
  }

  onPopupMenuSelect(int value) async {
    switch (value) {
      case 0:
        MyToast.show(sprintf("%s:%s", [R.current.credit, courseTableData!.getTotalCredit().toString()]));
        break;
      case 1:
        _loadFavorite();
        break;
      case 2:
        await _addCustomCourse();
        break;
      case 3:
        await screenshot();
        break;
      default:
        break;
    }
  }

  void getCourseTable(
      {SemesterJson? semesterSetting, bool refresh = false}) async {
    await Future.delayed(const Duration(microseconds: 100)); //等待頁面刷新
    String studentId = Model.instance.getAccount();
    //await Model.instance.clearSemesterJsonList();
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
      SemesterJson? select;
      MyToast.show(
        sprintf(R.current.selectSemesterWarning, [semesterJson.year]),
        toastLength: Toast.LENGTH_LONG,
      );
      select =
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

  void _loadFavorite() async {
    List<CourseTableJson> value = Model.instance.getCourseTableList();
    if (value.isEmpty) {
      MyToast.show(R.current.noAnyFavorite);
      return;
    }
    Get.dialog(
      StatefulBuilder(
        builder:
            (BuildContext context, void Function(void Function()) setState) {
          return AlertDialog(
            content: SizedBox(
              width: double.minPositive,
              child: ListView.builder(
                itemCount: value.length,
                shrinkWrap: true, //使清單最小化
                itemBuilder: (BuildContext context, int index) {
                  return SizedBox(
                    height: 50,
                    child: TextButton(
                      child: Text(sprintf("%s %s %s-%s", [
                        value[index].studentId,
                        value[index].studentName,
                        value[index].courseSemester.year,
                        value[index].courseSemester.semester
                      ])),
                      onPressed: () {
                        Model.instance.getCourseSetting().info =
                        value[index]; //儲存課表
                        Model.instance.saveCourseSetting();
                        _showCourseTable(value[index]);
                        Model.instance.clearSemesterJsonList(); //須清除已儲存學期
                        Get.back();
                      },
                      onLongPress: () async {
                        ErrorDialogParameter parameter = ErrorDialogParameter(
                            desc: "",
                            btnOkText: R.current.sure,
                            title: R.current.delete,
                            dialogType: DialogType.warning);
                        var result = await ErrorDialog(parameter).show();
                        if (result) {
                          Model.instance.removeCourseTable(value[index]);
                          //value.removeAt(index);
                          await Model.instance.saveCourseTableList();
                          setState(() {});
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
      barrierDismissible: true,
    );
  }


  //顯示課程對話框
  void showCourseDetailDialog(int section, CourseInfoJson courseInfo) {
    CourseMainJson course = courseInfo.main.course;
    String classroomName = courseInfo.main.getClassroomName();
    String teacherName = courseInfo.main.getTeacherName();
    String studentId = Model.instance.getCourseSetting().info.studentId;

    this.studentId.value = studentId;

    Get.dialog(
      AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 10.0, 10.0),
        title: Text(course.name),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            GestureDetector(
              child: Text(sprintf("%s : %s", [R.current.courseId, course.id])),
              onLongPress: () async {
                course.id = await _showEditDialog(course.id);
                Model.instance.saveOtherSetting();
              },
            ),
            Text(sprintf("%s : %s",
                [R.current.time, courseTableControl.getTimeString(section)])),
            Text(sprintf("%s : %s", [R.current.location, classroomName])),
            Text(sprintf("%s : %s", [R.current.instructor, teacherName])),
          ],
        ),
        actions: <Widget>[
          (courseInfo.main.course.select)
              ? TextButton(
            onPressed: () {
              _showCourseData(courseInfo, 0);
            },
            onLongPress: () {
              _showCourseData(courseInfo, 1);
            },
            child: Text(R.current.courseData),
          )
              : TextButton(
            onPressed: () {
              Get.back();
              courseTableData!
                  .removeCourseByCourseId(courseInfo.main.course.id);
              Model.instance.getCourseSetting().info =
              courseTableData!; //儲存課表
              Model.instance.saveCourseSetting();
              _loadSetting();
            },
            child: Text(R.current.remove),
          ),
          TextButton(
            onPressed: () {
              _showCourseDetail(courseInfo, 0);
            },
            onLongPress: () {
              _showCourseDetail(courseInfo, 1);
            },
            child: Text(R.current.details),
          )
        ],
      ),
      barrierDismissible: true,
    );
  }

  Future<String> _showEditDialog(String value) async {
    final TextEditingController controller = TextEditingController();
    controller.text = value;
    String? v = await Get.dialog<String>(
      AlertDialog(
        contentPadding: const EdgeInsets.all(16.0),
        title: const Text('Edit'),
        content: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(hintText: value),
              ),
            )
          ],
        ),
        actions: <Widget>[
          TextButton(
              child: Text(R.current.cancel),
              onPressed: () {
                Get.back(result: null);
              }),
          TextButton(
              child: Text(R.current.sure),
              onPressed: () {
                Get.back<String>(result: controller.text);
              })
        ],
      ),
      barrierDismissible: true,
    );
    return v ?? value;
  }

  void _showCourseData(CourseInfoJson courseInfo, int index) {
    CourseMainJson course = courseInfo.main.course;
    Get.back();
    if (course.id.isEmpty) {
      MyToast.show(course.name + R.current.noSupport);
    } else {
      RouteUtils.toCourseDataPage(courseInfo, index);
    }
  }

  void _showCourseDetail(CourseInfoJson courseInfo, int index) {
    CourseMainJson course = courseInfo.main.course;
    Get.back();
    if (course.id.isEmpty) {
      MyToast.show(course.name + R.current.noSupport);
    } else {
      RouteUtils.toCourseDetailPage(
          courseTableData!.courseSemester, courseInfo, index);
    }
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
    double originHeight = courseHeight.value;
    RenderObject? renderObject = key.currentContext!.findRenderObject();
    double height =
        renderObject!.semanticBounds.size.height - CourseConfig.studentIdHeight - CourseConfig.dayHeight;
    Directory directory = await getApplicationSupportDirectory();
    String path = directory.path;
    courseHeight.value = height / courseTableControl.getSectionIntList.length;
    await Future.delayed(const Duration(milliseconds: 100));

    isLoading.value = CourseTableUIState.loading;
    Log.d(path);

    final RenderRepaintBoundary boundary = overRepaintKey.currentContext!
        .findRenderObject()! as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 2);

    courseHeight.value = originHeight;
    isLoading.value = CourseTableUIState.success;

    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    Uint8List pngBytes = byteData!.buffer.asUint8List();
    File imgFile = File('$path/course_widget.png');
    await imgFile.writeAsBytes(pngBytes);
    final bool result = await platform.invokeMethod('update_weight');
    Log.d("complete $result");
    if (result) {
      MyToast.show(R.current.settingComplete);
    } else {
      MyToast.show(R.current.settingCompleteWithError);
    }
  }

  _addCustomCourse() {
    final control = TextEditingController();
    CacheTask? task;
    bool taskDone = false;
    Get.dialog(
      StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
        return AlertDialog(
          title: Text(R.current.importCourse),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(R.current.importCourseWarning),
                  TextField(
                    controller: control,
                    decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        labelText: R.current.inputCourseName,
                        prefixIconColor: Colors.black,
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
                        floatingLabelStyle: const TextStyle(color: Colors.blue)
                    ),
                    onEditingComplete: () async {
                      FocusScope.of(context).unfocus();
                      setState(() {
                        taskDone = false;
                      });
                      final taskFlow = TaskFlow();
                      task = CourseSearchTask(
                          courseTableData!.courseSemester, control.text);
                      taskFlow.addTask(task!);
                      if (await taskFlow.start()) {
                        setState(() {
                          taskDone = true;
                        });
                      }
                    },
                  ),
                  if (taskDone)
                    Column(
                      children: task?.result
                          .map<Widget>(
                            (info) => Container(
                          padding:
                          const EdgeInsets.only(top: 10, bottom: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Expanded(
                                child: AutoSizeText(
                                  sprintf("%s\n%s\n%s\n%s\n%s\n%s\n%s", [
                                    "${R.current.courseId}: ${info.course.id}",
                                    "${R.current.courseName}: ${info.course.name}",
                                    "${R.current.instructor}: ${info.getTeacherName()}",
                                    "${R.current.startClass}: ${info.getOpenClassName()}",
                                    "${R.current.classroom}: ${info.getClassroomName()}",
                                    "${R.current.time}: ${info.getTime()}",
                                    "${R.current.note}: ${info.course.note}",
                                  ]),
                                ),
                              ),
                              IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () {
                                    info.course.select = false;
                                    if (!courseTableData!
                                        .addCourseDetailByCourseInfo(
                                        info)) {
                                      MyToast.show(
                                          R.current.addCustomCourseError);
                                    }
                                    Get.back();
                                    Model.instance.getCourseSetting().info =
                                    courseTableData!; //儲存課表
                                    Model.instance.saveCourseSetting();
                                    _loadSetting();
                                  })
                            ],
                          ),
                        ),
                      )
                          .toList(),
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}