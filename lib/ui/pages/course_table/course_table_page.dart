import 'dart:io';
import 'dart:ui' as ui;

import 'package:auto_size_text/auto_size_text.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_config.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/userdata/user_data_json.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/task/cache_task.dart';
import 'package:flutter_app/src/task/course/course_search_task.dart';
import 'package:flutter_app/src/task/course/course_semester_task.dart';
import 'package:flutter_app/src/task/course/course_table_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/src/util/remote_config_utils.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/ui/other/error_dialog.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:flutter_app/ui/pages/error/error_page.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sprintf/sprintf.dart';

import 'course_table_control.dart';
import 'over_repaint_boundary.dart';

class CourseTablePage extends StatefulWidget {
  const CourseTablePage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _CourseTablePageState();
}

enum CourseTableUIState { loading, fail, success }

class _CourseTablePageState extends State<CourseTablePage> {
  final TextEditingController _studentIdControl = TextEditingController();
  final FocusNode _studentFocus = FocusNode();
  final GlobalKey _key = GlobalKey();
  CourseTableUIState isLoading = CourseTableUIState.loading;
  CourseTableJson? courseTableData;
  static double dayHeight = 25;
  static double studentIdHeight = 40;
  static double courseHeight = 60;
  static double sectionWidth = 20;
  static int courseTableWithAlpha = 0xDF;
  static int showCourseTableNum = 9;
  CourseTableControl courseTableControl = CourseTableControl();

  @override
  void initState() {
    super.initState();
    _studentIdControl.text = " ";
    UserDataJson userData = Model.instance.getUserData();
    Future.delayed(const Duration(milliseconds: 200)).then((_) {
      if (userData.account.isEmpty || userData.password.isEmpty) {
        setState(() {
          isLoading = CourseTableUIState.fail;
        });
        RouteUtils.toLoginScreen();
      } else {
        _loadSetting();
      }
    });
  }

  @override
  void setState(fn) {
    super.setState(fn);
  }

  @override
  void dispose() {
    _studentFocus.dispose();
    super.dispose();
  }

  void _loadSetting() {
    RenderObject? renderObject = _key.currentContext!.findRenderObject();
    courseHeight = (renderObject!.semanticBounds.size.height -
            studentIdHeight -
            dayHeight) /
        showCourseTableNum; //計算高度
    CourseTableJson? courseTable = Model.instance.getCourseSetting().info;
    if (courseTable.isEmpty) {
      _getCourseTable();
    } else {
      _showCourseTable(courseTable);
    }
  }

  Future<void> _getSemesterList(String studentId) async {
    TaskFlow taskFlow = TaskFlow();
    var task = CourseSemesterTask(studentId);
    taskFlow.addTask(task);
    if (await taskFlow.start()) {
      Model.instance.setSemesterJsonList(task.result);
    }
  }

  void _getCourseTable(
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
      setState(() {
        isLoading = CourseTableUIState.fail;
      });
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
        setState(() {
          isLoading = CourseTableUIState.fail;
        });
      }
    }
    Model.instance.getCourseSetting().info = courseTable!; //儲存課表
    Model.instance.saveCourseSetting();
    _showCourseTable(courseTable);
  }

  Widget _buildSemesterItem(SemesterJson semester) {
    String semesterString = semester.year;
    if (semester.semester.isNotEmpty) {
      semesterString += ("-${semester.semester}");
    }
    return TextButton(
      child: Text(semesterString),
      onPressed: () async {
        Get.back();
        _getCourseTable(semesterSetting: semester); //取得課表
      },
    );
  }

  void _showSemesterList() async {
    //顯示選擇學期
    _unFocusStudentInput();
    if (Model.instance.getSemesterList().isEmpty) {
      TaskFlow taskFlow = TaskFlow();
      var task = CourseSemesterTask(_studentIdControl.text);
      taskFlow.addTask(task);
      if (await taskFlow.start()) {
        Model.instance.setSemesterJsonList(task.result);
      }
    }
    List<SemesterJson> semesterList = Model.instance.getSemesterList();
    //Model.instance.saveSemesterJsonList();
    Get.dialog(
        AlertDialog(
          content: SizedBox(
            width: double.minPositive,
            child: ListView.builder(
              itemCount: semesterList.length,
              shrinkWrap: true, //使清單最小化
              itemBuilder: (BuildContext context, int index) {
                return _buildSemesterItem(semesterList[index]);
              },
            ),
          ),
        ),
        barrierDismissible: true);
  }

  _onPopupMenuSelect(int value) async {
    switch (value) {
      case 0:
        MyToast.show(sprintf("%s:%s",
            [R.current.credit, courseTableData!.getTotalCredit().toString()]));
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

  @override
  Widget build(BuildContext context) {
    SemesterJson semesterSetting =
        courseTableData?.courseSemester ?? SemesterJson();
    String semesterString =
        "${semesterSetting.year}-${semesterSetting.semester}";
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(R.current.titleCourse),
        actions: [
          IconButton(
            icon: const Icon(Icons.announcement_outlined),
            padding: const EdgeInsets.all(8.0),
            iconSize: 24,
            onPressed: () {
              RemoteConfigUtils.showAnnouncementDialog(allTime: true);
            },
            enableFeedback: true,
          ),
          if (Model.instance.getAccount().isNotEmpty)
            IconButton(
              icon: const Icon(EvaIcons.refreshOutline),
              padding: const EdgeInsets.all(8.0),
              iconSize: 24,
              onPressed: () {
                _getCourseTable(
                  semesterSetting: semesterSetting,
                  refresh: true,
                );
              },
              enableFeedback: true,
            ),
          if (Model.instance.getAccount().isNotEmpty)
            PopupMenuButton<int>(
              onSelected: (result) {
                setState(() {
                  _onPopupMenuSelect(result);
                });
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem(
                  value: 0,
                  child: Text(R.current.searchCredit),
                ),
                PopupMenuItem(
                  value: 1,
                  child: Text(R.current.loadFavorite),
                ),
                if (_studentIdControl.text == Model.instance.getAccount())
                  PopupMenuItem(
                    value: 2,
                    child: Text(R.current.importCourse),
                  ),
                if (Platform.isAndroid)
                  PopupMenuItem(
                    value: 3,
                    child: Text(R.current.setAsAndroidWeight),
                  ),
              ],
            )
        ],
      ),
      body: Column(
        key: _key,
        children: <Widget>[
          Container(
            height: studentIdHeight,
            color: Theme.of(context).backgroundColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    scrollPadding: const EdgeInsets.all(0),
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      // 關閉框線
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(10),
                      hintText: R.current.pleaseEnterStudentId,
                    ),
                    onEditingComplete: () {
                      _studentFocus.unfocus();
                    },
                    controller: _studentIdControl,
                    focusNode: _studentFocus,
                    /*
                    toolbarOptions: ToolbarOptions(
                      copy: true,
                      paste: true,
                    ),
                     */
                  ),
                ),
                TextButton(
                  child: Row(
                    children: <Widget>[
                      Text(
                        semesterString,
                        textAlign: TextAlign.center,
                      ),
                      const Padding(
                        padding: EdgeInsets.all(5),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                  onPressed: () {
                    _showSemesterList();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildListViewWithScreenshot(),
          ),
        ],
      ),
    );
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

  final GlobalKey<OverRepaintBoundaryState> overRepaintKey = GlobalKey();

  Widget _buildListViewWithScreenshot() {
    return SingleChildScrollView(
      child: OverRepaintBoundary(
        key: overRepaintKey,
        child: RepaintBoundary(
          child: (isLoading != CourseTableUIState.success)
              ? Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          //makes the red row full width
                          child: SizedBox(
                            height: courseHeight * showCourseTableNum,
                            child: (isLoading == CourseTableUIState.loading)
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : const ErrorPage(),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Column(
                  children: List.generate(
                    1 + courseTableControl.getSectionIntList.length,
                    (index) {
                      Widget widget;
                      widget = (index == 0)
                          ? _buildDay()
                          : _buildCourseTable(index - 1);
                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 375),
                        child: ScaleAnimation(
                          child: FadeInAnimation(
                            child: widget,
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDay() {
    List<Widget> widgetList = [];
    widgetList.add(Container(
      width: sectionWidth,
    ));
    for (int i in courseTableControl.getDayIntList) {
      widgetList.add(
        Expanded(
          child: Text(
            courseTableControl.getDayString(i),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Container(
      color: Theme.of(context).backgroundColor.withAlpha(courseTableWithAlpha),
      height: dayHeight,
      child: Row(
        children: widgetList,
      ),
    );
  }

  Widget _buildCourseTable(int index) {
    int section = courseTableControl.getSectionIntList[index];
    Color color;
    color = (index % 2 == 1)
        ? Theme.of(context).backgroundColor
        : Theme.of(context).dividerColor;
    color = color.withAlpha(courseTableWithAlpha);
    List<Widget> widgetList = [];
    widgetList.add(
      Container(
        width: sectionWidth,
        alignment: Alignment.center,
        child: Text(
          courseTableControl.getSectionString(section),
          textAlign: TextAlign.center,
        ),
      ),
    );
    for (int day in courseTableControl.getDayIntList) {
      CourseInfoJson? courseInfo =
          courseTableControl.getCourseInfo(day, section);
      Color color = courseTableControl.getCourseInfoColor(day, section);
      courseInfo = courseInfo ?? CourseInfoJson();
      widgetList.add(
        Expanded(
          child: (courseInfo.isEmpty)
              ? Container()
              : Container(
                  padding: const EdgeInsets.all(1),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(0),
                      backgroundColor: color,
                    ),
                    child: AutoSizeText(
                      courseInfo.main.course.name,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                      ),
                      minFontSize: 10,
                      maxLines: 3,
                      textAlign: TextAlign.center,
                    ),
                    onPressed: () {
                      showCourseDetailDialog(section, courseInfo!);
                    },
                  ),
                ),
        ),
      );
    }
    return Container(
      color: color,
      height: courseHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widgetList,
      ),
    );
  }

  //顯示課程對話框
  void showCourseDetailDialog(int section, CourseInfoJson courseInfo) {
    _unFocusStudentInput();
    CourseMainJson course = courseInfo.main.course;
    String classroomName = courseInfo.main.getClassroomName();
    String teacherName = courseInfo.main.getTeacherName();
    String studentId = Model.instance.getCourseSetting().info.studentId;
    setState(() {
      _studentIdControl.text = studentId;
    });
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
                setState(() {});
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

  void _unFocusStudentInput() {
    FocusScope.of(context).requestFocus(FocusNode()); //失焦使鍵盤關閉
    _studentFocus.unfocus();
  }

  void _showCourseTable(CourseTableJson? courseTable) async {
    if (courseTable == null || courseTable.isEmpty) {
      setState(() {
        isLoading = CourseTableUIState.fail;
      });
      return;
    }
    courseTableData = courseTable;
    _studentIdControl.text = courseTable.studentId;
    _unFocusStudentInput();
    setState(() {
      isLoading = CourseTableUIState.loading;
    });
    courseTableControl.set(courseTable); //設定課表顯示狀態
    await Future.delayed(const Duration(milliseconds: 50));
    setState(() {
      isLoading = CourseTableUIState.success;
    });
    //如果第一次直接設成小工具
    Directory directory = await getApplicationSupportDirectory();
    String path = directory.path;
    if (!await File('$path/course_widget.png').exists()) {
      screenshot();
    }
  }

  static const platform = MethodChannel(AppConfig.methodChannelWidgetName);

  Future screenshot() async {
    double originHeight = courseHeight;
    RenderObject? renderObject = _key.currentContext!.findRenderObject();
    double height =
        renderObject!.semanticBounds.size.height - studentIdHeight - dayHeight;
    Directory directory = await getApplicationSupportDirectory();
    String path = directory.path;
    setState(() {
      courseHeight = height / courseTableControl.getSectionIntList.length;
    });
    await Future.delayed(const Duration(milliseconds: 100));
    setState(() {
      isLoading = CourseTableUIState.loading;
    });
    Log.d(path);

    final RenderRepaintBoundary boundary = overRepaintKey.currentContext!
        .findRenderObject()! as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 2);
    setState(() {
      courseHeight = originHeight;
      isLoading = CourseTableUIState.success;
    });
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
