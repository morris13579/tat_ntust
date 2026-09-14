import 'package:flutter/foundation.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/native/inbox_bridge.dart';
import 'package:flutter_app/src/util/remote_config_utils.dart';
import 'package:upgrader/upgrader.dart';

/// 原生版啟動時的公告彈窗與更新提示，照 `main.dart` 的 `onReady` 與 `UpdatePrompt`。
class AppNoticeBridge implements TatAppNoticeApi {
  AppNoticeBridge({Future<AnnouncementRequest?> Function(bool test)? resolve})
      : _resolve = resolve ??
            ((test) => RemoteConfigUtils.resolveAnnouncement(test: test));

  final Future<AnnouncementRequest?> Function(bool test) _resolve;

  /// 只建一次，照 `UpdatePrompt`：略過的版本與上次問的時間記在它身上。
  Upgrader? _upgrader;

  static void install() => TatAppNoticeApi.setUp(AppNoticeBridge());

  @override
  Future<LaunchAnnouncement?> launchAnnouncement(bool test) async {
    try {
      final request = await _resolve(test);
      if (request == null) return null;
      return LaunchAnnouncement(
        notices: [for (final info in request.info) InboxBridge.noticeOf(info)],
        countDown: request.countDown,
      );
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  @override
  Future<void> markAnnouncementRead() => RemoteConfigUtils.setAnnouncementRead();

  @override
  Future<UpdateOffer?> updateOffer(bool manual) async {
    try {
      final upgrader = _upgrader ??= Upgrader(
        durationUntilAlertAgain: const Duration(days: 1),
        debugLogging: kDebugMode,
      );
      await upgrader.initialize();
      final available =
          manual ? upgrader.isUpdateAvailable() : upgrader.shouldDisplayUpgrade();
      if (!available) return null;
      final url = upgrader.currentAppStoreListingURL;
      final store = upgrader.currentAppStoreVersion;
      final installed = upgrader.currentInstalledVersion;
      if (url == null || store == null || installed == null) return null;
      // 照 UpgradeAlert：自己跳出來的那一刻就算問過，一天之內不再問；使用者自己來問的不算。
      if (!manual) await upgrader.saveLastAlerted();
      return UpdateOffer(
        installedVersion: installed,
        storeVersion: store,
        releaseNotes: upgrader.releaseNotes,
        storeUrl: url,
      );
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  @override
  Future<void> ignoreUpdate() async {
    await _upgrader?.saveIgnored();
  }

  @override
  Future<void> refreshRemoteConfig() =>
      RemoteConfigUtils.init(focusUpdate: true);
}
