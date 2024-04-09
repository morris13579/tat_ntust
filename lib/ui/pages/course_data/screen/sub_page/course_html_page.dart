import 'package:flutter/material.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/page/error_page.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

class CourseHtmlPage extends StatelessWidget {
  const CourseHtmlPage({super.key, required this.ap});
  final Modules ap;

  Future<String> getPageData() async {
    var params = Connector.uriAddQuery(
      ap.contents.first.fileurl,
      {"token": MoodleWebApiConnector.wsToken},
    );
    var html = await DioConnector.instance.getDataByGet(ConnectorParameter(params));
    return html;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: baseAppbar(
          title: ap.name
        ),
        body: FutureBuilder<String>(
          future: getPageData(),
          builder:
              (BuildContext context, AsyncSnapshot snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.data == null) {
                return const ErrorPage();
              } else {
                return Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: HtmlWidget(
                    snapshot.data,
                    textStyle: const TextStyle(height: 1.2),
                    renderMode: RenderMode.column,
                    onTapUrl: (String s) {
                      RouteUtils.toWebViewPage("", s);
                      return true;
                    },
                  ),
                );
              }
            } else {
              return const Text("");
            }
          },
        ),
    );
  }
}
