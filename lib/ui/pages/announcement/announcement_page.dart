import 'dart:async';

import 'package:card_swiper/card_swiper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/announcement/announcement_json.dart';
import 'package:flutter_app/src/util/remote_config_utils.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';

class AnnouncementPage extends StatefulWidget {
  final List<AnnouncementInfoJson> info;
  final int countDown;

  const AnnouncementPage({
    Key? key,
    required this.info,
    required this.countDown,
  }) : super(key: key);

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
    return AlertDialog(
      title: Text(widget.info[index].title),
      contentPadding: EdgeInsets.only(
        left: 24.0,
        top: Theme.of(context).useMaterial3 ? 16.0 : 20.0,
        right: 24.0,
        bottom: 0.0,
      ),
      content: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(Get.context!).size.height * 0.6,
          width: MediaQuery.of(Get.context!).size.width * 0.85,
          child: Swiper(
            loop: false,
            itemCount: widget.info.length,
            controller: controller,
            pagination: SwiperPagination(
              // SwiperPagination.fraction 數字1/5，默認點
              builder: DotSwiperPaginationBuilder(
                size: 8,
                activeSize: 12,
                color: Theme.of(context).primaryColor,
                activeColor: Theme.of(context).primaryColorDark,
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
                  onTapLink: (String text, String? href, String title) {
                    RouteUtils.toWebViewPage(title, href!);
                  },
                ),
              );
            },
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: count > 0
              ? null
              : () {
                  Get.back<bool>(result: true);
                  RemoteConfigUtils.setAnnouncementRead();
                },
          child: Text(count > 0 ? "${R.current.wait} $count" : R.current.sure),
        ),
      ],
    );
  }
}
