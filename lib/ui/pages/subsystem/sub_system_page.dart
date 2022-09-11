import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/ntust/ap_tree_json.dart';
import 'package:flutter_app/src/task/ntust/ntust_sub_system_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/ui/pages/error/error_page.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

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
      body: FutureBuilder<APTreeJson?>(
        future: initTask(),
        builder: (BuildContext context, AsyncSnapshot<APTreeJson?> snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.data == null) {
              return const ErrorPage();
            } else {
              return getAnimationList(snapshot.data!);
            }
          } else {
            return const Text("");
          }
        },
      ),
    );
  }

  Widget getAnimationList(APTreeJson apTree) {
    return AnimationLimiter(
      child: ListView.builder(
        itemCount: apTree.apList.length,
        itemBuilder: (BuildContext context, int index) {
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque, //讓透明部分有反應
                  child: Container(
                    child: buildTree(apTree.apList[index]),
                  ),
                  onTap: () {},
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildTree(APListJson ap) {
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
  }
}
