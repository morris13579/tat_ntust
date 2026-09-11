import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/controller/announcement/announcement_center_controller.dart';
import 'package:flutter_app/src/model/announcement/announcement_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_message_popup_notifications.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/util/moodle_notification_utils.dart';
import 'package:flutter_app/ui/components/card/section_card.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/page/inline_error_view.dart';
import 'package:flutter_app/ui/components/page/result_view.dart';
import 'package:flutter_app/ui/components/page/web_view_opener.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/tat_dialog.dart';
import 'package:flutter_app/ui/pages/announcement/announcement_page.dart';
import 'package:flutter_app/ui/pages/announcement/components/announcement_banner.dart';
import 'package:flutter_app/ui/pages/announcement/components/notification_empty_view.dart';
import 'package:flutter_app/ui/pages/announcement/components/notification_groups.dart';
import 'package:flutter_app/ui/pages/announcement/notification_tile.dart';
import 'package:get/get.dart';

/// 「通知」：最上面是 TAT 自己的公告（Remote Config，同啟動彈窗的內容）擺成
/// 一張色塊卡，底下是 Moodle 站內通知，依今天／本週／更早分組。
/// WebView 開啟器由呼叫端注入，見 docs/ARCHITECTURE.md「UI 慣例」。
///
/// TAT 公告只畫最新的一則：一年只有兩三則，開一個永遠只有 0–1 列的區塊
/// 比不開更空。其餘幾則在點「看完整公告」之後的 [AnnouncementPage] 裡翻。
///
/// 每一半都只是頁面中段的一個區塊，失敗畫面一律是 `InlineErrorView`，
/// 這一頁不需要注入頁面層級的 errorBuilder。
class AnnouncementCenterPage extends StatefulWidget {
  const AnnouncementCenterPage({
    super.key,
    required this.openWebView,
    this.controller,
    this.clock = DateTime.now,
  });

  final WebViewOpener openWebView;

  /// 測試注入預先載好的狀態；注入時這一頁不會自己再發請求。
  final AnnouncementCenterController? controller;

  /// 「現在」，時間欄與分組的基準。
  final DateTime Function() clock;

  @override
  State<StatefulWidget> createState() => _AnnouncementCenterPageState();
}

class _AnnouncementCenterPageState extends State<AnnouncementCenterPage> {
  late final AnnouncementCenterController _controller;
  late final bool _ownsController;

  /// 沒有 contexturl、就地展開內文的那幾列。
  final Set<int> _expanded = {};

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? AnnouncementCenterController();
    if (_ownsController) unawaited(_controller.loadAll());
  }

  @override
  void dispose() {
    // 注入進來的那一顆屬於呼叫端（測試），不歸這裡收。
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: baseAppbar(
        title: R.current.notificationCenterTitle,
        // 設計稿上沒有這顆鈕——清單本身該乾淨。放進 appbar 的 action 是唯一
        // 不會擠掉分組標題與列的位置。
        action: [_MarkAllReadButton(controller: _controller)],
      ),
      body: RefreshIndicator(
        onRefresh: _controller.refreshAll,
        // 用 sliver 而不是 ListView：空狀態要在「公告卡以下的剩餘高度」裡置中，
        // 而捲動清單給每一格的高度就是那一格自己的高度，`Center` 在裡面只剩
        // 水平置中。剩下多少高度只有 sliver 量得到。
        child: Obx(() => CustomScrollView(
              // 清單空或是錯誤畫面時也要拉得動。
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // 沒有公告時這一格是零高度（連內距都沒有），空狀態才會落在
                // 整個畫面的正中央而不是被上面那點內距推低半格。
                SliverToBoxAdapter(child: _buildBanner()),
                _buildNotificationsSliver(),
              ],
            )),
      ),
    );
  }

  /// 通知那一半。有清單時就是頁面中段的一段；空的時候改成吃掉剩餘高度的
  /// [SliverFillRemaining]，那張空狀態才會真的落在畫面中央。
  ///
  /// 只有空清單走 fill remaining：它是先問 child 的 intrinsic 高度再決定要不要
  /// 撐開，而通知列展開後裡面是 `MoodleHtmlView`，那東西量不得。
  Widget _buildNotificationsSliver() {
    final content = ResultView<MoodleNotificationList>(
      shrinkWrap: true,
      state: _controller.notifications,
      onRetry: _reloadNotifications,
      errorBuilder: (message) => InlineErrorView(
        message: message,
        onRetry: _reloadNotifications,
      ),
      builder: _buildNotifications,
    );
    final data = _controller.notifications.value?.dataOrNull;
    if (data != null && data.notifications.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: content,
        ),
      );
    }
    return SliverPadding(
      // 上緣的 12 由公告卡自己帶，沒有卡片時才由這裡補。
      padding: EdgeInsets.fromLTRB(12, _notices.isEmpty ? 12 : 0, 12, 32),
      sliver: SliverToBoxAdapter(child: content),
    );
  }

  /// 重試是使用者主動按的，所以 `background: false`：這時候才可以開登入頁。
  Future<void> _reloadNotifications() =>
      _controller.loadNotifications(background: false);

  /// 最新的一則 TAT 公告，新到舊排序後的第一則。
  List<AnnouncementInfoJson> get _notices {
    final list = _controller.appNotices.value?.dataOrNull ?? const [];
    return list.isEmpty
        ? const []
        : AnnouncementCenterController.sortForList(list);
  }

  /// 公告那一半失敗時什麼都不畫：它是一張「順便看看」的卡，為它在通知清單
  /// 上方擺一整塊紅色錯誤畫面，等於讓次要內容蓋掉主要內容。下拉重新整理
  /// 本來就會再試一次。
  Widget _buildBanner() {
    final notices = _notices;
    if (notices.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: AnnouncementBanner(
        info: notices.first,
        unread: AnnouncementCenterController.isUnread(
            notices.first, _controller.lastReadSnapshot),
        onOpen: () => unawaited(_openAnnouncement(notices)),
      ),
    );
  }

  /// 公告全文。整份清單一起帶過去，那一頁自己有翻頁；index 0 就是卡片上
  /// 這一則（[_notices] 已經排好）。倒數是啟動彈窗才需要的東西，這裡是
  /// 使用者自己點進來的，傳 0。
  Future<void> _openAnnouncement(List<AnnouncementInfoJson> notices) =>
      Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => AnnouncementPage(info: notices, countDown: 0),
      ));

  Widget _buildNotifications(MoodleNotificationList data) {
    if (data.notifications.isEmpty) {
      // 清單空但未讀數不是 0 ＝ 使用者在 Moodle 關掉了站內通知，
      // 跟「真的沒有通知」是兩件事，所以只換第二行的說明。
      return NotificationEmptyView(
        message: R.current.notificationEmpty,
        hint: MoodleNotificationUtils.looksDisabledByUser(data)
            ? R.current.notificationDisabledOnMoodle
            : R.current.notificationEmptyHint,
      );
    }

    final now = widget.clock();
    final items = MoodleNotificationUtils.sortNewestFirst(data.notifications);
    final groups = NotificationGroups.groupByAge(items, now);
    // 上面有公告卡時第一個分組標題要留出正常的段距；沒有的話它就是整頁的
    // 第一個元素，`first` 才把上緣收緊。
    final hasBanner = _notices.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var g = 0; g < groups.length; g++) ...[
          SectionHeader(
            title: NotificationGroups.labelOf(groups[g].bucket),
            first: g == 0 && !hasBanner,
          ),
          for (var i = 0; i < groups[g].items.length; i++) ...[
            if (i > 0) const SizedBox(height: 2),
            _buildTile(groups[g].items[i], now, i, groups[g].items.length),
          ],
        ],
      ],
    );
  }

  Widget _buildTile(MoodleNotification n, DateTime now, int index, int length) {
    final url = MoodleNotificationUtils.openUrlOf(
      n,
      siteHost: MoodleWebApiConnector.siteHost,
    );
    return NotificationTile(
      key: ValueKey('notification-${n.id}'),
      notification: n,
      now: now,
      openable: url != null,
      expanded: _expanded.contains(n.id),
      openWebView: widget.openWebView,
      index: index,
      length: length,
      onTap: () => unawaited(_onTap(n, url)),
    );
  }

  Future<void> _onTap(MoodleNotification n, String? url) async {
    // 標記已讀是背景寫入，失敗只 toast：使用者的意圖是打開它，不是管理已讀狀態。
    unawaited(_controller.markRead(n));
    if (url == null) {
      setState(() {
        if (!_expanded.remove(n.id)) _expanded.add(n.id);
      });
      return;
    }
    // 不自己呼叫 autologinUrl：注入進來的開啟器（RouteUtils.toWebViewPage）
    // 已經做了，再換一次會在伺服器 6 分鐘的節流內白燒一把鑰匙。
    await widget.openWebView(n.subject, url);
  }
}

/// 「全部標為已讀」。只在有未讀而且是 `Ok`（不是 `Stale`）時出現：`Stale`
/// 幾乎一定是離線，提供一個必定失敗的寫入比不提供更糟。
///
/// 是圖示鈕不是文字鈕：appbar 上的標題只有兩個字，一顆六個字的文字鈕會變成
/// 那一列最搶眼的東西。
class _MarkAllReadButton extends StatelessWidget {
  const _MarkAllReadButton({required this.controller});

  final AnnouncementCenterController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.markingAll.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
      final state = controller.notifications.value;
      final unread = switch (state) {
        Ok(:final data) => data.unreadcount,
        _ => 0,
      };
      if (unread <= 0) return const SizedBox.shrink();
      return IconButton(
        tooltip: R.current.notificationMarkAllRead,
        icon: const Icon(LucideIcons.checkCheck, size: 20),
        onPressed: () => unawaited(_confirmAndMark()),
      );
    });
  }

  /// 伺服器預設在已讀 7 天後刪除通知，所以這是有破壞性的操作，要先問。
  ///
  /// 對話框刻意不寫數字：`core_message_mark_all_notifications_as_read` 標的是
  /// `{notifications}` 全部，而畫面上的未讀數只算 popup 那一部分，寫上去等於
  /// 少報這次寫入的範圍。
  Future<void> _confirmAndMark() async {
    final confirmed = await showTatDialog<bool>(
      dialog: TatDialog(
        title: R.current.notificationMarkAllRead,
        body: R.current.notificationMarkAllReadConfirm,
        kind: TatDialogKind.warning,
        destructive: true,
        secondary: TatDialogAction(
          label: R.current.cancel,
          onPressed: () => Get.back<bool>(result: false),
        ),
        primary: TatDialogAction(
          label: R.current.sure,
          onPressed: () => Get.back<bool>(result: true),
        ),
      ),
    );
    if (confirmed != true) return;
    if (await controller.markAllRead()) {
      TaskUiDelegate.instance.toast(R.current.notificationMarkAllReadDone);
    }
  }
}
