//
//  file_download.dart
//  北科課程助手
//  下載檔案，透過 DioConnector.download 並以通知列顯示進度
//
//  住在 lib/ui/service/ 而不是 lib/src/file/：它吃 BuildContext、彈 toast、
//  發通知、記 analytics，是 UI 層編排；放進 lib/src/file/（deps.py 算成 util）
//  時 import DioConnector 會成為 util -> connector 的上行邊。
//  Created by morris13579 on 2020/02/12.
//  Copyright © 2020 morris13579 All rights reserved.
//

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/service/notifications.dart';
import 'package:flutter_app/src/util/analytics_utils.dart';
import 'package:flutter_app/src/util/file_utils.dart';
import 'package:flutter_app/src/util/my_toast.dart';

import 'package:flutter_app/src/file/file_store.dart';

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

  /// 檔案在就開起來回 true，不在回 false。
  /// [FileUtils.openFile] 對不存在的路徑是 throw，不是回傳失敗。
  static Future<bool> _openIfExists(String path) async {
    try {
      Log.d("try open $path");
      await FileUtils.openFile(path);
      return true;
    } catch (e) {
      Log.d(e);
      return false;
    }
  }

  /// 下載並開啟。**已經下載過的就直接開，不會再抓一次。**
  ///
  /// `withOpen` 參數以前宣告了但整份程式沒有任何地方讀它，也沒有呼叫端傳過，
  /// 看起來卻像在控制「要不要開檔」——移掉，免得再誤導下一個讀這段的人。
  static Future<void> download(BuildContext context, String url, dirName,
      {String name = "", String? referer}) async {
    String path;
    try {
      path = await FileStore.getDownloadDir(context, dirName); //取得下載路徑
    } catch (e) {
      // 建立下載目錄可能失敗（自選路徑被刪、外部儲存被拔掉、不可寫）。呼叫端
      // 都是 fire-and-forget 不接這個 Future，不在這裡攔就會變成沒人處理的
      // 非同步錯誤，使用者只看到「什麼都沒發生」。
      Log.d(e);
      MyToast.show(R.current.downloadError);
      return;
    }
    if (path.isEmpty) {
      // 沒有儲存權限，FileStore 已經跳過 noPermission 提示。再走下去
      // savePath 會變成根目錄的 '/檔名'，寫入必定失敗。
      return;
    }
    referer = referer ?? url;
    String savePath = "$path/$name";
    String realFileName = "";
    // 先用呼叫端給的檔名試一次：命中就連 HEAD 都不必送，離線也開得起來。
    // 下面那次 HEAD 只是為了拿 content-disposition 裡的真實檔名。
    if (name.isNotEmpty && await _openIfExists(savePath)) return;
    try {
      var downloadReq = await DioConnector.instance.dio.head(url);
      Map<String, List<String>> headers = downloadReq.headers.map;
      realFileName = getFileNameByHeader(headers) ?? name;
      savePath = "$path/$realFileName";
    } catch (e) {
      Log.d(e);
    }
    // 命中快取就結束。**先前這裡開完沒有 return**，開起來也照樣往下重新下載
    // 一次，等於整個快取完全沒有作用——使用者每點一次檔案就重抓一次。
    if (await _openIfExists(savePath)) return;
    if (await Connectivity().checkConnectivity() == ConnectivityResult.none) {
      MyToast.show(R.current.pleaseConnectToNetwork);
      return;
    }
    await AnalyticsUtils.logDownloadFileEvent();
    MyToast.show(R.current.downloadWillStart);
    // 只印 host 與檔名：完整 url 的 query string 帶著長效的 Moodle wsToken。
    Log.d("file download: ${Uri.tryParse(url)?.host ?? "?"} / $name");
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
        unawaited(Notifications.instance.showProgressNotification(
            value, 100, (count * 100 / total).round())); //顯示下載進度
      } else {
        unawaited(Notifications.instance
            .showIndeterminateProgressNotification(value)); //顯示下載進度
      }
    };
    // 這裡必須 await：不等的話 download() 的 Future 在下載才剛開始時就完成，
    // 呼叫端拿到的 Future 就不代表「下載結束、完成/失敗通知也發完了」。
    await DioConnector.instance.download(url, (Headers responseHeaders) {
      value.title = realFileName;
      Log.d(savePath);
      return savePath;
    },
        progressCallback: onReceiveProgress,
        cancelToken: cancelToken,
        header: {"referer": referer}).then(
      (_) async {
        // 用 then 而不是 whenComplete：whenComplete 是 finally 語意，失敗時也會
        // 執行，使用者會先收到一則 Importance.max 的假「下載完成」通知；而
        // whenComplete 內自己拋的例外（通知權限被關）會取代成功結果流進
        // catchError，讓成功的下載顯示成失敗。
        await Notifications.instance.cancelNotification(value.id);
        value.body = R.current.downloadComplete;
        value.id = Notifications.instance.notificationId; //取得新的id
        // 用實際的 savePath，不要重組 '$path/$realFileName'：realFileName 只在
        // HEAD 探測成功時才有值，失敗時是空字串，payload 會指向目錄，點下去只
        // 得到 File not found。
        value.payload = json.encode({
          "type": "download_complete",
          "path": savePath,
          "id": value.id,
        });
        await Notifications.instance.showNotification(value); //顯示下載完成
      },
    ).catchError(
      (onError) async {
        Log.d(onError.toString());
        await Notifications.instance.cancelNotification(value.id);
        value.body = R.current.downloadError;
        value.id = Notifications.instance.notificationId; //取得新的id
        value.payload = json.encode({
          "type": "download_fail",
          "id": value.id,
        });
        await Notifications.instance.showNotification(value); //顯示下載失敗
      },
    );
  }
}
