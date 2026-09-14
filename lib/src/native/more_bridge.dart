import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_app/debug/log/console_output.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/auth/session_cleaner.dart';
import 'package:flutter_app/src/config/app_link.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/controller/announcement/notification_badge_controller.dart';
import 'package:flutter_app/src/controller/mail/mail_outbox_controller.dart';
import 'package:flutter_app/src/controller/mail/mail_watch_controller.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart'
    show MoodleWebApiConnector;
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/store/settings_store.dart';
import 'package:flutter_app/src/util/moodle_avatar_utils.dart';
import 'package:flutter_app/src/version/app_version.dart';
import 'package:github/github.dart';
import 'package:path_provider/path_provider.dart';

/// 原生版的「更多」分頁。個人資料照 `MainController`，登出照 `OtherPage._onLogout`。
class MoreBridge implements TatMoreApi {
  MoreBridge({void Function(TransferProgress progress)? onProgress})
      : _onProgress = onProgress ?? TatTransferHost().onProgress;

  static void install() => TatMoreApi.setUp(MoreBridge());

  final void Function(TransferProgress progress) _onProgress;

  @override
  bool isSignedIn() => AuthSession.instance.isSignedIn;

  @override
  Future<MoodleProfile?> profile(bool interactive) async {
    if (!AuthSession.instance.isSignedIn) return null;
    try {
      // 先確保 SSO 再碰 Moodle：launch.php 會轉址經過 ssoam2，順序反過來就是再登入一次。
      await AuthSession.instance
          .ensure({SystemId.ntustSso}, interactive: interactive);
      if (!await MoodleWebApiConnector.isMoodleTokenAvailable() &&
          await AuthSession.instance
                  .ensure({SystemId.moodleWebApi}, interactive: interactive) !=
              null) {
        return null;
      }
      final profile = await MoodleWebApiConnector.getProfile();
      if (profile == null) return null;
      final url = profile.userpictureurl;
      return MoodleProfile(
        name: profile.firstname,
        account: profile.username.toUpperCase(),
        avatarUrl: url.isEmpty ? null : url,
        customAvatar: MoodleAvatarUtils.hasCustomPicture(url),
      );
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  @override
  Future<String?> changeAvatar(Uint8List? jpeg) async {
    File? file;
    if (jpeg != null) {
      final directory = await getTemporaryDirectory();
      file = File(
          '${directory.path}/tat_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(jpeg);
    }
    try {
      final result = await MoodleRepository.instance.changeProfilePicture(
        file: file,
        // 照 `MainController.avatarProgress`：量不出來之前不報，原生端先整圈轉。
        onProgress: (sent, total) {
          if (total > 0) {
            _onProgress(TransferProgress(
              key: 'avatar',
              progress: sent / total,
              label: '',
              phase: TransferPhase.upload,
            ));
          }
        },
      );
      return switch (result) {
        Failed(:final reason) => reason.message,
        _ => null,
      };
    } finally {
      if (file != null && await file.exists()) await file.delete();
    }
  }

  @override
  Future<ThemeChoice> theme() async {
    final index = await SettingsStore.instance.themeModeIndex;
    return index >= 0 && index < ThemeChoice.values.length
        ? ThemeChoice.values[index]
        : ThemeChoice.system;
  }

  /// 與 Flutter 版的 `ThemeMode` 同一個索引：system、light、dark。
  @override
  Future<void> setTheme(ThemeChoice theme) =>
      SettingsStore.instance.setThemeModeIndex(theme.index);

  @override
  Future<int?> themeColor() => SettingsStore.instance.themeColor;

  @override
  Future<void> setThemeColor(int? argb) =>
      SettingsStore.instance.setThemeColor(argb);

  @override
  Future<String> feedbackUrl() async {
    try {
      return AppLink.feedback(
          await APPVersion.getAppVersion(), LogBuffer.getLog());
    } catch (e) {
      Log.d(e);
      return AppLink.feedbackBaseUrl;
    }
  }

  @override
  Future<List<ProjectContributor>?> contributors() async {
    try {
      final list = await GitHub()
          .repositories
          .listContributors(
              RepositorySlug(AppLink.githubOwner, AppLink.githubName))
          .toList();
      return [
        for (final contributor in list)
          ProjectContributor(
            login: contributor.login ?? '',
            avatarUrl: contributor.avatarUrl,
            url: contributor.htmlUrl,
          ),
      ];
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  @override
  Future<void> logout() async {
    await SessionCleaner(
      // WKWebView 的 cookie 在原生端清：Dart 這一側碰不到 WKWebsiteDataStore。
      clearWebViewCookies: () async {},
      clearDioCookies: () => DioConnector.instance.deleteCookies(),
      clearModel: () => Model.instance.logout(),
      // 桌面小工具的截圖只有 Android 有。
      clearWidgetImage: () async {},
    ).logoutAll();
    // 紅點是 process 級狀態，照 `OtherPage._onLogout`：不清的話換帳號後 B 會看到 A 的紅點。
    NotificationBadgeController.instance.reset();
    // 同理：信箱的基準不清，換帳號後第一輪會把 B 信箱裡本來就有的信整批當成新信；
    // 寄件匣的 timer 不收，會拿 B 的帳密去寄 A 寫的信。
    MailWatchController.instance.reset();
    MailOutboxController.instance.reset();
  }
}
