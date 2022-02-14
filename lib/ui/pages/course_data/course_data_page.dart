import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/ui/other/my_progress_dialog.dart';
import 'package:flutter_app/ui/pages/course_data/screen/course_announcement_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/course_directory_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/course_score_page.dart';
import 'package:flutter_app/ui/pages/course_detail/tab_page.dart';
import 'package:get/get.dart';

class CourseDataPage extends StatefulWidget {
  final CourseInfoJson courseInfo;
  final int index;

  CourseDataPage(this.courseInfo, this.index);

  @override
  _CourseDataPageState createState() => _CourseDataPageState();
}

class _CourseDataPageState extends State<CourseDataPage>
    with SingleTickerProviderStateMixin {
  late TabPageList tabPageList;
  TabController? _tabController;
  PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    tabPageList = TabPageList();
    testMoodleWebApi();
  }

  void testMoodleWebApi() async {
    const moodleCheckKey = "moodle_api_check";
    if (Model.instance.getOtherSetting().useMoodleWebApi &&
        await Model.instance.getFirstUse(moodleCheckKey)) {
      Model.instance.setAlreadyUse(moodleCheckKey);
      MyProgressDialog.progressDialog(R.current.testMoodleApi);
      var result = await MoodleWebApiConnector.testMoodleWebApi();
      MyProgressDialog.hideAllDialog();
      Model.instance.getOtherSetting().useMoodleWebApi = result;
    }

    _tabController = TabController(vsync: this, length: 3);
    var filePage = TabPage(
        R.current.file,
        Icons.folder,
        CourseDirectoryPage(
          widget.courseInfo,
        ));
    var announcementPage = TabPage(
        R.current.announcement,
        Icons.message,
        CourseAnnouncementPage(
          widget.courseInfo,
        ));
    tabPageList.add((widget.index == 0) ? filePage : announcementPage);
    tabPageList.add((widget.index == 0) ? announcementPage : filePage);
    tabPageList.add(TabPage(
      R.current.score,
      Icons.score,
      CourseScorePage(widget.courseInfo),
    ));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        var currentState = tabPageList.getKey(_currentIndex).currentState;
        bool pop = (currentState == null) ? true : currentState.canPop();
        return pop;
      },
      child: tabPageView(),
    );
  }

  Widget tabPageView() {
    CourseMainJson course = widget.courseInfo.main.course;

    return DefaultTabController(
      length: tabPageList.length,
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () => Get.back(),
          ),
          title: Text(course.name),
          bottom: TabBar(
            indicatorPadding: EdgeInsets.all(0),
            labelPadding: EdgeInsets.all(0),
            isScrollable: true,
            controller: _tabController,
            tabs: tabPageList.getTabList(context),
            onTap: (index) {
              _pageController.jumpToPage(index);
              _currentIndex = index;
            },
          ),
        ),
        body: PageView(
          //控制滑動
          controller: _pageController,
          children: tabPageList.getTabPageList,
          onPageChanged: (index) {
            _tabController?.animateTo(index); //與上面tab同步
            _currentIndex = index;
          },
        ),
      ),
    );
  }
}
