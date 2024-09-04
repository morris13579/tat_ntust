import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/ntust_connector.dart';
import 'package:flutter_app/src/model/ntust/ap_tree_json.dart';
import 'package:flutter_app/src/task/ntust/ntust_task.dart';
import 'package:flutter_app/src/task/task.dart';

class NTUSTSubSystemTask extends NTUSTTask<List<APTreeJson>> {
  NTUSTSubSystemTask() : super("NTUSTSubSystemTask");

  @override
  Future<TaskStatus> execute() async {
    TaskStatus status = await super.execute();
    if (status == TaskStatus.success) {
      var value = await NTUSTConnector.getSubSystem();
      result = value;
      return TaskStatus.success;
    }
    return status;
  }
}
