import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/controller/course_table/course_controller.dart';
import 'package:flutter_app/ui/components/card/course_search_card.dart';
import 'package:flutter_app/ui/components/input/search_bar.dart';
import 'package:flutter_app/ui/components/page/base_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:sprintf/sprintf.dart';

class CustomCoursePage extends GetView<CourseController> {
  const CustomCoursePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return BasePage(title: R.current.importCourse, child: contentView());
    });
  }

  Widget contentView() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
        child: CourseSearchBar(
          onSubmit: controller.onCustomCourseSearchSubmit,
        ),
      ),
      Expanded(
          child: controller.courseInfoList.isEmpty ? hintView() : listView())
    ]);
  }

  Widget listView() {
    return Scrollbar(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: controller.courseInfoList.length,
        itemBuilder: (context, index) {
          var info = controller.courseInfoList[index];
          return CourseSearchCard(
            info: info,
            onTap: (info) {
              Get.back(result: info);
            },
          );
        },
        separatorBuilder: (BuildContext context, int index) {
          return const SizedBox(height: 12);
        },
      ),
    );
  }

  Widget hintView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset("assets/image/img_search.svg",
              color: Colors.grey, height: 76),
          const SizedBox(height: 24),
          Text(R.current.courseSearchHint, style: const TextStyle(fontSize: 16, color: Colors.grey),),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
