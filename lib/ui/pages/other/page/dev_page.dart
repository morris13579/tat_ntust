import 'dart:async';

import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/util/cloud_messaging_utils.dart';
import 'package:flutter_app/src/util/remote_config_utils.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/tile/settings_tile.dart';
import 'package:flutter_app/ui/components/toast/tat_toast.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/routes/route_utils.dart';
import 'package:in_app_review/in_app_review.dart';

enum DevMenuAction {
  cloudMessageToken,
  dioLog,
  appLog,
  storeEdit,
  announcement,
  notificationPreview,
  storeReview
}

class DevPage extends StatefulWidget {
  const DevPage({super.key});

  @override
  State<StatefulWidget> createState() => _DevPageState();
}

class _DevPageState extends State<DevPage> {
  /// 開發用的項目，字串刻意不進翻譯檔。
  static const _rows = <({IconData icon, String title, DevMenuAction action})>[
    (
      icon: LucideIcons.keyRound,
      title: 'Cloud Messaging Token',
      action: DevMenuAction.cloudMessageToken
    ),
    (icon: LucideIcons.info, title: 'Dio Log', action: DevMenuAction.dioLog),
    (icon: LucideIcons.info, title: 'App Log', action: DevMenuAction.appLog),
    (
      icon: LucideIcons.pencil,
      title: 'Store Edit',
      action: DevMenuAction.storeEdit
    ),
    (
      icon: LucideIcons.megaphone,
      title: 'Announcement',
      action: DevMenuAction.announcement
    ),
    (
      icon: LucideIcons.bell,
      title: 'Notification Preview',
      action: DevMenuAction.notificationPreview
    ),
    (
      icon: LucideIcons.shieldCheck,
      title: 'Store Review',
      action: DevMenuAction.storeReview
    ),
  ];

  @override
  void initState() {
    super.initState();
    RemoteConfigUtils.init(focusUpdate: true);
  }

  void _onListViewPress(DevMenuAction value) async {
    switch (value) {
      case DevMenuAction.cloudMessageToken:
        String? token = await CloudMessagingUtils.getToken();
        TatToast.show("${token!} copy");
        unawaited(FlutterClipboard.copy(token));
        break;
      case DevMenuAction.dioLog:
        DioConnector.instance.alice.showInspector();
        break;
      case DevMenuAction.appLog:
        unawaited(RouteUtils.toLogConsolePage());
        break;
      case DevMenuAction.storeEdit:
        unawaited(RouteUtils.toStoreEditPage());
        break;
      case DevMenuAction.announcement:
        unawaited(RouteUtils.showAnnouncement(test: true));
        break;
      case DevMenuAction.notificationPreview:
        unawaited(RouteUtils.toNotificationPreviewPage());
        break;
      case DevMenuAction.storeReview:
        // 直接叫系統的評分視窗，跳過那三道門檻。系統自己也會擋（Apple 一年
        // 只給三次、debug build 多半什麼都不會出現），所以叫不出來是正常的。
        if (await InAppReview.instance.isAvailable()) {
          unawaited(InAppReview.instance.requestReview());
        } else {
          TatToast.show('in_app_review 不可用');
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: baseAppbar(title: R.current.developerMode),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (var i = 0; i < _rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 2),
            SettingsTile(
              icon: _rows[i].icon,
              title: _rows[i].title,
              onTap: () => _onListViewPress(_rows[i].action),
              index: i,
              length: _rows.length,
            ),
          ],
        ],
      ),
    );
  }
}
