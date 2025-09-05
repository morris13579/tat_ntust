import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/ntust/ap_tree_json.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/task/ntust/ntust_sub_system_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/page/error_page.dart';
import 'package:flutter_app/ui/pages/password/webmail_password_dialog.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

class SubSystemPage extends StatefulWidget {
  const SubSystemPage({
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _SubSystemPageState();
}

class _SubSystemPageState extends State<SubSystemPage> {
  Future<List<APTreeJson>> initTask() async {
    TaskFlow taskFlow = TaskFlow();
    var task = NTUSTSubSystemTask();
    taskFlow.addTask(task);
    await taskFlow.start();
    return task.result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: mainAppbar(title: R.current.informationSystem),
      body: FutureBuilder<List<APTreeJson>>(
        future: initTask(),
        builder:
            (BuildContext context, AsyncSnapshot<List<APTreeJson>> snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.data == null) {
              return const ErrorPage();
            }
            return Column(
              children: [
                buildMail(APListJson(
                    name: R.current.webMail,
                    type: 'webMail_link',
                    url: "https://mail.ntust.edu.tw")),
                Expanded(child: getAnimationList(snapshot.data!)),
              ],
            );
          } else {
            return const Text("");
          }
        },
      ),
    );
  }

  Widget getAnimationList(List<APTreeJson> apTree) {
    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        physics: const BouncingScrollPhysics(),
        itemCount: apTree.length,
        itemBuilder: (BuildContext context, int index) {
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque, //讓透明部分有反應
                  child: buildTree(apTree[index]),
                  onTap: () {},
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildTree(APTreeJson ap) {
    var serviceMap = {
      "service-1": R.current.curriculum,
      "service-2": R.current.person_info,
      "service-3": R.current.campus_life,
      "service-4": R.current.financial_support,
      "service-5": R.current.activities,
      "service-6": R.current.resources
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          serviceMap[ap.serviceId] ?? "",
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Get.theme.colorScheme.onSurface),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: (Get.width - 12 * 2) / 100,
              crossAxisSpacing: 8,
              mainAxisSpacing: 12),
          itemBuilder: (context, index) {
            return buildItem(ap.apList[index]);
          },
          itemCount: ap.apList.length,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget buildItem(APListJson ap) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: Get.theme.colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6),),
        minimumSize: const Size(0, 120)
      ),
      onPressed: () {
        RouteUtils.toWebViewPage(ap.name, ap.url, openWithExternalWebView: false);
      },
      child: Text(
        ap.name,
        textAlign: TextAlign.center,
        style: TextStyle(color: Get.theme.colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget buildMail(APListJson ap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: GestureDetector(
        onTap: () async {
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
        },
        child: SizedBox(
          height: 50,
          child: Row(
            children: [
              Text(ap.name),
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
      ),
    );
  }
}
