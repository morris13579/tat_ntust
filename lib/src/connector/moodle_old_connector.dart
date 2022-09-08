import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_enrol_get_users.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';

class MoodleOldConnector {
  static const String host = "https://moodle.ntust.edu.tw";
  static const String _loginUrl = "$host/login/index.php";
  static const String _userUrl = "$host/user/index.php";
  static const String _viewUrl = "$host/course/view.php";
  static const String _branchUrl = "$host/lib/ajax/getnavbranch.php";
  static const String _scoreUrl = "$host/grade/report/user/index.php";
  static String? id;

  static Future<MoodleConnectorStatus> login(
      String account, String password) async {
    String result;
    Document tagNode;
    List<Element> nodes;
    ConnectorParameter parameter;
    try {
      String? loginToken;

      parameter = ConnectorParameter(_loginUrl);
      result = await Connector.getRedirects(parameter);
      tagNode = parse(result);

      if (result.contains(account.toUpperCase())) {
        //代表已經登入了
        return MoodleConnectorStatus.loginSuccess;
      }

      nodes = tagNode.getElementsByTagName("input");
      for (var i in nodes) {
        if (i.attributes["name"] != null &&
            i.attributes["name"]!.contains("logintoken")) {
          loginToken = i.attributes["value"];
          break;
        }
      }
      Map<String, String> data = {
        "username": account,
        "password": password,
        "anchor": "",
        "logintoken": loginToken!
      };
      parameter.data = data;
      result = await Connector.getRedirects(parameter, usePost: true);

      parameter = ConnectorParameter(host);
      result = await Connector.getDataByGet(parameter);
      return (result.contains("登出"))
          ? MoodleConnectorStatus.loginSuccess
          : MoodleConnectorStatus.loginFail;
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return MoodleConnectorStatus.loginFail;
    }
  }

  static Future<String> getCourseUrl(String courseId) async {
    String result;
    Document tagNode;
    Element node;
    List<Element> nodes;
    ConnectorParameter parameter;
    try {
      String? courseUrl;
      parameter = ConnectorParameter(host);
      result = await Connector.getDataByGet(parameter);
      tagNode = parse(result);

      node = tagNode.getElementById("custom_menu_courses")!;
      nodes = node.getElementsByClassName("dropdown-menu");
      nodes = nodes[0].getElementsByTagName("a");
      for (var i in nodes) {
        String courseTitle = i.attributes["title"]!;
        if (courseTitle.contains(courseId)) {
          courseUrl = i.attributes["href"];
        }
      }
      id = null;
      if (courseUrl == null) {
        throw Exception("courseUrl is null");
      }
      id = Uri.parse(courseUrl).queryParameters["id"];
      return id!;
    } catch (e) {
      rethrow;
    }
  }

  static Future<List<MoodleCoreEnrolGetUsers>?> getMember(
      String courseId) async {
    String result;
    Document tagNode;
    Element node;
    List<Element> nodes;
    ConnectorParameter parameter;
    List<MoodleCoreEnrolGetUsers> userInfo = [];
    try {
      String id = await getCourseUrl(courseId);

      parameter = ConnectorParameter(_userUrl);
      Map<String, String> data = {
        "id": id,
      };
      parameter.data = data;
      result = await Connector.getDataByGet(parameter);

      tagNode = parse(result);
      node = tagNode.getElementById("showall")!;
      nodes = node.getElementsByTagName("a");
      String listAllUrl = nodes[0].attributes["href"]!;

      parameter = ConnectorParameter(listAllUrl);
      result = await Connector.getDataByGet(parameter);
      tagNode = parse(result);
      node = tagNode.getElementById("participants")!;
      nodes = node.getElementsByTagName("tr");
      for (var i in nodes.getRange(1, nodes.length)) {
        if (i.attributes["class"] != "emptyrow") {
          String text = i.getElementsByTagName("td")[1].text;
          List<String> c = text.split("@");
          String studentId = c.first.replaceAll(" ", "");
          if (studentId.contains("老師")) {
            continue;
          }
          var u = MoodleCoreEnrolGetUsers(fullName: text);
          userInfo.add(u);
        } else {
          break;
        }
      }
      return userInfo;
    } catch (e, stack) {
      Log.eWithStack(e, stack);
      return null;
    }
  }
}
