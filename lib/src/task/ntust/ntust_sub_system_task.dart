import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/ntust_connector.dart';
import 'package:flutter_app/src/model/ntust/ap_tree_json.dart';
import 'package:flutter_app/src/task/ntust/ntust_task.dart';

import '../task.dart';

class NTUSTSubSystemTask extends NTUSTTask<APTreeJson> {
  NTUSTSubSystemTask() : super("NTUSTSubSystemTask");

  @override
  Future<TaskStatus> execute() async {
    TaskStatus status = await super.execute();
    if (status == TaskStatus.Success) {
      var value = await NTUSTConnector.getSubSystem();
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
