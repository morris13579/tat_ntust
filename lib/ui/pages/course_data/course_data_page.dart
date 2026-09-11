import 'dart:async';

import 'package:flutter_app/src/controller/course_data/course_data_controller.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/page/error_page.dart';
import 'package:flutter_app/ui/components/tat_tab_bar.dart';
import 'package:flutter_app/ui/pages/course_data/screen/course_announcement_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/course_assignment_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/course_directory_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/course_score_page.dart';
import 'package:flutter_app/ui/routes/route_utils.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';

class CourseDataPage extends StatefulWidget {
  /// 「成績」在 `_pages` / `_tabItems` 裡的位置。呼叫端要直接開那一頁時用它，
  /// 不要寫死 2。
  static const int scoreTab = 2;

  final CourseInfoJson courseInfo;

  /// 進頁時落在哪一個分頁。
  final int initialTab;

  const CourseDataPage(
    this.courseInfo, {
    this.initialTab = 0,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _CourseDataPageState();
}

class _CourseDataPageState extends State<CourseDataPage>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  late final PageController _pageController;
  List<Widget> _pages = [];

  /// getter 而不是 initState 裡指派的欄位：initState 只跑一次，切換語言後
  /// 分頁標籤會停在舊語言。長度固定，TabController 照樣讀得到。
  List<Map<String, dynamic>> get _tabItems => [
        {"name": R.current.file, "icon": LucideIcons.fileText},
        {"name": R.current.announcement, "icon": LucideIcons.messagesSquare},
        {"name": R.current.score, "icon": LucideIcons.graduationCap},
        {"name": R.current.assignment, "icon": LucideIcons.clipboardList},
      ];

  late final CourseDataController _controller;

  @override
  void initState() {
    super.initState();
    // 兩個都要跟著 initialTab，少設一個第一幀的指示器與內容就對不上。
    _pageController = PageController(initialPage: widget.initialTab);
    _controller = CourseDataController(widget.courseInfo.main.course.id);
    // 四個分頁一起抓，不等使用者滑過去；見 CourseDataController。
    unawaited(_controller.loadAll());
    _pages = [
      CourseDirectoryPage(widget.courseInfo, controller: _controller),
      // 公告與作業分頁不能 import ErrorPage / RouteUtils，所以由這裡注入。
      CourseAnnouncementPage(
        widget.courseInfo,
        controller: _controller,
        errorBuilder: (message) => ErrorPage(errorMsg: message),
        openWebView: RouteUtils.toWebViewPage,
      ),
      CourseScorePage(widget.courseInfo, controller: _controller),
      CourseAssignmentPage(
        widget.courseInfo,
        controller: _controller,
        errorBuilder: (message) => ErrorPage(errorMsg: message),
        openWebView: RouteUtils.toWebViewPage,
      ),
    ];
    _tabController = TabController(
      vsync: this,
      length: _tabItems.length,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    _tabController?.dispose();
    super.dispose();
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
          onPageChanged: (index) => _tabController?.animateTo(index),
        ),
      ),
    );
  }

  /// 分頁列的樣式在 [TatTabBar]，這裡只給內容。
  PreferredSizeWidget _buildTabBar(List<Map<String, dynamic>> items) {
    return TatTabBar(
      isScrollable: false,
      controller: _tabController,
      tabs: [
        for (final item in items)
          Tab(
            icon: Icon(item["icon"] as IconData, size: 21),
            iconMargin: const EdgeInsets.only(bottom: 7),
            child: AutoSizeText(
              item["name"] as String,
              maxLines: 1,
              minFontSize: 6,
            ),
          ),
      ],
      onTap: (index) => _pageController.jumpToPage(index),
    );
  }
}
