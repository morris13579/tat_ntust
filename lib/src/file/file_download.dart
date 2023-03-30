//
//  file_download.dart
//  北科課程助手
//  下載檔案用使用flutter_downloader
//  Created by morris13579 on 2020/02/12.
//  Copyright © 2020 morris13579 All rights reserved.
//

import 'dart:convert';
import 'dart:typed_data';

import 'package:connectivity/connectivity.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/generated/l10n.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/notifications/notifications.dart';
import 'package:flutter_app/src/util/analytics_utils.dart';
import 'package:flutter_app/src/util/file_utils.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:open_filex/open_filex.dart';

import 'file_store.dart';

class FileDownload {
  static String? getFileNameByHeader(Map<String, List<String>> headers) {
    String? name;
    if (headers.containsKey("content-disposition")) {
      //代表有名字
      List<String> names = headers["content-disposition"]!;
      String decodeName = utf8.decode(Uint8List.fromList(names[0].codeUnits));
      RegExp exp = RegExp("['|\"](?<name>.+)['|\"]"); //尋找 'name' , "name" 的name
      RegExpMatch matches = exp.firstMatch(decodeName)!;
      name = matches.group(1)!;
    }
    return name;
  }

  static Future<void> download(BuildContext context, String url, dirName,
      {String name = "", String? referer, withOpen = true}) async {
    String path = await FileStore.getDownloadDir(context, dirName); //取得下載路徑
    referer = referer ?? url;
    String savePath = "$path/$name";
    String realFileName = "";
    //顯示下載通知窗
    try {
      var downloadReq = await DioConnector.instance.dio.head(url);
      Map<String, List<String>> headers = downloadReq.headers.map;
      realFileName = getFileNameByHeader(headers) ?? name;
      savePath = "$path/$realFileName";
    } catch (e) {
      Log.d(e);
    }
    try {
      Log.d("try open $savePath");
      OpenResult result = await OpenFilex.open(savePath);
      if (result.type == ResultType.done) {
        return;
      } else if (result.type == ResultType.noAppToOpen) {
        MyToast.show(S.current.noAppToOpen);
        return;
      }
    } catch (e) {
      Log.d(e);
    }
    if (await Connectivity().checkConnectivity() == ConnectivityResult.none) {
      MyToast.show(R.current.pleaseConnectToNetwork);
      return;
    }
    await AnalyticsUtils.logDownloadFileEvent();
    MyToast.show(R.current.downloadWillStart);
    Log.d("file download \n url: $url \n referer: $referer");
    ReceivedNotification value = ReceivedNotification(
        title: name, body: R.current.prepareDownload, payload: null); //通知窗訊息
    CancelToken? cancelToken; //取消下載用
    ProgressCallback onReceiveProgress; //下載進度回調
    await Notifications.instance.showIndeterminateProgressNotification(value);
    //顯示下載進度通知窗
    value.title = name;

    int nowSize = 0;
    onReceiveProgress = (int count, int total) async {
      value.body = FileUtils.formatBytes(count, 2);
      if ((nowSize + 1024 * 128) > count && nowSize != 0) {
        //128KB顯示一次
        return;
      }
      nowSize = count;
      if (count < total) {
        Notifications.instance.showProgressNotification(
            value, 100, (count * 100 / total).round()); //顯示下載進度
      } else {
        Notifications.instance
            .showIndeterminateProgressNotification(value); //顯示下載進度
      }
    };
    DioConnector.instance.download(url, (Headers responseHeaders) {
      value.title = realFileName;
      Log.d(savePath);
      return savePath;
    },
        progressCallback: onReceiveProgress,
        cancelToken: cancelToken,
        header: {"referer": referer}).whenComplete(
      () async {
        //顯示下載萬完成通知窗
        await Notifications.instance.cancelNotification(value.id);
        value.body = R.current.downloadComplete;
        value.id = Notifications.instance.notificationId; //取得新的id
        String filePath = '$path/$realFileName';
        int id = value.id;
        value.payload = json.encode({
          "type": "download_complete",
          "path": filePath,
          "id": id,
        });
        await Notifications.instance.showNotification(value); //顯示下載完成
      },
    ).catchError(
      (onError) async {
        //顯示下載萬完成通知窗
        Log.d(onError.toString());
        await Future.delayed(const Duration(milliseconds: 100));
        Notifications.instance.cancelNotification(value.id);
        value.body = "下載失敗";
        value.id = Notifications.instance.notificationId; //取得新的id
        int id = value.id;
        value.payload = json.encode({
          "type": "download_fail",
          "id": id,
        });
        await Notifications.instance.showNotification(value); //顯示下載完成
      },
    );
  }
}
