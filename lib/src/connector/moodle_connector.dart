import 'package:flutter_app/debug/log/Log.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_enrol_get_users.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions_paginated.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';

enum MoodleConnectorStatus { LoginSuccess, LoginFail, UnknownError }

class MoodleScoreItem {
  String name;
  String weight; //計算後權量
  String score; //成績
  String fullRange; //全距
  String percentage; //百分比
  String feedback; //回饋
  String contribute; //貢獻到課程總分
  MoodleScoreItem({
    required this.name,
    required this.weight,
    required this.score,
    required this.fullRange,
    required this.percentage,
    required this.feedback,
    required this.contribute,
  });
}

class MoodleConnector {
  static const String host = "https://moodle2.ntust.edu.tw";
  static const String _loginUrl = "$host/login/index.php";
  static const String _userUrl = "$host/user/index.php";
  static const String _viewUrl = "$host/course/view.php";
  static const String _announcementView = "$host/mod/forum/view.php";
  static const String _scoreUrl = "$host/grade/report/user/index.php";

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
        return MoodleConnectorStatus.LoginSuccess;
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
          ? MoodleConnectorStatus.LoginSuccess
          : MoodleConnectorStatus.LoginFail;
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return MoodleConnectorStatus.LoginFail;
    }
  }

  static Future<String?> getCourseUrl(String courseId) async {
    String result;
    Document tagNode;
    Element node;
    List<Element>? nodes;
    ConnectorParameter parameter;
    try {
      String? courseUrl;
      parameter = ConnectorParameter(host);
      result = await Connector.getDataByGet(parameter);
      tagNode = parse(result);

      node = tagNode.getElementById("nav-drawer")!;
      for (var i in node.getElementsByTagName("li")) {
        if (i.attributes["data-key"] == "mycourses") {
          nodes = i.getElementsByTagName("ul");
          break;
        }
      }
      nodes = nodes![0].getElementsByTagName("a");
      for (var i in nodes) {
        String courseTitle = i.text;
        if (courseTitle.contains(courseId)) {
          courseUrl = i.attributes["href"];
        }
      }
      String id = Uri.parse(courseUrl!).queryParameters["id"]!;
      return id;
    } catch (e) {
      return null;
    }
  }

  static Future<List<MoodleCoreCourseGetContents>?> getCourseDirectory(
      String id) async {
    String result;
    Document tagNode;
    List<Element> nodes;
    ConnectorParameter parameter;
    List<MoodleCoreCourseGetContents> value = [];
    try {
      parameter = ConnectorParameter(_viewUrl);
      Map<String, String> data = {
        "id": id,
        "lang": (LanguageUtils.getLangIndex() == LangEnum.zh) ? "zh_tw" : "en"
      };
      parameter.data = data;
      result = await Connector.getDataByGet(parameter);

      tagNode = parse(result);
      nodes = tagNode
          .getElementsByClassName("course-content")[0]
          .getElementsByClassName("weeks");
      nodes = nodes[0].children;
      for (int i = 0; i < nodes.length; i++) {
        try {
          var node = nodes[i];
          print(node.id);
          var title =
              node.getElementsByTagName("span")[0].getElementsByTagName("a")[0];
          MoodleCoreCourseGetContents info = MoodleCoreCourseGetContents(
            id: int.parse(id),
            name: title.text,
          );
          List<Element> items = node.getElementsByClassName("activity");
          for (var item in items) {
            try {
              var module = Modules();
              String type = item.className;

              module.url =
                  item.getElementsByTagName("a")[0].attributes['href']!;
              var k = item.getElementsByClassName("instancename")[0];
              module.name = k.text;
              //do something
              try {
                var hide = k.getElementsByClassName("accesshide")[0].text;
                var index = module.name.indexOf(hide);
                module.name = module.name.substring(0, index);
              } catch (e) {}

              if (type.contains("modtype_forum")) {
                module.modname = "forum";
              } else if (type.contains("modtype_resource")) {
                module.modname = "resource";
                var content = Contents(fileurl: module.url);
                module.contents.add(content);
              } else if (type.contains("modtype_assign")) {
                module.modname = "assign";
              } else if (type.contains("modtype_folder")) {
                module.modname = "folder";
              } else if (type.contains("modtype_label")) {
                module.modname = "label";
                module.description = item
                    .getElementsByClassName("contentwithoutlink")[0]
                    .innerHtml;
              } else if (type.contains("modtype_url")) {
                module.modname = "url";
                module.url =
                    item.getElementsByTagName("a")[0].attributes['href']!;
                var k = item.getElementsByClassName("instancename")[0];
                module.name = k.text;
                //do something
                try {
                  var hide = k.getElementsByClassName("accesshide")[0].text;
                  var index = module.name.indexOf(hide);
                  module.name = module.name.substring(0, index);
                } catch (e) {}
              } else {
                //??
                module.modname = "forum";
                module.url =
                    item.getElementsByTagName("a")[0].attributes['href']!;
                module.name =
                    item.getElementsByClassName("instancename")[0].text;
              }
              try {
                module.description =
                    item.getElementsByTagName("contentafterlink")[0].innerHtml;
              } catch (e) {}
              info.modules.add(module);
            } catch (e, stack) {
              Log.eWithStack(e, stack);
            }
          }
          print(items);
          value.add(info);
        } catch (e) {
          print(e);
        }
      }
      return value;
    } catch (e, stack) {
      Log.eWithStack(e, stack);
      return null;
    }
  }

  static Future<MoodleModForumGetForumDiscussionsPaginated?>
      getCourseAnnouncement(String id) async {
    String result;
    Document tagNode;
    List<Element> nodes;
    Element node;
    ConnectorParameter parameter;
    MoodleModForumGetForumDiscussionsPaginated announcement =
        MoodleModForumGetForumDiscussionsPaginated();
    try {
      parameter = ConnectorParameter(_viewUrl);
      Map<String, String> data = {
        "id": id,
        "lang": (LanguageUtils.getLangIndex() == LangEnum.zh) ? "zh_tw" : "en"
      };
      parameter.data = data;
      result = await Connector.getDataByGet(parameter);
      tagNode = parse(result);
      nodes = tagNode.getElementsByClassName("activityinstance");
      String url = nodes[0].getElementsByTagName("a")[0].attributes['href']!;
      parameter = ConnectorParameter(url);
      result = await Connector.getDataByGet(parameter);
      tagNode = parse(result);
      nodes = tagNode.getElementsByTagName("table");
      var discussions = nodes[0].getElementsByClassName("discussion");
      for (var i in discussions) {
        try {
          var discussion = Discussions();
          discussion.name = i.children[1]
              .getElementsByTagName("a")[0]
              .attributes["aria-label"]!;
          discussion.userpictureurl =
              i.children[1].getElementsByTagName("a")[0].attributes["href"]!;
          discussion.userfullname = i.children[2]
              .getElementsByClassName("author-info")[0]
              .children[0]
              .text;
          discussion.modified = int.parse(i.children[2]
              .getElementsByClassName("author-info")[0]
              .getElementsByTagName("time")[0]
              .attributes["data-timestamp"]!);
          discussion.isNone = true;
          announcement.discussions.add(discussion);
        } catch (e, stack) {
          Log.eWithStack(e, stack);
        }
      }
      return announcement;
    } catch (e, stack) {
      Log.eWithStack(e, stack);
      return null;
    }
  }

  static Future<String?> getCourseAnnouncementDetail(String url) async {
    String result;
    Document tagNode;
    List<Element> nodes;
    ConnectorParameter parameter;
    try {
      parameter = ConnectorParameter(url);
      result = await Connector.getDataByGet(parameter);
      tagNode = parse(result);
      nodes = tagNode.getElementsByClassName("post-content-container");
      //nodes = tagNode.getElementsByClassName("body-content-container");
      return nodes.first.innerHtml;
    } catch (e, stack) {
      Log.eWithStack(e, stack);
      return null;
    }
  }

  static Future<List<MoodleCoreEnrolGetUsers>?> getMember(String id) async {
    String result;
    Document tagNode;
    Element node;
    List<Element> nodes;
    ConnectorParameter parameter;
    List<MoodleCoreEnrolGetUsers> userInfo = [];
    try {
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
          String text = i.getElementsByTagName("a")[0].text;
          List<String> c = text.split("@");
          String studentId = c.first.replaceAll(" ", "");
          //String name = c.last.replaceAll(" ", "");
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

  static Future<List<MoodleScoreItem>?> getScore(String id) async {
    String result;
    Document tagNode;
    List<Element> nodes;
    ConnectorParameter parameter;
    try {
      parameter = ConnectorParameter(_scoreUrl);
      parameter.data = {"id": id};
      result = await Connector.getDataByGet(parameter);
      tagNode = parse(result);
      nodes = tagNode
          .getElementsByTagName("table")
          .first
          .getElementsByTagName("tbody")
          .first
          .getElementsByTagName("tr");
      nodes = nodes.getRange(1, nodes.length).toList();
      List<MoodleScoreItem> value = [];
      for (var node in nodes) {
        List<Element> th, td;
        try {
          th = node.getElementsByTagName('th').first.children;
          td = node.getElementsByTagName('td');
        } catch (e) {
          continue;
        }
        value.add(MoodleScoreItem(
          name: th.first.text,
          weight: td[0].text,
          score: td[1].text,
          fullRange: td[2].text,
          percentage: td[3].text,
          feedback: td[4].text,
          contribute: td[5].text,
        ));
      }
      return value;
    } catch (e, stack) {
      Log.eWithStack(e, stack);
      return null;
    }
  }
}
