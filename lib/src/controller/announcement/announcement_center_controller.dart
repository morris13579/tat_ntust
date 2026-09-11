import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/controller/announcement/notification_badge_controller.dart';
import 'package:flutter_app/src/model/announcement/announcement_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_message_popup_notifications.dart';
import 'package:flutter_app/src/repository/app_notice_repository.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/store/settings_store.dart';
import 'package:flutter_app/src/util/moodle_notification_utils.dart';
import 'package:get/get.dart';

/// 公告與通知頁的狀態：App 公告與 Moodle 站內通知兩半，由頁面的 State 建立與
/// [dispose]（同 `CourseAssignmentController`）。
///
/// 這一層只回資料、不開對話框：「全部標為已讀」的確認框由頁面自己開。
class AnnouncementCenterController {
  AnnouncementCenterController();

  final Rxn<Result<List<AnnouncementInfoJson>>> appNotices = Rxn();
  final Rxn<Result<MoodleNotificationList>> notifications = Rxn();
  final RxBool markingAll = false.obs;

  /// 進頁那一刻的公告已讀時間。畫面上的未讀點整頁都用這個快照算，否則
  /// [_markAppNoticesRead] 一寫下去，使用者眼前的點就自己消失了。
  DateTime lastReadSnapshot = DateTime.utc(2000);

  bool _appNoticesReadWritten = false;
  bool _lastReadCaptured = false;

  /// 這則公告在進頁時是不是還沒讀過。判準是 `RemoteConfigUtils.getAnnouncement`
  /// 裡那個 `startTime.isBefore(lastRead)` 的反面，所以啟動彈窗按過確定的公告
  /// 不會在這裡又變回未讀。
  static bool isUnread(AnnouncementInfoJson info, DateTime lastRead) =>
      !info.startTime.isBefore(lastRead);

  /// 新的排前面。
  static List<AnnouncementInfoJson> sortForList(
      List<AnnouncementInfoJson> list) {
    final indexed = [
      for (var i = 0; i < list.length; i++) (i, list[i]),
    ]..sort((a, b) {
        final byTime = b.$2.startTime.compareTo(a.$2.startTime);
        return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
      });
    return [for (final entry in indexed) entry.$2];
  }

  Future<void> loadAll() =>
      Future.wait([loadAppNotices(), loadNotifications(background: true)]);

  Future<void> loadAppNotices() async {
    appNotices.value = null;
    appNotices.value = await _fetchAppNotices();
  }

  /// [background] 為 true 時不開登入頁、不彈重試框：只是按了大聲公，不該
  /// 對沒登入 Moodle 的使用者丟一個登入 WebView。下拉重新整理與重試傳 false。
  Future<void> loadNotifications({bool background = true}) async {
    notifications.value = null;
    notifications.value = await MoodleRepository.instance
        .getNotifications(background: background);
    _pushBadge();
  }

  /// 下拉重新整理：兩半都重抓，但**不把 `Rxn` 設回 null**，否則畫面會在
  /// `RefreshIndicator` 自己的轉圈之外再閃一次 LoadingPage。
  Future<void> refreshAll() async {
    await Future.wait([
      _fetchAppNotices().then((value) => appNotices.value = value),
      MoodleRepository.instance
          .getNotifications(background: false)
          .then((value) => notifications.value = value),
    ]);
    _pushBadge();
  }

  Future<Result<List<AnnouncementInfoJson>>> _fetchAppNotices() async {
    // 快照只取一次。下拉重新整理時再讀一次會讀到 [_markAppNoticesRead] 剛寫
    // 下去的時間，使用者眼前的未讀點會自己消失。
    if (!_lastReadCaptured) {
      _lastReadCaptured = true;
      lastReadSnapshot = await SettingsStore.instance.announcementLastRead;
    }
    final result = await AppNoticeRepository.instance.getNotices();
    await _markAppNoticesRead(result);
    return result;
  }

  /// 看得到公告就等於讀過了——這與啟動彈窗按「確定」寫的是同一個 key，所以
  /// 在這一頁看過的公告不會再以彈窗跳出來。
  ///
  /// 只認 `Ok`：`Stale` 是離線讀快取，那份清單可能是幾個月前的，寫下去會把
  /// 「快取那天之後才發布、使用者根本沒看過」的公告一起標成已讀。
  Future<void> _markAppNoticesRead(
      Result<List<AnnouncementInfoJson>> result) async {
    if (_appNoticesReadWritten) return;
    if (result is! Ok<List<AnnouncementInfoJson>>) return;
    final list = result.data;
    if (list.isEmpty) return;
    _appNoticesReadWritten = true;
    // 寫「畫面上最新那一則的發布時間」而不是 now：Remote Config 的
    // minimumFetchInterval 是一小時，now 會把這一小時內發布、還沒抓到的那些
    // 公告一起吃掉。加 1 毫秒是為了讓最新那一則自己落在已讀那一側
    // （判準是 `startTime.isBefore(lastRead)`）。
    final newest = list
        .map((e) => e.startTime)
        .reduce((a, b) => a.isAfter(b) ? a : b)
        .add(const Duration(milliseconds: 1));
    // 絕不倒退：啟動彈窗按過確定之後的時間比這一批公告新，覆蓋回去會讓
    // 已經讀過的公告全部變回未讀。
    if (!newest.isAfter(lastReadSnapshot)) return;
    await SettingsStore.instance.markAnnouncementReadUpTo(newest);
  }

  /// 樂觀標記已讀：先改畫面再打伺服器，失敗就回捲並 toast。
  ///
  /// `Ok` / `Stale` 都沒有覆寫 `==`，而 `Rxn` 只在 `.value =` 時通知，所以
  /// 一定要指派一個**新的**實例（[_rewrap]），改欄位本身不會重畫。
  Future<void> markRead(MoodleNotification n) async {
    // Stale（離線讀快取）時也要能標已讀，所以看 dataOrNull 而不是只認 Ok。
    final current = notifications.value?.dataOrNull;
    if (current == null || n.read) return;

    _applyRead(current, n, true);
    final result = await MoodleRepository.instance.markNotificationRead(n.id);
    if (!result.hasData) {
      _applyRead(current, n, false);
      TaskUiDelegate.instance.toast(R.current.notificationMarkReadError);
      return;
    }
    // 不回寫的話，下一次讀快取（離線）會把剛剛標掉的圓點與未讀數整批復活。
    await MoodleRepository.instance.saveNotifications(current);
  }

  void _applyRead(
      MoodleNotificationList list, MoodleNotification n, bool read) {
    n.read = read;
    n.timeread = read ? DateTime.now().millisecondsSinceEpoch ~/ 1000 : null;
    list.unreadcount =
        read ? (list.unreadcount - 1).clamp(0, 1 << 31) : list.unreadcount + 1;
    notifications.value = _rewrap(list);
    _pushBadge();
  }

  /// 保留原本的外殼型別。一律換成 `Ok` 會讓離線時的「你在看舊資料」橫幅消失，
  /// 還會把刻意藏起來的「全部標為已讀」變出來——那個寫入離線必定失敗。
  /// `Failed` 走不到這裡：呼叫端在 `dataOrNull == null` 時就回頭了。
  Result<MoodleNotificationList> _rewrap(MoodleNotificationList list) =>
      switch (notifications.value) {
        Stale(:final reason) => Stale(list, reason),
        _ => Ok(list),
      };

  /// 全部標為已讀。成功回 true；失敗只 toast，資料不動。
  Future<bool> markAllRead() async {
    final current = notifications.value?.dataOrNull;
    if (current == null || markingAll.value) return false;

    markingAll.value = true;
    try {
      final result = await MoodleRepository.instance.markAllNotificationsRead();
      if (!result.hasData) {
        TaskUiDelegate.instance.toast(R.current.notificationMarkAllReadError);
        return false;
      }
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      for (final n in current.notifications) {
        if (n.read) continue;
        n.read = true;
        n.timeread = now;
      }
      current.unreadcount = 0;
      notifications.value = _rewrap(current);
      _pushBadge();
      await MoodleRepository.instance.saveNotifications(current);
      return true;
    } finally {
      markingAll.value = false;
    }
  }

  /// 清單那一趟本來就回未讀數，紅點不必再打一次請求。
  ///
  /// 只認 `Ok`：`Stale` 是快取裡的舊數字，拿它蓋掉剛輪詢到的值等於謊報，
  /// 與 `NotificationBadgeController.refresh` 立下的規則同一條。
  void _pushBadge() {
    if (notifications.value case Ok(:final data)) {
      final badge = NotificationBadgeController.instance;
      // 使用者關掉站內通知時清單永遠是空的，那個未讀數在 App 內沒有非破壞性的
      // 辦法清掉，留著只會變成一顆永遠亮著、按不掉的紅點。
      final disabled = MoodleNotificationUtils.looksDisabledByUser(data);
      badge.setDisabled(disabled);
      if (!disabled) badge.setCount(data.unreadcount);
    }
  }

  void dispose() {
    appNotices.close();
    notifications.close();
    markingAll.close();
  }
}
