import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/ad/ad_manager.dart';
import 'package:flutter_app/src/util/cloud_messaging_utils.dart';
import 'package:flutter_app/src/util/remote_config_utils.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/ui/other/input_dialog.dart';
import 'package:flutter_app/ui/other/listview_animator.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:get/get.dart';

enum onListViewPress { cloudMessageToken, dioLog, appLog, storeEdit, adRemove }

class DevPage extends StatefulWidget {
  const DevPage({Key? key}) : super(key: key);

  @override
  _DevPageState createState() => _DevPageState();
}

class _DevPageState extends State<DevPage> {
  List<Map> listViewData = [
    {
      "icon": Icons.vpn_key_outlined,
      "title": "Cloud Messaging Token",
      "color": Colors.green,
      "onPress": onListViewPress.cloudMessageToken
    },
    {
      "icon": Icons.info_outline,
      "title": "Dio Log",
      "color": Colors.blue,
      "onPress": onListViewPress.dioLog
    },
    {
      "icon": Icons.info_outline,
      "title": "App Log",
      "color": Colors.yellow,
      "onPress": onListViewPress.appLog
    },
    {
      "icon": Icons.edit_outlined,
      "title": "Store Edit",
      "color": Colors.green,
      "onPress": onListViewPress.storeEdit
    },
    {
      "icon": Icons.code_outlined,
      "title": "AD Remover",
      "color": Colors.red,
      "onPress": onListViewPress.adRemove
    },
  ];

  @override
  void initState() {
    super.initState();
    removeADItem();
  }

  Future<void> removeADItem() async {
    if (!await AdManager.getADEnable()) {
      int index = listViewData
          .indexWhere((e) => e["onPress"] == onListViewPress.adRemove);
      if (index >= 0) {
        setState(() {
          listViewData.removeAt(index);
        });
      }
    }
  }

  int pressTime = 0;

  void _onListViewPress(onListViewPress value) async {
    switch (value) {
      case onListViewPress.cloudMessageToken:
        String? token = await CloudMessagingUtils.getToken();
        MyToast.show(token! + " copy");
        FlutterClipboard.copy(token);
        break;
      case onListViewPress.dioLog:
        RouteUtils.toAliceInspectorPage();
        break;
      case onListViewPress.appLog:
        RouteUtils.toLogConsolePage();
        break;
      case onListViewPress.storeEdit:
        RouteUtils.toStoreEditPage();
        break;
      case onListViewPress.adRemove:
        await Get.dialog(CustomInputDialog(
          title: "Input Valid Code",
          initText: "",
          hint: "Please input valid code",
          onOk: (String value) async {
            List<String> keyList = await RemoteConfigUtils.getRemoveADKey();
            if (keyList.contains(value)) {
              MyToast.show("Remove AD success");
              AdManager.setADEnable(value);
            } else {
              MyToast.show("Invalid code");
            }
          },
          onCancel: (String value) {},
        ));
        removeADItem();
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
        title: Text(R.current.developerMode),
      ),
      body: ListView.separated(
        itemCount: listViewData.length,
        itemBuilder: (context, index) {
          Widget widget;
          widget = _buildAbout(listViewData[index]);
          return InkWell(
            child: WidgetAnimator(widget),
            onTap: () {
              _onListViewPress(listViewData[index]['onPress']);
            },
          );
        },
        separatorBuilder: (context, index) {
          // 顯示格線
          return Container(
            color: Colors.black12,
            height: 1,
          );
        },
      ),
    );
  }

  Container _buildAbout(Map data) {
    return Container(
      //color: Colors.yellow,
      padding:
          const EdgeInsets.only(top: 20.0, left: 20.0, right: 20.0, bottom: 20.0),
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
          Text(
            data['title'],
            style: const TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }
}
