import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

class TabPage {
  late GlobalKey<NavigatorState> navigatorKey;
  late Widget tab;
  late Widget tabPage;

  TabPage(String title, String path, Widget initPage,
      {useNavigatorKey = false}) {
    navigatorKey = GlobalKey();
    tab = Tab(
      icon: SvgPicture.asset("assets/image/$path", color: Get.iconColor, height: 24),
      iconMargin: const EdgeInsets.only(bottom: 6),
      height: 64.0,
      child: AutoSizeText(
        title,
        maxLines: 1,
        minFontSize: 6,
      ),
    );
    tabPage = (useNavigatorKey)
        ? Navigator(
            key: navigatorKey,
            onGenerateRoute: (routeSettings) {
              return MaterialPageRoute(builder: (context) => initPage);
            })
        : initPage;
  }
}

class TabPageList {
  late List<TabPage> tabPageList;

  TabPageList() {
    tabPageList = [];
  }

  void add(TabPage page) {
    tabPageList.add(page);
  }

  List<Widget> get getTabPageList {
    List<Widget> pages = [];
    for (TabPage tabPage in tabPageList) {
      pages.add(tabPage.tabPage);
    }
    return pages;
  }

  List<Widget> getTabList(BuildContext context) {
    List<Widget> pages = [];
    double width = MediaQuery.of(context).size.width / length;
    for (TabPage tabPage in tabPageList) {
      Widget tabNew = SizedBox(
        width: width,
        child: tabPage.tab,
      );
      pages.add(tabNew);
    }
    return pages;
  }

  Widget getPage(int index) {
    return tabPageList[index].tabPage;
  }

  GlobalKey<NavigatorState> getKey(int index) {
    return tabPageList[index].navigatorKey;
  }

  int get length {
    return tabPageList.length;
  }
}
