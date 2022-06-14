import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/connector/ntust_connector.dart';
import 'package:flutter_app/src/task/cache_task.dart';
import 'package:flutter_app/src/task/task.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

class NTUSTCalendarTask extends CacheTask<String> {
  bool forceUpdate;

  NTUSTCalendarTask({this.forceUpdate = false}) : super("NTUSTCalendarTask");

  @override
  Future<TaskStatus> execute() async {
    var directory = await getApplicationSupportDirectory();
    String savePath = "${directory.path}/calendar.ics";
    Log.d(savePath);
    result = savePath;
    bool exists = await File(savePath).exists();
    if (!exists || forceUpdate) {
      super.onStart(R.current.downloading);
      try {
        var s = await NTUSTConnector.getCalendarUrl();
        var url = await selectSemesterDialog(s!);
        await DioConnector.instance
            .download(url!, (responseHeaders) => savePath);
      } catch (e) {
        super.onEnd();
        return await super.onError(R.current.downloadError);
      }
      super.onEnd();
    }
    return TaskStatus.success;
  }

  static Future<String?> selectSemesterDialog(
      Map<String, String> selects) async {
    String? select = await Get.dialog<String?>(
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: Text(R.current.selectSemester),
            content: Column(
                mainAxisSize: MainAxisSize.min,
                children: selects.keys
                    .map(
                      (key) => InkWell(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.only(
                                  top: 10, bottom: 10, left: 5, right: 5),
                              child: Text(key),
                            )
                          ],
                        ),
                        onTap: () {
                          Get.back<String>(result: selects[key]!);
                        },
                      ),
                    )
                    .toList()),
          );
        },
      ),
      barrierDismissible: false,
    );
    return select ?? selects[selects.keys.first];
  }
}
