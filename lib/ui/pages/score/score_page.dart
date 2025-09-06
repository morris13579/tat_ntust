import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_colors.dart';
import 'package:flutter_app/src/controller/score_page/score_page_controller.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/page/error_page.dart';
import 'package:get/get.dart';

class ScoreViewerPage extends GetView<ScorePageController> {
  const ScoreViewerPage({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(ScorePageController());

    return Obx(
      () {
        switch (controller.state.value) {
          case ScoreUIState.success:
            return _buildContentPage();
          case ScoreUIState.loading:
            return _buildLoadingPage();
          case ScoreUIState.fail:
            return _buildErrorPage();
          case ScoreUIState.notLogin:
            return _buildNotLoginPage();
        }
      },
    );
  }

  Widget _buildContentPage() {
    return DefaultTabController(
      length: controller.tabLabelList.length,
      child: Scaffold(
        appBar: mainAppbar(
            title: R.current.searchScore,
            action: [
              IconButton(
                icon: const Icon(CupertinoIcons.refresh),
                splashRadius: 18,
                iconSize: 24,
                onPressed: () async {
                  controller.initTask(refresh: true);
                },
                tooltip: R.current.update,
              ),
            ],
            bottom: TabBar(
              controller: controller.tabController,
              isScrollable: true,
              tabs: controller.tabLabelList,
              onTap: controller.toIndex,
            )),
        body: TabBarView(
          controller: controller.tabController,
          children: controller.tabChildList,
        ),
      ),
    );
  }

  Widget _buildErrorPage() {
    return Scaffold(
      appBar: mainAppbar(title: R.current.searchScore, action: [
        IconButton(
          icon: const Icon(CupertinoIcons.refresh),
          splashRadius: 18,
          iconSize: 24,
          onPressed: () async {
            controller.initTask(refresh: true);
          },
          tooltip: R.current.update,
        ),
      ]),
      body: const ErrorPage(),
    );
  }

  Widget _buildLoadingPage() {
    return Scaffold(
      appBar: mainAppbar(title: R.current.searchScore),
      body: const Text(""),
    );
  }

  Widget _buildNotLoginPage() {
    return Scaffold(
      appBar: mainAppbar(title: R.current.searchScore),
      body: const ErrorPage(),
    );
  }
}
