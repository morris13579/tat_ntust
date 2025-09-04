import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/controller/main_page/main_controller.dart';
import 'package:flutter_app/src/providers/app_provider.dart';
import 'package:flutter_app/src/util/analytics_utils.dart';
import 'package:flutter_app/ui/components/page/loading_page.dart';
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
        return Scaffold(
          body: _buildPageView(),
          bottomNavigationBar: _buildBottomNavigationBar(),
        );
      },
    );
  }

  Widget _buildPageView() {
    return Obx(() {
      if(controller.pageList.isEmpty) {
        return const LoadingPage(isLoading: true);
      }
      return PageView(
          controller: controller.pageController,
          onPageChanged: controller.onPageChanged,
          physics: const NeverScrollableScrollPhysics(),
          children: controller.pageList
      );
    });
  }

  Widget _buildBottomNavigationBar() {
    final items = [
      {
        "icon": "img_clock.svg",
        "name": R.current.titleCourse
      },
      {
        "icon": "img_info.svg",
        "name": R.current.informationSystem
      },
      {
        "icon": "img_calendar.svg",
        "name": R.current.calendar
      },
      {
        "icon": "img_book.svg",
        "name": R.current.titleScore
      },
      {
        "icon": "img_menu.svg",
        "name": R.current.titleOther
      }
    ];

    return Obx(() {
      var currentIndex = controller.currentIndex.value;

      return BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: controller.onBottomNavigationTap,
        items: items.map((item) {
          final index = items.indexOf(item);
          return BottomNavigationBarItem(
            icon: SvgPicture.asset(
              "assets/image/${item["icon"]}",
              color: currentIndex == index
                  ? Get.theme.bottomNavigationBarTheme.selectedItemColor
                  : Get.theme.bottomNavigationBarTheme.unselectedItemColor,
            ),
            label: item["name"],
          );
        }).toList()
      );
    });
  }
}
