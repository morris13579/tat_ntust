import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_config.dart';
import 'package:flutter_app/src/config/app_themes.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/providers/app_provider.dart';
import 'package:flutter_app/ui/pages/course_detail/screen/course_info_page.dart';
import 'package:flutter_app/ui/pages/course_detail/tab_page.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'screen/course_member.dart';

class CourseDetailPage extends StatefulWidget {
  final CourseInfoJson courseInfo;
  final SemesterJson semester;
  final int index;

  CourseDetailPage(this.courseInfo, this.semester, this.index);

  @override
  _CourseDetailPageState createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage>
    with SingleTickerProviderStateMixin {
  late TabPageList tabPageList;
  late TabController _tabController;
  PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    tabPageList = TabPageList();
    var courseInfoPage = TabPage(
      R.current.course,
      Icons.info,
      CourseInfoPage(
        widget.courseInfo.main.course.id,
        widget.semester,
      ),
    );

    var courseMemberPage = TabPage(
      R.current.member,
      Icons.people,
      CourseMemberPage(
        widget.courseInfo.main.course.id,
      ),
    );

    tabPageList.add((widget.index == 0) ? courseInfoPage : courseMemberPage);
    tabPageList.add((widget.index == 0) ? courseMemberPage : courseInfoPage);

    _tabController = TabController(vsync: this, length: tabPageList.length);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (BuildContext context, AppProvider appProvider, Widget? child) {
        return WillPopScope(
          onWillPop: () async {
            var currentState = tabPageList.getKey(_currentIndex).currentState;
            bool pop = (currentState == null) ? true : currentState.canPop();
            return pop;
          },
          child: MaterialApp(
            title: AppConfig.appName,
            theme: appProvider.theme,
            darkTheme: AppThemes.darkTheme,
            home: tabPageView(),
          ),
        );
      },
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
            _tabController.animateTo(index); //與上面tab同步
            _currentIndex = index;
          },
        ),
      ),
    );
  }
}
