import 'package:flutter/material.dart';
import 'package:flutter_app/src/model/ntust/ap_tree_json.dart';
import 'package:flutter_app/src/task/ntust/ntust_sub_system_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/src/util/route_utils.dart';

class SubSystemPage extends StatefulWidget {
  final String title;
  final String? arg;

  const SubSystemPage({
    required this.title,
    required this.arg,
    Key? key,
  }) : super(key: key);

  @override
  _SubSystemPageState createState() => _SubSystemPageState();
}

class _SubSystemPageState extends State<SubSystemPage> {
  bool isLoading = true;
  APTreeJson? apTree;

  @override
  void initState() {
    super.initState();
    loadTree();
  }

  void loadTree() async {
    setState(() {
      isLoading = true;
    });
    TaskFlow taskFlow = TaskFlow();
    var task = NTUSTSubSystemTask();
    taskFlow.addTask(task);
    if (await taskFlow.start()) {
      apTree = task.result;
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : buildTree(),
    );
  }

  Widget buildTree() {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: apTree!.apList.length,
      itemBuilder: (BuildContext context, int index) {
        APListJson ap = apTree!.apList[index];
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
