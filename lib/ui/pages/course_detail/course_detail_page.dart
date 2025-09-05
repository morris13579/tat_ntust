import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/pages/course_detail/screen/course_info_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import 'screen/course_member_page.dart';

class CourseDetailPage extends StatefulWidget {
  final CourseInfoJson courseInfo;
  final SemesterJson semester;

  const CourseDetailPage(
    this.courseInfo,
    this.semester, {
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: 2);
  }

  @override
  Widget build(BuildContext context) {
    return tabPageView();
  }

  Widget tabPageView() {
    CourseMainJson course = widget.courseInfo.main.course;
    final items = [
      {
        "name": R.current.course,
        "icon": "img_info.svg",
        "page": CourseInfoPage(
          widget.courseInfo.main.course.id,
          widget.semester,
        )
      },
      {
        "name": R.current.member,
        "icon": "img_group.svg",
        "page": CourseMemberPage(
          widget.courseInfo.main.course.id,
          widget.semester,
        ),
      }
    ];

    return DefaultTabController(
      length: items.length,
      child: Scaffold(
        appBar: baseAppbar(
          title: course.name,
          bottom: _buildTabBar(items),
        ),
        body: PageView(
          //控制滑動
          controller: _pageController,
          children: items.map((item) => item["page"] as Widget).toList(),
          onPageChanged: (index) {
            _tabController.animateTo(index);
            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ),
    );
  }

  TabBar _buildTabBar(List<dynamic> items) {
    return TabBar(
      isScrollable: false,
      controller: _tabController,
      indicatorSize: TabBarIndicatorSize.tab,
      tabs: items.map((item) {
        final index = items.indexOf(item);
        return Tab(
          icon: SvgPicture.asset("assets/image/${item["icon"]}",
              color: _currentIndex == index
                  ? Get.theme.colorScheme.primary
                  : Get.theme.colorScheme.onSurface,
              height: 24),
          iconMargin: const EdgeInsets.only(bottom: 6),
          child: AutoSizeText(
            item["name"] as String,
            maxLines: 1,
            minFontSize: 6,
          ),
        );
      }).toList(),
      onTap: (index) {
        _pageController.jumpToPage(index);
        _currentIndex = index;
      },
    );
  }
}
