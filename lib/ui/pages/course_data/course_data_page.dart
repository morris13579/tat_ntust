import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/other/my_progress_dialog.dart';
import 'package:flutter_app/ui/pages/course_data/screen/course_announcement_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/course_directory_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/course_score_page.dart';
import 'package:flutter_app/ui/pages/course_detail/tab_page.dart';
import 'package:get/get.dart';

class CourseDataPage extends StatefulWidget {
  final CourseInfoJson courseInfo;
  final int index;

  const CourseDataPage(
    this.courseInfo,
    this.index, {
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _CourseDataPageState();
}

class _CourseDataPageState extends State<CourseDataPage>
    with SingleTickerProviderStateMixin {
  late TabPageList tabPageList;
  TabController? _tabController;
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    testMoodleWebApi();

    tabPageList = TabPageList();
    _tabController = TabController(vsync: this, length: 3);
    var filePage = TabPage(
        R.current.file,
        "img_file.svg",
        CourseDirectoryPage(
          widget.courseInfo,
        ));
    var announcementPage = TabPage(
        R.current.announcement,
        "img_message.svg",
        CourseAnnouncementPage(
          widget.courseInfo,
        ));
    tabPageList.add((widget.index == 0) ? filePage : announcementPage);
    tabPageList.add((widget.index == 0) ? announcementPage : filePage);
    tabPageList.add(TabPage(
      R.current.score,
      "img_education.svg",
      CourseScorePage(widget.courseInfo),
    ));
    setState(() {});
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
        appBar: baseAppbar(
          title: course.name,
          bottom: TabBar(
            indicatorColor: Get.theme.indicatorColor,
            indicatorPadding: const EdgeInsets.all(0),
            isScrollable: false,
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
