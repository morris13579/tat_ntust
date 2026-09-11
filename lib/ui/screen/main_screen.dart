import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/ui/pages/score/score_page.dart';
import 'package:flutter_app/ui/pages/other/other_page.dart';
import 'package:flutter_app/ui/pages/course_table/course_table_page.dart';
import 'package:flutter_app/ui/pages/calendar/calendar_page.dart';
import 'package:flutter_app/ui/routes/route_utils.dart';
import 'package:flutter_app/src/controller/announcement/notification_badge_controller.dart';
import 'package:flutter_app/src/controller/main_page/main_controller.dart';
import 'package:flutter_app/src/util/analytics_utils.dart';
import 'package:get/get.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<StatefulWidget> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with RouteAware, WidgetsBindingObserver {
  // 註冊在 AppBindings（lazyPut + fenix），這裡只取用。
  final controller = Get.find<MainController>();

  /// 一定要是 getter：欄位只在 State 建立時初始化，而 forceAppUpdate 只重跑
  /// build()、不重建 State，導覽列標籤會永遠停在啟動時的語言。
  List<Map<String, dynamic>> get items => [
        {"icon": LucideIcons.table, "name": R.current.titleCourse},
        {"icon": LucideIcons.calendarDays, "name": R.current.calendar},
        {"icon": LucideIcons.graduationCap, "name": R.current.titleScore},
        {"icon": LucideIcons.menu, "name": R.current.titleMore}
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AnalyticsUtils.observer
        .subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  /// 課表是預設分頁，停在它把 App 丟到背景再回來不會觸發 `onPageChanged`，
  /// 沒有這一段紅點就會一直停在進 App 那一刻的數字——那正是輪詢要解決的情境。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(NotificationBadgeController.instance.refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AnalyticsUtils.observer.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildPageView(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  /// 四個分頁。**順序必須與 [MainTab] 一致**——底下的導覽列與 controller 的
  /// 分析事件都是靠索引對應的。清單放在這裡，controller 才不必 import 頁面。
  ///
  /// 資訊系統不在這裡：它是用系統的名字命名的入口，擺在導覽列反而容易被
  /// 整個忽略，現在從「更多」的最上面進去。
  static const _pages = [
    CourseTablePage(),
    CalendarPage(openInApp: RouteUtils.tryOpenUpcomingEvent),
    ScoreViewerPage(),
    OtherPage(),
  ];

  Widget _buildPageView() {
    return PageView(
      controller: controller.pageController,
      onPageChanged: controller.onPageChanged,
      physics: const NeverScrollableScrollPhysics(),
      children: _pages,
    );
  }

  Widget _buildBottomNavigationBar() {
    return Obx(() {
      var currentIndex = controller.currentIndex.value;

      return NavigationBar(
        // 選取狀態只由這個索引表達。**不要**改成拿 item 去 items.indexOf：
        // items 是 getter，每次讀都是新的 Map，而 Map 沒有覆寫 ==，跨兩次
        // 讀取的 indexOf 一律回 -1。
        selectedIndex: currentIndex,
        onDestinationSelected: controller.onBottomNavigationTap,
        destinations: [
          for (final item in items)
            NavigationDestination(
              // 圖示的顏色與尺寸一律交給 NavigationBarThemeData，在這裡再塗
              // 一次會蓋掉主題。
              icon: Icon(item["icon"] as IconData),
              label: item["name"] as String,
            ),
        ],
      );
    });
  }
}
