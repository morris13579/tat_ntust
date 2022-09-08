import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_link.dart';
import 'package:flutter_app/src/file/file_store.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/src/version/update/app_update.dart';
import 'package:flutter_app/ui/other/error_dialog.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:flutter_app/ui/pages/log_console/log_console.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

enum OnListViewPress {
  setting,
  fileViewer,
  logout,
  report,
  about,
  login,
  changePassword
}

class OtherPage extends StatefulWidget {
  final PageController pageController;

  const OtherPage(
    this.pageController, {
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _OtherPageState();
}

class _OtherPageState extends State<OtherPage> {
  List<Map> optionList = [
    {
      "icon": EvaIcons.settings2Outline,
      "color": Colors.orange,
      "title": R.current.setting,
      "onPress": OnListViewPress.setting
    },
    {
      "icon": EvaIcons.downloadOutline,
      "color": Colors.yellow[700],
      "title": R.current.fileViewer,
      "onPress": OnListViewPress.fileViewer
    },
    if (Model.instance.getPassword().isNotEmpty)
      {
        "icon": EvaIcons.syncOutline,
        "color": Colors.lightGreen,
        "title": R.current.changePassword,
        "onPress": OnListViewPress.changePassword
      },
    if (Model.instance.getPassword().isNotEmpty)
      {
        "icon": EvaIcons.undoOutline,
        "color": Colors.teal[400],
        "title": R.current.logout,
        "onPress": OnListViewPress.logout
      },
    if (Model.instance.getPassword().isEmpty)
      {
        "icon": EvaIcons.logIn,
        "color": Colors.teal[400],
        "title": R.current.login,
        "onPress": OnListViewPress.login
      },
    {
      "icon": EvaIcons.messageSquareOutline,
      "color": Colors.cyan,
      "title": R.current.feedback,
      "onPress": OnListViewPress.report
    },
    {
      "icon": EvaIcons.infoOutline,
      "color": Colors.lightBlue,
      "title": R.current.about,
      "onPress": OnListViewPress.about
    }
  ];

  @override
  void initState() {
    super.initState();
  }

  void _onListViewPress(OnListViewPress value) async {
    switch (value) {
      case OnListViewPress.logout:
        ErrorDialogParameter parameter = ErrorDialogParameter(
            context: context,
            desc: R.current.logoutWarning,
            dialogType: DialogType.warning,
            title: R.current.warning,
            btnOkText: R.current.sure,
            btnOkOnPress: () {
              Get.back();
              TaskFlow.resetLoginStatus();
              Model.instance.logout().then((_) {
                widget.pageController.jumpToPage(0);
              });
            });
        ErrorDialog(parameter).show();
        break;
      case OnListViewPress.login:
        RouteUtils.toLoginScreen().then((value) {
          if (value) widget.pageController.jumpToPage(0);
        });
        break;
      case OnListViewPress.fileViewer:
        FileStore.findLocalPath(context).then((filePath) {
          RouteUtils.toFileViewerPage(R.current.fileViewer, filePath);
        });
        break;
      case OnListViewPress.changePassword:
        String changePasswordUrl =
            "https://stuinfosys.ntust.edu.tw/NTUSTSSOServ/SSO/ChangePWD";
        RouteUtils.toWebViewPage(R.current.changePassword, changePasswordUrl);
        break;
      case OnListViewPress.about:
        RouteUtils.toAboutPage();
        break;
      case OnListViewPress.setting:
        RouteUtils.toSettingPage(widget.pageController);
        break;
      case OnListViewPress.report:
        String link = AppLink.feedbackBaseUrl;
        try {
          String mainVersion = await AppUpdate.getAppVersion();
          link = AppLink.feedback(mainVersion, LogConsole.getLog());
        } catch (e) {
          Log.d(e);
        }
        RouteUtils.toWebViewPage(R.current.feedback, link);
        break;
      case OnListViewPress.changePassword:
        MyToast.show(R.current.noFunction);
        break;
      default:
        MyToast.show(R.current.noFunction);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(R.current.titleOther),
      ),
      body: Column(children: <Widget>[
        const SizedBox(
          height: 16,
        ),
        if (Model.instance.getAccount().isNotEmpty)
          Container(
            padding: const EdgeInsets.only(
                top: 24.0, left: 24.0, right: 24.0, bottom: 24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(
                  width: 16.0,
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (Model.instance.getAccount().isEmpty)
                          ? R.current.pleaseLogin
                          : Model.instance.getAccount(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(
          height: 16,
        ),
        Expanded(
          child: AnimationLimiter(
            child: ListView.builder(
              itemCount: optionList.length,
              itemBuilder: (BuildContext context, int index) {
                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 375),
                  child: ScaleAnimation(
                    child: _buildSetting(optionList[index]),
                  ),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildSetting(Map data) {
    return InkWell(
      onTap: () {
        _onListViewPress(data['onPress']);
      },
      child: Container(
        padding: const EdgeInsets.only(
            top: 24.0, left: 24.0, right: 24.0, bottom: 24.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              data['icon'],
              color: data['color'],
            ),
            const SizedBox(
              width: 20.0,
            ),
            Expanded(
              child: Text(
                data['title'],
                style: const TextStyle(fontSize: 18),
              ),
            )
          ],
        ),
      ),
    );
  }
}
