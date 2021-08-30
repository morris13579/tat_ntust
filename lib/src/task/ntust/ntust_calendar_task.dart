import 'dart:io';

import 'package:flutter_app/debug/log/Log.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/connector/ntust_connector.dart';
import 'package:flutter_app/src/task/dialog_task.dart';
import 'package:path_provider/path_provider.dart';

import '../task.dart';

class NTUSTCalendarTask extends DialogTask<String> {
  NTUSTCalendarTask() : super("NTUSTCalendarTask");

  @override
  Future<TaskStatus> execute() async {
    var directory = await getApplicationSupportDirectory();
    String savePath = "${directory.path}/calendar.ics";
    Log.d(savePath);
    result = savePath;
    int day = 0;
    bool exists = await File(savePath).exists();
    if (exists) {
      day =
          DateTime.now().difference(await File(savePath).lastModified()).inDays;
    }
    if (!exists || day >= 1) {
      super.onStart(R.current.downloading);
      try {
        String url = await NTUSTConnector.getCalendarUrl();
        await DioConnector.instance
            .download(url, (responseHeaders) => savePath);
      } catch (e) {
        super.onEnd();
        return await super.onError(R.current.downloadError);
      }
      super.onEnd();
    }
    return TaskStatus.Success;
  }
}
