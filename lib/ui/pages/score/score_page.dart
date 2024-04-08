import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_colors.dart';
import 'package:flutter_app/src/controller/score_page/score_page_controller.dart';
import 'package:flutter_app/ui/components/page/error_page.dart';
import 'package:get/get.dart';

class ScoreViewerPage extends StatefulWidget {
  const ScoreViewerPage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ScoreViewerPageState();
}

class _ScoreViewerPageState extends State<ScoreViewerPage> {
  final ScorePageController controller = Get.put(ScorePageController());

  @override
  void dispose() {
    Get.delete<ScorePageController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        switch (controller.state.value) {
          case ScoreUIState.success:
            return DefaultTabController(
              length: controller.tabLabelList.length,
              child: Scaffold(
                appBar: AppBar(
                  title: Text(R.current.searchScore),
                  actions: [
                    IconButton(
                      onPressed: () {
                        controller.initTask(refresh: true);
                      },
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                  bottom: TabBar(
                    controller: controller.tabController,
                    labelColor: AppColors.mainColor,
                    unselectedLabelColor: Colors.white,
                    indicatorSize: TabBarIndicatorSize.label,
                    indicator: const BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                      ),
                      color: Colors.white,
                    ),
                    isScrollable: true,
                    tabs: controller.tabLabelList,
                    onTap: (int index) {
                      controller.toIndex(index);
                    },
                  ),
                ),
                body: TabBarView(
                  controller: controller.tabController,
                  children: controller.tabChildList,
                ),
              ),
            );
          case ScoreUIState.loading:
            return Scaffold(
              appBar: AppBar(title: Text(R.current.searchScore)),
              body: const Text(""),
            );
          case ScoreUIState.fail:
            return Scaffold(
              appBar: AppBar(
                title: Text(R.current.searchScore),
                actions: [
                  IconButton(
                    onPressed: () {
                      controller.initTask(refresh: true);
                    },
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              body: const ErrorPage(),
            );
          case ScoreUIState.notLogin:
            return Scaffold(
              appBar: AppBar(title: Text(R.current.searchScore)),
              body: const ErrorPage(),
            );
        }
      },
    );
  }
}
