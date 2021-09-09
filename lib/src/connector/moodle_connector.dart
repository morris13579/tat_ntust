import 'dart:convert';

import 'package:flutter_app/debug/log/Log.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/model/moodle/moodle_branch.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';

enum MoodleConnectorStatus { LoginSuccess, LoginFail, UnknownError }

class MoodleUserInfo {
  String studentId;
  String name;

  MoodleUserInfo({this.studentId, this.name});
}

class MoodleCourseDirectoryInfo {
  String elementid;
  String id;
  String type;
  String sesskey;
  String instance;
  String name;

  MoodleCourseDirectoryInfo(
      {this.elementid,
      this.id,
      this.type,
      this.sesskey,
      this.instance,
      this.name});
}

class MoodleAnnouncementInfo {
  String name;
  String url;
  String author;
  String replies;
  String time;

  MoodleAnnouncementInfo(
      {this.name, this.author, this.replies, this.time, this.url});
}

class MoodleFileInfo {
  String name;
  String url;

  MoodleFileInfo({this.name, this.url});
}

class MoodleConnector {
  static final String host = "https://moodle.ntust.edu.tw";
  static final String _loginUrl = "$host/login/index.php";
  static final String _userUrl = "$host/user/index.php";
  static final String _viewUrl = "$host/course/view.php";
  static final String _branchUrl = "$host/lib/ajax/getnavbranch.php";

  static Future<MoodleConnectorStatus> login(
      String account, String password) async {
    String result;
    Document tagNode;
    List<Element> nodes;
    ConnectorParameter parameter;
    try {
      String logintoken;

      parameter = ConnectorParameter(_loginUrl);
      result = await Connector.getRedirects(parameter);
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

  static Future<List<MoodleCourseDirectoryInfo>> getCourseDirectory(
      String courseId) async {
    String result;
    Document tagNode;
    List<Element> nodes;
    ConnectorParameter parameter;
    List<MoodleCourseDirectoryInfo> value = [];
    try {
      String id = await getCourseUrl(courseId);
      parameter = ConnectorParameter(_viewUrl);
      Map<String, String> data = {
        "id": id,
        "lang": (LanguageUtils.getLangIndex() == LangEnum.zh) ? "zh_tw" : "en"
      };
      parameter.data = data;
      result = await Connector.getDataByGet(parameter);

      tagNode = parse(result);
      nodes = tagNode.getElementsByClassName(
          "type_course depth_3 contains_branch current_branch");
      nodes = nodes[0].getElementsByTagName("ul");
      nodes = nodes[0]
          .getElementsByClassName("type_structure depth_4 contains_branch");
      for (var i in nodes) {
        Element p = i.getElementsByTagName("p")[0];
        MoodleCourseDirectoryInfo info = MoodleCourseDirectoryInfo(
          name: i.text,
          elementid: p.attributes["data-node-id"],
          id: p.attributes["data-node-key"],
          type: p.attributes["data-node-type"],
          sesskey: "avG0zcjfKy",
          instance: "4",
        );
        value.add(info);
      }
      return value;
    } catch (e, stack) {
      Log.eWithStack(e, stack);
      return null;
    }
  }

  static Future<List<MoodleAnnouncementInfo>> getCourseAnnouncement(
      String url) async {
    String result;
    Document tagNode;
    List<Element> nodes;
    Element node;
    ConnectorParameter parameter;
    List<MoodleAnnouncementInfo> value = [];
    try {
      parameter = ConnectorParameter(url);
      result = await Connector.getDataByGet(parameter);
      tagNode = parse(result);
      nodes = tagNode.getElementsByClassName("forumheaderlist");
      if (nodes.length == 0) {
        return [];
      }
      node = nodes.first.getElementsByTagName("tbody").first;
      for (var i in node.getElementsByTagName("tr")) {
        nodes = i.getElementsByTagName("td");
        value.add(MoodleAnnouncementInfo(
          name: nodes[0].text,
          replies: nodes[3].text,
          author: nodes[2].text,
          url: nodes[0].getElementsByTagName("a").first.attributes["href"],
          time: nodes[4].getElementsByTagName("a")[1].text,
        ));
      }
      return value;
    } catch (e, stack) {
      Log.eWithStack(e, stack);
      return null;
    }
  }

  static Future<String> getCourseAnnouncementDetail(String url) async {
    String result;
    Document tagNode;
    List<Element> nodes;
    Element node;
    ConnectorParameter parameter;
    List<MoodleAnnouncementInfo> value = [];
    try {
      parameter = ConnectorParameter(url);
      result = await Connector.getDataByGet(parameter);
      tagNode = parse(result);
      nodes = tagNode.getElementsByClassName(
          "forumpost clearfix lastpost firstpost starter");
      return nodes.first.innerHtml;
    } catch (e, stack) {
      Log.eWithStack(e, stack);
      return null;
    }
  }

  static Future<MoodleBranchJson> getCourseBranch(
      MoodleCourseDirectoryInfo info) async {
    String result;
    ConnectorParameter parameter;
    try {
      parameter = ConnectorParameter(_branchUrl);
      Map<String, String> data = {
        "elementid": info.elementid,
        "id": info.id,
        "type": info.type,
        "sesskey": info.sesskey,
        "instance": info.instance,
      };
      parameter.data = data;
      result = await Connector.getDataByPost(parameter);
      MoodleBranchJson branch = MoodleBranchJson.fromJson(json.decode(result));
      List<Children> c = [];
      branch.children ??= [];
      for (var i in branch.children) {
        if (i != null) {
          c.add(i);
        }
      }
      branch.children = c;
      return branch;
    } catch (e, stack) {
      Log.eWithStack(e, stack);
      return null;
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

  static Future<List<MoodleFileInfo>> getFolder(String url) async {
    String result;
    Document tagNode;
    Element node;
    List<Element> nodes;
    ConnectorParameter parameter;
    List<MoodleFileInfo> fs = [];
    try {
      parameter = ConnectorParameter(url);
      result = await Connector.getDataByGet(parameter);
      tagNode = parse(result);
      nodes = tagNode.getElementsByClassName("box generalbox foldertree");
      nodes = nodes[0].getElementsByTagName("li");
      for (var i in nodes.getRange(1, nodes.length)) {
        MoodleFileInfo f = MoodleFileInfo(
          url: i.getElementsByTagName("a")[0].attributes["href"],
          name: i.text,
        );
        fs.add(f);
      }
      if (fs.length != 0) {
        try {
          node = tagNode.getElementsByClassName("singlebutton")[0];

          node = node.getElementsByTagName("form")[0];
          String url = node.attributes["action"];
          nodes = node.getElementsByTagName("input");
          Map<String, dynamic> data = {};
          for (var i in nodes) {
            if (i.attributes["type"] == "hidden") {
              data[i.attributes["name"]] = i.attributes["value"];
            }
          }
          MoodleFileInfo f = MoodleFileInfo(
            url: Uri.https(Uri.parse(url).host, Uri.parse(url).path, data)
                .toString(),
            name: R.current.downloadAll,
          );
          fs.add(f);
        } catch (e, stack) {
          Log.eWithStack(e, stack);
        }
      }
      return fs;
    } catch (e, stack) {
      Log.eWithStack(e, stack);
      return null;
    }
  }
}
