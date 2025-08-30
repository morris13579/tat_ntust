import 'package:expansion_tile_card/expansion_tile_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/file/file_download.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:flutter_app/src/util/open_utils.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_html_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

class CourseInfoPage extends StatefulWidget {
  final CourseInfoJson courseInfo;
  final MoodleCoreCourseGetContents contents;

  const CourseInfoPage(
    this.courseInfo,
    this.contents, {
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _CourseInfoPageState();
}

class _CourseInfoPageState extends State<CourseInfoPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: baseAppbar(
          title: widget.contents.name,
        ),
        body: buildTree());
  }

  String getIcon(String type) {
    switch (type) {
      case "forum":
        return "img_message";
      case "assign":
        return "img_clipboard";
      case "folder":
        return "img_folder";
      case "label":
        return "img_tag";
      case "url":
        return "img_link";
      default:
        return "img_copy";
    }
  }

  void openWebView(Modules ap, {openWithExternalWebView = false}) async {
    RouteUtils.toWebViewPage(
        ap.name,
        Connector.uriAddQuery(
          ap.url,
          (LanguageUtils.getLangIndex() == LangEnum.zh)
              ? {"lang": "zh_tw"}
              : {"lang": "en"},
        ),
        openWithExternalWebView: openWithExternalWebView);
  }

  void handleTap(Modules ap) async {
    switch (ap.modname) {
      case "forum":
        openWebView(ap);
        break;
      case "assign":
        openWebView(ap);
        break;
      case "folder":
        if (ap.contents.isNotEmpty || ap.folderIsNone) {
          RouteUtils.toCourseFolderPage(widget.courseInfo, ap);
        } else {
          MyToast.show(R.current.nothingHere);
        }
        break;
      case "label":
        break;
      case "url":
        if(ap.contents.isNotEmpty) {
          OpenUtils.launchURL(ap.contents.first.fileurl);
        }
        break;
      case "page":
        Get.to(() => CourseHtmlPage(ap: ap));
        break;
      case "resource":
      default:
        String dirName = widget.courseInfo.main.course.name;
        FileDownload.download(
            context,
            Connector.uriAddQuery(
              ap.contents.first.fileurl,
              {"token": MoodleWebApiConnector.wsToken},
            ),
            dirName,
            name: ap.contents.first.filename);
    }
  }

  final titleTextStyle = const TextStyle(fontSize: 14, height: 1.2);

  Widget buildItem(Modules ap, int index) {
    switch (ap.modname) {
      case "label":
        return Container(
            padding: const EdgeInsets.only(left: 20, top: 10, bottom: 10),
            child: HtmlWidget(
              ap.description,
              renderMode: RenderMode.column,
            ));
      default:
        if (ap.description.isNotEmpty) {
          return ExpansionTileCard(
            expandedTextColor: Theme.of(context).textTheme.bodyMedium!.color,
            expandedColor: getColor(index),
            baseColor: getColor(index),
            title: Text(
              ap.name,
              style: titleTextStyle,
            ),
            children: [
              Container(
                padding: const EdgeInsets.only(left: 20),
                child: HtmlWidget(
                  ap.description,
                  renderMode: RenderMode.column,
                ),
              ),
              SizedBox(
                height: 50,
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        child: SvgPicture.asset("assets/image/img_download.svg", color: Get.iconColor),
                        onTap: () {
                          handleTap(ap);
                        },
                      ),
                    )
                  ],
                ),
              )
            ],
          );
        }
        return Container(
          height: 50,
          padding: const EdgeInsets.only(left: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  ap.name,
                  style: titleTextStyle,
                  overflow: TextOverflow.fade,
                  maxLines: 2,
                ),
              )
            ],
          ),
        );
    }
  }

  Color getColor(int index) {
    return (index % 2 == 1)
        ? Theme.of(context).scaffoldBackgroundColor
        : Theme.of(context).dividerColor;
  }

  Widget buildTree() {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: widget.contents.modules.length,
      itemBuilder: (BuildContext context, int index) {
        var ap = widget.contents.modules[index];

        return InkWell(
          child: Container(
            color: getColor(index),
            child: Row(
              children: [
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: SvgPicture.asset("assets/image/${getIcon(ap.modname)}.svg", color: Get.iconColor,)),
                Expanded(
                  child: buildItem(ap, index),
                ),
              ],
            ),
          ),
          onTap: () async {
            handleTap(ap);
          },
        );
      },
    );
  }
}
