import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart'
    show MoodleWebApiConnector;
import 'package:flutter_app/src/controller/announcement/announcement_center_controller.dart';
import 'package:flutter_app/src/controller/announcement/announcement_center_preview.dart';
import 'package:flutter_app/src/controller/announcement/notification_badge_controller.dart';
import 'package:flutter_app/src/model/announcement/announcement_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_message_popup_notifications.dart';
import 'package:flutter_app/src/native/course_moodle_bridge.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/util/announcement_text.dart';
import 'package:flutter_app/src/util/moodle_notification_utils.dart';
import 'package:flutter_app/src/util/notification_groups.dart';
import 'package:intl/intl.dart';

/// 原生版的通知中心。狀態與已讀照 `AnnouncementCenterController`，版面上的字照
/// `announcement_center_page.dart`。
class InboxBridge implements TatInboxApi {
  InboxBridge({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  AnnouncementCenterController _controller = AnnouncementCenterController();
  bool _preview = false;

  static void install() => TatInboxApi.setUp(InboxBridge());

  /// 每次進頁換一顆 controller：公告的已讀快照是一頁一份。
  @override
  Future<InboxState> load() async {
    final controller = AnnouncementCenterController();
    _controller = controller;
    _preview = false;
    await controller.loadAll();
    return _stateOf(controller);
  }

  @override
  Future<InboxState> refresh() async {
    final controller = _controller;
    await controller.refreshAll();
    return _stateOf(controller);
  }

  @override
  Future<InboxState> retryNotifications() async {
    final controller = _controller;
    await controller.loadNotifications(background: false);
    return _stateOf(controller);
  }

  @override
  Future<InboxState> markRead(int id) async {
    final controller = _controller;
    final notification = _find(controller, id);
    if (notification != null) await controller.markRead(notification);
    return _stateOf(controller);
  }

  @override
  Future<InboxMarkAll> markAllRead() async {
    final controller = _controller;
    final ok = await controller.markAllRead();
    return InboxMarkAll(ok: ok, state: _stateOf(controller));
  }

  @override
  Future<WebLink?> openLink(int id) async {
    final notification = _find(_controller, id);
    final url = notification == null
        ? null
        : MoodleNotificationUtils.openUrlOf(notification,
            siteHost: MoodleWebApiConnector.siteHost);
    if (url == null) return null;
    if (_preview) {
      // 預覽不開 WebView：那條路要 autologin，等於拿真的鑰匙去換假資料的網址。
      TaskUiDelegate.instance.toast('preview → $url');
      return null;
    }
    return CourseMoodleBridge.webLinkOf(url);
  }

  @override
  Future<int> badge(bool force) async {
    await NotificationBadgeController.instance.refresh(force: force);
    return NotificationBadgeController.instance.unread.value;
  }

  @override
  List<InboxPreviewItem> previewItems() => [
        for (final which in announcementPreviewMenu)
          InboxPreviewItem(title: which.title, subtitle: which.subtitle),
      ];

  @override
  InboxState startPreview(int index) {
    final controller =
        AnnouncementCenterPreviewController(announcementPreviewMenu[index]);
    _controller = controller;
    _preview = true;
    return _stateOf(controller);
  }

  static MoodleNotification? _find(
          AnnouncementCenterController controller, int id) =>
      controller.notifications.value?.dataOrNull?.notifications
          .where((n) => n.id == id)
          .firstOrNull;

  InboxState _stateOf(AnnouncementCenterController controller) {
    final now = _preview ? announcementPreviewNow : _clock();
    final notices = AnnouncementCenterController.sortForList(
        controller.appNotices.value?.dataOrNull ?? const []);
    final result = controller.notifications.value;
    final data = result?.dataOrNull;
    final empty = data != null && data.notifications.isEmpty;
    return InboxState(
      notices: [for (final notice in notices) noticeOf(notice)],
      noticeUnread: notices.isNotEmpty &&
          AnnouncementCenterController.isUnread(
              notices.first, controller.lastReadSnapshot),
      sections: data == null
          ? const []
          : [
              for (final group in NotificationGroups.groupByAge(
                  MoodleNotificationUtils.sortNewestFirst(data.notifications),
                  now))
                InboxSection(
                  title: NotificationGroups.labelOf(group.bucket),
                  rows: [for (final n in group.items) _row(n, now)],
                ),
            ],
      emptyMessage: empty ? R.current.notificationEmpty : null,
      // 清單空但未讀數不是 0 ＝ 使用者在 Moodle 關掉了站內通知，跟「真的沒有通知」是兩件事。
      emptyHint: empty
          ? (MoodleNotificationUtils.looksDisabledByUser(data)
              ? R.current.notificationDisabledOnMoodle
              : R.current.notificationEmptyHint)
          : null,
      error: switch (result) {
        Failed(:final reason) => reason.message,
        _ => null,
      },
      notice: switch (result) {
        Stale(:final reason) => reason.message,
        _ => null,
      },
      signedIn: AuthSession.instance.isSignedIn,
      // `Stale` 幾乎一定是離線，提供一個必定失敗的寫入比不提供更糟。
      canMarkAll: switch (result) {
        Ok(:final data) => data.unreadcount > 0,
        _ => false,
      },
    );
  }

  /// startTime 是 UTC 欄位裝著台北的牆上時間（見 RemoteConfigUtils），toLocal() 會讓
  /// 日期整整位移八小時。
  static InboxNotice noticeOf(AnnouncementInfoJson info) => InboxNotice(
        title: info.title,
        content: info.content,
        date: DateFormat.MMMd().format(info.startTime),
        excerpt: AnnouncementText.plainExcerpt(info.content),
      );

  static InboxRow _row(MoodleNotification n, DateTime now) => InboxRow(
        id: n.id,
        subject: n.subject,
        source: NotificationGroups.sourceLabelOf(n),
        time: NotificationGroups.formatCreatedTime(n.createdTime, now),
        unread: !n.read,
        kind: InboxKind.values.byName(MoodleNotificationUtils.kindOf(
                n.component,
                eventtype: n.eventtype)
            .name),
        openable: MoodleNotificationUtils.openUrlOf(n,
                siteHost: MoodleWebApiConnector.siteHost) !=
            null,
        bodyHtml: MoodleNotificationUtils.bodyHtmlOf(n),
      );
}
