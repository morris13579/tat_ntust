import 'dart:async';

import 'package:card_swiper/card_swiper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/announcement/announcement_json.dart';
import 'package:flutter_app/src/util/remote_config_utils.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/ui/components/page/base_page.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

class AnnouncementPage extends StatefulWidget {
  final List<AnnouncementInfoJson> info;
  final int countDown;

  const AnnouncementPage({
    super.key,
    required this.info,
    required this.countDown,
  });

  @override
  State<StatefulWidget> createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends State<AnnouncementPage> {
  late List<SwiperController> controllers;
  late SwiperController controller;
  int index = 0;
  late int count;

  @override
  void initState() {
    controller = SwiperController();
    count = widget.countDown;
    Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        count--;
      });
      if (count == 0) {
        timer.cancel();
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
        title: widget.info[index].title,
        action: [
          btnConfirm()
        ],
        child: SizedBox(
          height: Get.height,
          width: Get.width,
          child: Swiper(
            loop: false,
            itemCount: widget.info.length,
            controller: controller,
            pagination: SwiperPagination(
              builder: DotSwiperPaginationBuilder(
                size: 8,
                activeSize: widget.info.length == 1 ? 0 : 12,
                space: 12,
                color: Colors.grey,
                activeColor: Get.iconColor,
              ),
            ),
            onIndexChanged: (i) {
              setState(() {
                index = i;
              });
            },
            itemBuilder: (context, index) {
              return Container(
                padding: const EdgeInsets.only(bottom: 35),
                child: Markdown(
                  selectable: true,
                  shrinkWrap: true,
                  data: widget.info[index].content,
                  styleSheet: MarkdownStyleSheet.fromTheme(Get.theme.copyWith(
                      textTheme: Get.textTheme.copyWith(
                          bodyMedium: Get.textTheme.bodyMedium
                              ?.copyWith(height: 1.2)))),
                  onTapLink: (String text, String? href, String title) {
                    if (href != null) {
                      launchUrlString(href);
                    }
                  },
                ),
              );
            },
          ),
        ));
  }

  Widget btnConfirm() {
    return TextButton(
      onPressed: count > 0
          ? null
          : () {
        Get.back<bool>(result: true);
        RemoteConfigUtils.setAnnouncementRead();
      },
      child:
      Text(count > 0 ? "${R.current.wait} $count" : R.current.sure),
    );
  }
}
