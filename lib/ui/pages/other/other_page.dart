import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_link.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/controller/main_page/main_controller.dart';
import 'package:flutter_app/src/file/file_store.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/src/version/update/app_update.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/page/loading_page.dart';
import 'package:flutter_app/ui/other/error_dialog.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:flutter_app/ui/pages/log_console/log_console.dart';
import 'package:flutter_app/ui/pages/other/components/user_profile.dart';
import 'package:flutter_app/ui/pages/password/check_password_dialog.dart';
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
  const OtherPage({
    super.key,
  });

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
            btnOkOnPress: () async {
              Get.back();
              TaskFlow.resetLoginStatus();
              await Model.instance.logout();
              Get.find<MainController>().pageController.jumpToPage(0);
            });
        ErrorDialog(parameter).show();
        break;
      case OnListViewPress.login:
        RouteUtils.toLoginScreen();
        break;
      case OnListViewPress.fileViewer:
        FileStore.findLocalPath(context).then((filePath) {
          RouteUtils.toFileViewerPage(R.current.fileViewer, filePath);
        });
        break;
      case OnListViewPress.changePassword:
        if (await Get.dialog(const CheckPasswordDialog())) {
          bool first = true;
          String changePasswordUrl =
              "https://stuinfosys.ntust.edu.tw/NTUSTSSOServ/SSO/ChangePWD";
          RouteUtils.toWebViewPage(R.current.changePassword, changePasswordUrl,
              loadDone: (webView) async {
            if (!first) {
              return;
            }
            first = false;
            await webView.evaluateJavascript(
                source:
                    'document.getElementsByName("userName")[0].value = "${Model.instance.getAccount()}";');
            await webView.evaluateJavascript(
                source:
                    'document.getElementsByName("pwd")[0].value = "${Model.instance.getPassword()}";');
          });
        }
        break;
      case OnListViewPress.about:
        RouteUtils.toAboutPage();
        break;
      case OnListViewPress.setting:
        RouteUtils.toSettingPage();
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
      appBar: mainAppbar(title: R.current.titleOther),
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(
              height: 20,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: _buildAccountTile(),
            ),
            const SizedBox(
              height: 12,
            ),
            Expanded(
              child: AnimationLimiter(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
                  separatorBuilder: (context, index) {
                    return const SizedBox(height: 4);
                  },
                ),
              ),
            ),
          ]),
    );
  }

  Widget _buildSetting(Map data) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: () {
        _onListViewPress(data['onPress']);
      },
      title: Text(
        data['title'],
        style: const TextStyle(fontSize: 18),
      ),
      leading: Icon(
        data['icon'],
        color: data['color'],
      ),
    );
  }

  Widget _buildAccountTile() {
    if (Model.instance.getAccount().isEmpty) {
      return Text(R.current.pleaseLogin);
    }

    return FutureBuilder<MoodleProfileEntity?>(
      future: MoodleWebApiConnector.getProfile(),
      builder: (context, snapshot) {
        if(!snapshot.hasData || snapshot.data == null) {
          return const LoadingPage(isLoading: true, isShowBackground: false,);
        }

        return UserProfile(data: snapshot.data!);
      }
    );
  }
}
