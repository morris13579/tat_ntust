//
//  ntust_connector.dart
//  北科課程助手
//
//  Created by morris13579 on 2020/02/12.
//  Copyright © 2020 morris13579 All rights reserved.
//

import 'dart:async';

import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/model/ntut/ap_tree_json.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';

enum NTUSTLoginStatus { Success, Fail }

class NTUSTConnector {
  static const String host = "https://i.ntust.edu.tw";
  static const String ntustLoginUrl =
      "https://stuinfosys.ntust.edu.tw/NTUSTSSOServ/SSO/Login/CourseSelection";

  static const String subSystemTWUrl = "$host/student";
  static const String subSystemENUrl = "$host/EN/student";

  static Future<APTreeJson?> getSubSystem() async {
    String result;
    Document tagNode;
    Element node;
    List<Element> nodes;
    try {
      String subSystemUrl = (LanguageUtils.getLangIndex() == LangEnum.zh)
          ? subSystemTWUrl
          : subSystemENUrl;
      ConnectorParameter parameter = ConnectorParameter(subSystemUrl);
      result = await Connector.getDataByGet(parameter);
      tagNode = parse(result);
      node = tagNode.getElementById("service")!;
      nodes = node.getElementsByTagName("a");
      List<APListJson> apList = [];
      for (var i in nodes) {
        if (i.text.contains("瀏覽器尚無使用記錄") ||
            i.text.contains("No browsing history")) {
          continue;
        }
        APListJson item =
            APListJson(name: i.text, url: i.attributes["href"]!, type: "link");
        apList.add(item);
      }
      APTreeJson apTreeJson = APTreeJson(apList);
      return apTreeJson;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> getCalendarUrl() async {
    String result;
    Document tagNode;
    Element node;
    List<Element> nodes;
    try {
      String host = "https://www.academic.ntust.edu.tw";
      String url = "$host/p/404-1048-78935.php?Lang=zh-tw";
      ConnectorParameter parameter = ConnectorParameter(url);
      result = await Connector.getDataByGet(parameter);
      tagNode = parse(result);
      nodes = tagNode.getElementsByClassName("meditor");
      node = nodes[1].getElementsByTagName("ul").last;
      String href = node.getElementsByTagName("a").first.attributes["href"]!;
      return "$host$href";
    } catch (e) {
      return null;
    }
  }
}
