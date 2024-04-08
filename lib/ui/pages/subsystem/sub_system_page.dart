import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/ntust/ap_tree_json.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/task/ntust/ntust_sub_system_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/ui/components/page/error_page.dart';
import 'package:flutter_app/ui/pages/password/webmail_password_dialog.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

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
    task.result.apList.insert(
        0,
        APListJson(
            name: R.current.webMail,
            type: 'webMail_link',
            url: "https://mail.ntust.edu.tw"));
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
                  : Icons.mail_outline),
            ),
            Expanded(
              flex: 8,
              child: Text(ap.name),
            ),
            if (ap.type == "webMail_link")
              IconButton(
                  onPressed: () {
                    Get.dialog(const WebMailPasswordDialog(),
                        barrierDismissible: false);
                  },
                  icon: const Icon(EvaIcons.syncOutline))
          ],
        ),
      ),
      onTap: () async {
        if (ap.type == 'link') {
          RouteUtils.toWebViewPage(ap.name, ap.url,
              openWithExternalWebView: false);
        }
        if (ap.type == 'webMail_link') {
          if (Model.instance.getWebMailPassword().isEmpty) {
            await Get.dialog(const WebMailPasswordDialog(),
                barrierDismissible: false);
          }

          if (Model.instance.getWebMailPassword().isNotEmpty) {
            RouteUtils.toWebViewPage(
              ap.name,
              ap.url,
              openWithExternalWebView: false,
              loadDone: (webView) async {
                Uri? uri = await webView.getUrl();
                if (uri!.host == "login.ntust.edu.tw") {
                  await webView.evaluateJavascript(
                      source:
                          'document.getElementById("loginForm").kendoBindingTarget.target.obsCtrl.obsData.username = "${Model.instance.getAccount()}"');
                  await webView.evaluateJavascript(
                      source:
                          'document.getElementById("loginForm").kendoBindingTarget.target.obsCtrl.obsData.password = "${Model.instance.getWebMailPassword()}"');
                  await webView.evaluateJavascript(
                      source:
                          'document.getElementsByName("username")[0].value = "${Model.instance.getAccount()}"');
                  await webView.evaluateJavascript(
                      source:
                          'document.getElementsByName("password")[0].value = "${Model.instance.getWebMailPassword()}"');
                }
              },
            );
          }
        }
      },
    );
  }
}
