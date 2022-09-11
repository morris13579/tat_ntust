import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/ntust/ap_tree_json.dart';
import 'package:flutter_app/src/task/ntust/ntust_sub_system_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/ui/pages/error/error_page.dart';

class SubSystemPage extends StatefulWidget {
  const SubSystemPage({
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _SubSystemPageState();
}

class _SubSystemPageState extends State<SubSystemPage> {
  Future<APTreeJson?> initTask() async {
    TaskFlow taskFlow = TaskFlow();
    var task = NTUSTSubSystemTask();
    taskFlow.addTask(task);
    await taskFlow.start();
    return task.result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(R.current.informationSystem),
      ),
      body: Container(
        padding: const EdgeInsets.only(top: 10),
        child: FutureBuilder<APTreeJson?>(
          future: initTask(),
          builder: (BuildContext context, AsyncSnapshot<APTreeJson?> snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.data == null) {
                return const ErrorPage();
              } else {
                return buildTree(snapshot.data!);
              }
            } else {
              return const Text("");
            }
          },
        ),
      ),
    );
  }

  Widget buildTree(APTreeJson apTree) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: apTree.apList.length,
      itemBuilder: (BuildContext context, int index) {
        APListJson ap = apTree.apList[index];
        return InkWell(
          child: SizedBox(
            height: 50,
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Icon((ap.type == 'link')
                      ? Icons.link_outlined
                      : Icons.folder_outlined),
                ),
                Expanded(
                  flex: 8,
                  child: Text(ap.name),
                ),
              ],
            ),
          ),
          onTap: () async {
            if (ap.type == 'link') {
              RouteUtils.toWebViewPage(ap.name, ap.url,
                  openWithExternalWebView: false);
            }
          },
        );
      },
    );
  }
}
