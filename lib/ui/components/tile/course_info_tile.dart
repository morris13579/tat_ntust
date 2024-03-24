import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

class CourseInfoTile extends StatelessWidget {
  const CourseInfoTile(
      {super.key,
      required this.index,
      required this.title,
      required this.img,
      this.isShowArrow = false,
      required this.onTap});

  final int index;
  final String title;
  final String img;
  final bool isShowArrow;
  final Function() onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
        onTap: onTap,
        child: Container(
          color: getColor(index),
          height: 50,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: SvgPicture.asset(
                  "assets/image/$img.svg",
                  color: Get.iconColor,
                ),
              ),
              Expanded(
                child: Text(title),
              ),
              Visibility(
                  visible: isShowArrow,
                  child: const Icon(CupertinoIcons.right_chevron, size: 14)),
              const SizedBox(width: 8)
            ],
          ),
        ));
  }

  Color getColor(int index) {
    return (index % 2 == 1)
        ? Get.theme.backgroundColor
        : Get.theme.dividerColor;
  }
}
