import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/ntut_connector.dart';
import 'package:flutter_app/src/model/ntut/ap_tree_json.dart';
import 'package:flutter_app/src/task/ntut/ntut_task.dart';

import '../task.dart';

class NTUTSubSystemTask extends NTUTTask<APTreeJson> {
  final String arg;

  NTUTSubSystemTask(this.arg) : super("NTUTSubSystemTask");

  @override
  Future<TaskStatus> execute() async {
    TaskStatus status = await super.execute();
    if (status == TaskStatus.Success) {
      var value = await NTUTConnector.getSubSystem();
      print(value);
      if (value != null) {
        result = value;
        return TaskStatus.Success;
      } else {
        return await super.onError(R.current.error);
      }
    }
    return status;
  }
}
