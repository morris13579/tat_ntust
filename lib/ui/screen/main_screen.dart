import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/controller/main_page/main_controller.dart';
import 'package:flutter_app/src/providers/app_provider.dart';
import 'package:flutter_app/src/util/analytics_utils.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<StatefulWidget> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with RouteAware {
  var controller = Get.put(MainController());

  @override
  void initState() {
    super.initState();
    controller.appInit();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AnalyticsUtils.observer
        .subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    AnalyticsUtils.observer.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (BuildContext context, AppProvider appProvider, Widget? child) {
        appProvider.navigatorKey = Get.key;
        return Obx(() {
          return Scaffold(
            backgroundColor: Colors.white,
            body: _buildPageView(),
            bottomNavigationBar: _buildBottomNavigationBar(),
          );
        });
      },
    );
  }

  Widget _buildPageView() {
    return PageView(
        controller: controller.pageController,
        onPageChanged: controller.onPageChanged,
        physics: const NeverScrollableScrollPhysics(),
        children: controller.pageList
    );
  }

  Widget _buildBottomNavigationBar() {
    var index = controller.currentIndex.value;
    return BottomNavigationBar(
      currentIndex: index,
      type: BottomNavigationBarType.fixed,
      onTap: controller.onBottomNavigationTap,
      items: [
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            "assets/image/img_clock.svg",
            color: index == 0
                ? Get.theme.bottomNavigationBarTheme.selectedItemColor
                : Get.theme.bottomNavigationBarTheme.unselectedItemColor,
          ),
          label: R.current.titleCourse,
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            "assets/image/img_info.svg",
            color: index == 1
                ? Get.theme.bottomNavigationBarTheme.selectedItemColor
                : Get.theme.bottomNavigationBarTheme.unselectedItemColor,
          ),
          label: R.current.informationSystem,
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            "assets/image/img_calendar.svg",
            color: index == 2
                ? Get.theme.bottomNavigationBarTheme.selectedItemColor
                : Get.theme.bottomNavigationBarTheme.unselectedItemColor,
          ),
          label: R.current.calendar,
        ),
        BottomNavigationBarItem(
            icon: SvgPicture.asset(
              "assets/image/img_book.svg",
              color: index == 3
                  ? Get.theme.bottomNavigationBarTheme.selectedItemColor
                  : Get.theme.bottomNavigationBarTheme.unselectedItemColor,
            ),
            label: R.current.titleScore),
        BottomNavigationBarItem(
            icon: SvgPicture.asset(
              "assets/image/img_menu.svg",
              color: index == 4
                  ? Get.theme.bottomNavigationBarTheme.selectedItemColor
                  : Get.theme.bottomNavigationBarTheme.unselectedItemColor,
            ),
            label: R.current.titleOther),
      ],
    );
  }
}
