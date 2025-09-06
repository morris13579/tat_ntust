import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/pages/course_data/screen/course_announcement_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/course_directory_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/course_score_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

class CourseDataPage extends StatefulWidget {
  final CourseInfoJson courseInfo;

  const CourseDataPage(
    this.courseInfo, {
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _CourseDataPageState();
}

class _CourseDataPageState extends State<CourseDataPage>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  List<Widget> _pages = [];
  List<Map<String, dynamic>> _tabItems = [];

  @override
  void initState() {
    super.initState();
    _pages = [
      CourseDirectoryPage(widget.courseInfo),
      CourseAnnouncementPage(widget.courseInfo),
      CourseScorePage(widget.courseInfo)
    ];
    _tabItems = [
      {
        "name": R.current.file,
        "icon": "img_file.svg"
      },
      {
        "name": R.current.announcement,
        "icon": "img_message.svg"
      },
      {
        "name": R.current.score,
        "icon": "img_education.svg"
      }
    ];
    _tabController = TabController(vsync: this, length: _tabItems.length);
  }

  @override
  Widget build(BuildContext context) {
    return tabPageView();
  }

  Widget tabPageView() {
    CourseMainJson course = widget.courseInfo.main.course;

    return DefaultTabController(
      length: _tabItems.length,
      child: Scaffold(
        appBar: baseAppbar(title: course.name, bottom: _buildTabBar(_tabItems)),
        body: PageView(
          controller: _pageController,
          children: _pages,
          onPageChanged: (index) {
            _tabController?.animateTo(index);
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
