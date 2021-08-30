import 'package:flutter_app/debug/log/Log.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';

enum MoodleConnectorStatus { LoginSuccess, LoginFail, UnknownError }

class MoodleUserInfo {
  String studentId;
  String name;

  MoodleUserInfo({this.studentId, this.name});
}

class MoodleConnector {
  static final String host = "https://moodle.ntust.edu.tw";
  static final String _loginUrl = "$host/login/index.php";
  static final String _userUrl = "$host/user/index.php";

  static Future<MoodleConnectorStatus> login(
      String account, String password) async {
    String result;
    Document tagNode;
    List<Element> nodes;
    ConnectorParameter parameter;
    try {
      String logintoken;

      parameter = ConnectorParameter(_loginUrl);
      result = await Connector.getDataByGet(parameter);
      tagNode = parse(result);

      nodes = tagNode.getElementsByTagName("input");
      for (var i in nodes) {
        if (i.attributes["name"] != null &&
            i.attributes["name"].contains("logintoken")) {
          logintoken = i.attributes["value"];
          break;
        }
      }
      Map<String, String> data = {
        "username": account,
        "password": password,
        "anchor": "",
        "logintoken": logintoken
      };
      parameter.data = data;
      result = await Connector.getRedirects(parameter, usePost: true);

      parameter = ConnectorParameter(host);
      result = await Connector.getDataByGet(parameter);
      return (result.contains("登出"))
          ? MoodleConnectorStatus.LoginSuccess
          : MoodleConnectorStatus.LoginFail;
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return MoodleConnectorStatus.LoginFail;
    }
  }

  static Future<String> getCourseUrl(String courseId) async {
    String result;
    Document tagNode;
    Element node;
    List<Element> nodes;
    ConnectorParameter parameter;
    try {
      String courseUrl;
      parameter = ConnectorParameter(host);
      result = await Connector.getDataByGet(parameter);
      tagNode = parse(result);

      node = tagNode.getElementById("custom_menu_courses");
      nodes = node.getElementsByClassName("dropdown-menu");
      nodes = nodes[0].getElementsByTagName("a");
      for (var i in nodes) {
        String courseTitle = i.attributes["title"];
        if (courseTitle.contains(courseId)) {
          courseUrl = i.attributes["href"];
        }
      }
      return Uri.parse(courseUrl).queryParameters["id"];
    } catch (e) {
      throw e;
    }
  }

  static Future<List<MoodleUserInfo>> getMember(String courseId) async {
    String result;
    Document tagNode;
    Element node;
    List<Element> nodes;
    ConnectorParameter parameter;
    List<MoodleUserInfo> userInfo = [];
    try {
      String id = await getCourseUrl(courseId);

      parameter = ConnectorParameter(_userUrl);
      Map<String, String> data = {
        "id": id,
      };
      parameter.data = data;
      result = await Connector.getDataByGet(parameter);

      tagNode = parse(result);
      node = tagNode.getElementById("showall");
      nodes = node.getElementsByTagName("a");
      String listAllUrl = nodes[0].attributes["href"];

      parameter = ConnectorParameter(listAllUrl);
      result = await Connector.getDataByGet(parameter);
      tagNode = parse(result);
      node = tagNode.getElementById("participants");
      nodes = node.getElementsByTagName("tr");
      for (var i in nodes.getRange(1, nodes.length)) {
        if (i.attributes["class"] != "emptyrow") {
          String text = i.getElementsByTagName("td")[1].text;
          List<String> c = text.split("@");
          String studentId = c.first.replaceAll(" ", "");
          String name = c.last.replaceAll(" ", "");
          if (studentId.contains("老師")) {
            continue;
          }
          var u = MoodleUserInfo(studentId: studentId, name: name);
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
