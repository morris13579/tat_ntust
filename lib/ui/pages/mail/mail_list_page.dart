import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/src/controller/mail/mail_controller.dart';
import 'package:flutter_app/src/controller/mail/mail_outbox_controller.dart';
import 'package:flutter_app/src/controller/mail/mail_watch_controller.dart';
import 'package:flutter_app/src/model/mail/mail_outbox_item.dart';
import 'package:flutter_app/src/model/mail/mail_message_json.dart';
import 'package:flutter_app/ui/components/card/section_card.dart';
import 'package:flutter_app/ui/components/chip/tat_filter_chip.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/input/search_bar.dart';
import 'package:flutter_app/ui/components/page/empty_state.dart';
import 'package:flutter_app/ui/components/page/inline_error_view.dart';
import 'package:flutter_app/ui/components/page/result_view.dart';
import 'package:flutter_app/ui/components/sheet/tat_bottom_sheet.dart';
import 'package:flutter_app/ui/other/tat_dialog.dart';
import 'package:flutter_app/ui/components/tat_progress.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/components/toast/tat_toast.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:flutter_app/ui/pages/mail/components/mail_folder_sheet.dart';
import 'package:flutter_app/ui/pages/mail/components/mail_groups.dart';
import 'package:flutter_app/ui/pages/mail/components/mail_outbox_tile.dart';
import 'package:flutter_app/ui/pages/mail/components/mail_swipe_action.dart';
import 'package:flutter_app/ui/pages/mail/components/mail_tile.dart';
import 'package:flutter_app/ui/pages/mail/mail_compose_page.dart';
import 'package:flutter_app/ui/pages/mail/mail_detail_page.dart';
import 'package:flutter_app/ui/routes/route_utils.dart';
import 'package:get/get.dart';
import 'package:sprintf/sprintf.dart';

/// 信件列表。
///
/// 沒有 `IDLE` 就沒有推播，所以更新只有兩個時機：進頁面與下拉。不要試著開
/// 長連線等新信，見 docs/WEBMAIL_IMAP.md §5。
///
/// **標題是資料夾名，底下不印未讀數。** 那個數字（收件匣有兩千多）不對應任何
/// 動作——沒有人會把它讀完，而且同一頁的三個地方各算各的，彼此對不起來。總數
/// 只留在資料夾選單那一個地方。
///
/// **搜尋整條取代頂部列**，不是插在它下面。搜尋中資料夾鈕與未讀數都不能用也
/// 不該用，留著只是把清單往下推，第一列變成上一列被切掉的下半截。
class MailListPage extends StatefulWidget {
  const MailListPage({super.key});

  @override
  State<StatefulWidget> createState() => _MailListPageState();
}

class _MailListPageState extends State<MailListPage> {
  final _controller = MailController();
  final _searchController = TextEditingController();
  bool _searchMode = false;

  /// FAB 加上底部導覽列會蓋掉最後一列的主旨。
  static const double _listBottomPadding = 96;

  /// 同一組滑動選單。開一列就把其他列收起來。
  static const String _slidableGroup = 'mail-list';

  /// 滑動選單露出多寬（佔整列的比例）。
  ///
  /// 一格放一顆 44 的圓鈕加底下兩個字。411 寬的手機扣掉左右 16 之後整列是
  /// 379，所以一格抓 70 上下：三顆 0.56、一顆 0.19。先前是 0.72／0.26，一格
  /// 有九十幾，圓鈕之間空了五十幾 px，看起來是散開的三個點而不是一組。
  static const double _swipeExtentOne = 0.19;
  static const double _swipeExtentTwo = 0.56;

  /// 要拉過露出寬度的幾成才算「決定打開」。
  ///
  /// 預設是一半。拉到 0.62 之後手指要多走一段才會吸附過去，放開前那一段有東西
  /// 在抵著——那就是「穩重」的來源。套件把放開之後的回彈寫死成 200ms 的
  /// `Curves.ease`（`action_pane.dart` 的 `openCurrentActionPane`），公開 API
  /// 動不到，所以手感只能從門檻和視覺這兩邊給。
  ///
  /// **一定要乘上那一排自己的 `extentRatio`。** `ActionPane.openThreshold` 比
  /// 的是「拉開的距離佔整列的比例」，不是佔那一排的比例；直接填 0.62 的話，
  /// 露出寬度只有 0.26 的左邊那一排永遠到不了門檻（`normalizeRatio` 把位置夾
  /// 在 0.26 以內），甩也甩不開——放開就彈回去，完全固定不住。
  static const double _swipeOpenFraction = 0.62;

  /// 距離底部多近就先去抓下一頁。
  ///
  /// 每一頁要一次連線加一次 `SEARCH ALL`，所以這個數字要小：400 大約是最後
  /// 五列，使用者已經在往底部去了才會觸發，不是隨手甩一下就預抓。
  static const double _autoLoadExtent = 400;

  StreamSubscription<List<MailMessageJson>>? _arrivals;

  @override
  void initState() {
    super.initState();
    // 清除鍵只在有字的時候畫，所以每一個字都要重畫一次——少了這一行，那顆
    // ✕ 要等到別的東西觸發重畫才會出現。
    _searchController.addListener(_onKeywordChanged);
    // 橫幅跳出來、清單卻還是舊的會很怪。搜尋中不重抓：那會把結果換成收件匣。
    _arrivals = MailWatchController.instance.arrivals.listen((_) {
      if (mounted && !_controller.isSearching) unawaited(_controller.load());
    });
    unawaited(_start());
  }

  void _onKeywordChanged() => setState(() {});

  @override
  void dispose() {
    unawaited(_arrivals?.cancel());
    _controller.dispose();
    _searchController.removeListener(_onKeywordChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    await _controller.load();
    unawaited(_controller.loadFolders());
  }

  Future<void> _openMessage(MailMessageJson message) async {
    unawaited(_controller.markSeen(message.uid));
    final changed = await Get.to<bool>(
      () => MailDetailPage(
        message: message,
        folderPath: _controller.folderPath.value,
      ),
      transition: RouteUtils.transition,
    );
    // 內頁封存或刪除之後那一列就不該還在，重抓比就地猜省事也不會出錯。
    if (changed == true && mounted) await _controller.load();
  }

  Future<void> _delete(MailMessageJson message) async {
    final ok = await _controller.moveToTrash(message.uid);
    if (!mounted) return;
    _toast(ok ? R.current.mailMovedToTrash : R.current.mailActionFailed,
        error: !ok);
  }

  /// **不要換回 `Get.snackbar`。** GetX 的 `Get.back()` 看到有 snackbar 開著
  /// 就只關 snackbar 然後 return——「先提示再離開」那一段會變成頁面關不掉。
  void _toast(String message, {bool error = false}) => TatToast.show(message,
      kind: error ? TatToastKind.error : TatToastKind.info);

  Future<void> _compose() async {
    await Get.to(() => const MailComposePage(),
        transition: RouteUtils.transition);
    // 寄出去的信會被 APPEND 進寄件備份匣，正在看那個資料夾時不重抓就看不到。
    if (mounted) await _controller.load();
  }

  Future<void> _pickFolder() async {
    final folders = _controller.folders.value?.dataOrNull;
    if (folders == null || folders.isEmpty) {
      _toast(R.current.mailActionFailed, error: true);
      return;
    }
    final picked = await showMailFolderSheet(
      context: context,
      folders: folders,
      selected: _controller.folderPath.value,
    );
    if (picked != null) await _controller.openFolder(picked);
  }

  /// 目前資料夾的顯示名稱。還沒問到資料夾清單時退回「收件匣」——那是預設打開
  /// 的那一個，也是唯一保證存在的。
  String _folderTitle() {
    final path = _controller.folderPath.value;
    final folders = _controller.folders.value?.dataOrNull;
    if (folders != null) {
      for (final folder in folders) {
        if (folder.path == path) return mailFolderLabel(folder);
      }
    }
    return R.current.mailFolderInbox;
  }

  void _enterSearch() => setState(() => _searchMode = true);

  Future<void> _exitSearch() async {
    setState(() => _searchMode = false);
    _searchController.clear();
    await _controller.setSearchAllFolders(false);
    if (_controller.isSearching) await _controller.searchFor('');
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Obx 要在這裡而不是包住清單：標題、chip 與結果數都讀得到同一批 Rx。
      _controller.messages.value;
      _controller.hasMore.value;
      _controller.loadingMore.value;
      _controller.loadMoreFailed.value;
      // 寄件匣那幾列要跟著倒數每秒重畫，所以這裡也要讀一次。
      MailOutboxController.instance.items.length;
      return Scaffold(
        appBar: _searchMode ? _searchAppBar() : _folderAppBar(),
        floatingActionButton: _searchMode
            ? null
            : FloatingActionButton(
                onPressed: () => unawaited(_compose()),
                tooltip: R.current.mailCompose,
                child: const Icon(LucideIcons.penLine),
              ),
        body: SafeArea(
          bottom: false,
          child: _searchMode ? _searchBody() : _listBody(),
        ),
      );
    });
  }

  PreferredSizeWidget _folderAppBar() => mainAppbar(
        title: _folderTitle(),
        action: [
          IconButton(
            tooltip: R.current.mailFolders,
            icon: const Icon(LucideIcons.folder),
            onPressed: () => unawaited(_pickFolder()),
          ),
          IconButton(
            tooltip: R.current.search,
            icon: const Icon(LucideIcons.search),
            onPressed: _enterSearch,
          ),
        ],
      );

  /// 搜尋列：返回、輸入框、清除。返回鍵離開搜尋而不是離開這一頁——它取代的是
  /// 頂部列，不是整個畫面。
  PreferredSizeWidget _searchAppBar() => AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
          child: Row(
            children: [
              IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const Icon(LucideIcons.chevronLeft, size: 18),
                onPressed: () => unawaited(_exitSearch()),
              ),
              Expanded(
                child: CourseSearchBar(
                  controller: _searchController,
                  hintText: R.current.mailSearchHint,
                  onLeadingTap: () => unawaited(_exitSearch()),
                  onSubmit: (value) => unawaited(_controller.searchFor(value)),
                  trailing: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: MaterialLocalizations.of(context)
                              .deleteButtonTooltip,
                          icon: const Icon(LucideIcons.x, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            unawaited(_controller.searchFor(''));
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _searchBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              TatFilterChip(
                label: _folderTitle(),
                selected: !_controller.searchAllFolders.value,
                onTap: () => unawaited(_controller.setSearchAllFolders(false)),
              ),
              const SizedBox(width: 8),
              TatFilterChip(
                label: R.current.mailSearchScopeAll,
                selected: _controller.searchAllFolders.value,
                onTap: () => unawaited(_controller.setSearchAllFolders(true)),
              ),
            ],
          ),
        ),
        Expanded(
          child: !_controller.isSearching
              ? EmptyState(
                  icon: LucideIconsThin.mail,
                  message: R.current.mailSearchHint,
                )
              : ResultView<List<MailMessageJson>>(
                  state: _controller.messages,
                  onRetry: _controller.load,
                  errorBuilder: (message) => InlineErrorView(
                      message: message, onRetry: _controller.load),
                  builder: _buildResults,
                ),
        ),
      ],
    );
  }

  Widget _buildResults(List<MailMessageJson> messages) {
    final now = DateTime.now();
    final canWiden = !_controller.searchAllFolders.value;
    if (messages.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, _listBottomPadding),
        children: [
          EmptyState(
            icon: LucideIconsThin.mail,
            message: R.current.mailSearchEmpty,
          ),
          if (canWiden) _widenSearchRow(),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, _listBottomPadding),
      children: [
        SectionHeader(
          title: sprintf(R.current.mailSearchResultCount, [messages.length]),
          first: true,
        ),
        for (var i = 0; i < messages.length; i++) ...[
          if (i > 0) const SizedBox(height: 2),
          MailTile(
            key: ValueKey('mail-hit-${messages[i].uid}'),
            message: messages[i],
            now: now,
            index: i,
            length: messages.length,
            highlight: _controller.keyword.value,
            onTap: () => unawaited(_openMessage(messages[i])),
          ),
        ],
        if (canWiden) _widenSearchRow(),
      ],
    );
  }

  /// 「在全部資料夾再找一次」。收件匣有四千多封，找不到的時候使用者分不出是
  /// 「這個資料夾沒有」還是「整個信箱都沒有」——這一列把第二條路留著。
  Widget _widenSearchRow() => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => unawaited(_controller.setSearchAllFolders(true)),
            child: Text(R.current.mailSearchAllFolders),
          ),
        ),
      );

  Widget _listBody() => ResultView<List<MailMessageJson>>(
        state: _controller.messages,
        onRetry: _controller.load,
        errorBuilder: (message) =>
            InlineErrorView(message: message, onRetry: _controller.load),
        builder: _buildList,
      );

  Widget _buildList(List<MailMessageJson> messages) {
    if (messages.isEmpty) {
      final outbox = _outboxSection();
      // 空信箱也要看得到寄件匣：不然剛寄出第一封信的人會以為信不見了。
      if (outbox.isEmpty) {
        return EmptyState(
          icon: LucideIconsThin.mail,
          message: R.current.mailEmpty,
        );
      }
      return RefreshIndicator(
        onRefresh: _controller.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, _listBottomPadding),
          children: outbox,
        ),
      );
    }
    // 整份清單共用同一個「現在」，時間欄與分組才是同一個時間點。
    final now = DateTime.now();
    final groups = MailGroups.groupByAge(messages, now);
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _onScrollMetrics,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: RefreshIndicator(
          onRefresh: _controller.load,
          // 開一列就把別列收起來，捲動時也收。
          child: SlidableAutoCloseBehavior(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, _listBottomPadding),
              children: [
                ..._outboxSection(),
                for (var g = 0; g < groups.length; g++) ...[
                  SectionHeader(
                    title: MailGroups.labelOf(groups[g].bucket),
                    first: g == 0,
                  ),
                  for (var i = 0; i < groups[g].items.length; i++) ...[
                    if (i > 0) const SizedBox(height: 2),
                    _swipeRow(
                        groups[g].items[i], i, groups[g].items.length, now),
                  ],
                ],
                _loadMoreRow(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 捲到接近底部就自己載下一頁。
  ///
  /// **用通知而不是 `ScrollController`**：這一頁在搜尋／空清單／有信三個分支
  /// 各有一個 `ListView`，Obx 重畫時換一個，同一顆 controller 會在那一瞬間
  /// 同時掛在兩個 Scrollable 上而拋錯。`RefreshIndicator` 的處理器一律回
  /// false，通知照樣往上冒，所以包在它外面收得到。
  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false; // 列裡面自己會捲的東西不算。
    if (n.metrics.axis != Axis.vertical) return false;
    if (n.metrics.extentAfter >= _autoLoadExtent) return false;
    _autoLoad();
    return false; // 別人也還要看這一則。
  }

  /// 內容撐不滿一個畫面時不會有捲動事件——那種資料夾要靠 metrics 通知補一次，
  /// 不然清單會停在只有一頁的狀態，使用者也沒有東西可以按。
  bool _onScrollMetrics(ScrollMetricsNotification n) {
    if (n.depth != 0) return false;
    if (n.metrics.axis != Axis.vertical) return false;
    if (n.metrics.maxScrollExtent > 0) return false; // 捲得動，交給 _onScroll。
    _autoLoad();
    return false;
  }

  /// **失敗過就停手。** 失敗時 `hasMore` 不動、`loadingMore` 也回到 false，
  /// 不閂的話同一次拖曳裡的幾十個捲動事件會一路重連。閂上之後只有使用者自己
  /// 按底下那一列才會再試。
  void _autoLoad() {
    if (_controller.loadMoreFailed.value) return;
    if (_controller.loadingMore.value || !_controller.hasMore.value) return;
    if (_controller.isSearching) return;
    unawaited(_controller.loadMore());
  }

  /// 寄件匣。**只在有東西的時候出現**——永遠佔一個標題列的話，99% 的時間
  /// 它在講「沒有信在寄」，那是噪音。
  ///
  /// 放在清單最上面而不是做成一個要切過去的資料夾：使用者按下寄出之後眼睛
  /// 還在這一頁，收回鈕要在他看得到的地方。
  List<Widget> _outboxSection() {
    final outbox = MailOutboxController.instance;
    final items = outbox.items;
    if (items.isEmpty) return const [];
    return [
      SectionHeader(title: R.current.mailOutbox, first: true),
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) const SizedBox(height: 2),
        MailOutboxTile(
          key: ValueKey('mail-outbox-${items[i].id}'),
          item: items[i],
          remainingSeconds: outbox.remainingSeconds(items[i]),
          index: i,
          length: items.length,
          onRecall: () => unawaited(_recall(items[i])),
          onRetry: () => unawaited(outbox.retry(items[i].id)),
          onDiscard: () => unawaited(_discardQueued(items[i])),
        ),
      ],
    ];
  }

  Future<void> _recall(MailOutboxItem item) async {
    final ok = await MailOutboxController.instance.recall(item.id);
    if (!mounted) return;
    // 收不回來只有一種情況：剛好在按下去的那一瞬間交給 SMTP 了。那時候信
    // 可能已經在對方伺服器上，說「已收回」是騙人的。
    _toast(ok ? R.current.mailRecalled : R.current.mailOutboxSending,
        error: !ok);
  }

  /// 失敗的那一封長按刪除。**要問一次**：那是使用者寫好但沒寄出去的信，
  /// 刪掉就沒了。
  Future<void> _discardQueued(MailOutboxItem item) async {
    final subject = item.draft.subject.trim();
    final discard = await showTatDialog<bool>(
      dialog: TatDialog(
        title: R.current.mailDraftDiscard,
        body: subject.isEmpty ? R.current.mailDraftDiscardBody : subject,
        kind: TatDialogKind.warning,
        secondary: TatDialogAction(
          label: R.current.cancel,
          onPressed: () => Get.back<bool>(result: false),
        ),
        primary: TatDialogAction(
          label: R.current.mailDiscard,
          onPressed: () => Get.back<bool>(result: true),
        ),
      ),
    );
    if (discard != true) return;
    await MailOutboxController.instance.recall(item.id);
  }

  /// 清單最底下那一列。
  ///
  /// **捲到底自動載下一頁。** 每一頁要一次連線加一次 `SEARCH ALL`，所以門檻
  /// 壓在最後幾列（[_autoLoadExtent]）而不是預抓，而且失敗就閂住
  /// （`loadMoreFailed`）並把按鈕換回來讓人自己再試一次——不閂的話同一次拖曳
  /// 裡的幾十個捲動事件會一路重連。
  Widget _loadMoreRow() {
    if (!_controller.hasMore.value) {
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Center(
          child: Text(
            R.current.mailNoMore,
            style: context.text.bodySmall
                ?.copyWith(color: context.scheme.onSurfaceVariant),
          ),
        ),
      );
    }
    // 失敗過才給按鈕。正常情況下捲到底就自己載了，不需要人按。
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Center(
        child: _controller.loadMoreFailed.value
            ? TextButton(
                onPressed: () => unawaited(_controller.loadMore()),
                child: Text(R.current.mailLoadMore),
              )
            : const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: TatProgress(size: 20),
              ),
      ),
    );
  }

  /// 一列信 ＋ iOS 信件那種滑動選單。
  ///
  /// **不用 `Dismissible`。** 它內部只有「回原位」與「整列滑掉」兩個落點，
  /// 沒有「停在半路」；`background` 也只是畫在底下的一塊染色底圖，上面放什麼
  /// 都按不到。要的是滑一半停住、露出幾顆按鈕等人按，那是 `ActionPane`。
  ///
  /// **外面那層 `ClipRRect` 不能省。** 按鈕和信件卡是並排在同一個橫列裡的，
  /// 圓角若只靠 [MailTile] 自己那層 `Material`，露出來的按鈕會是直角，2px
  /// 節奏排出來的圓角就斷在滑開的那一刻。這裡用同一組
  /// [UIUtils.getBorderRadius] 把整列剪成同一個形狀。
  Widget _swipeRow(
      MailMessageJson message, int index, int length, DateTime now) {
    final scheme = context.scheme;
    final tokens = context.tokens;
    // **外層不要 `ClipRRect`。** 信件卡與每一顆按鈕各自有自己的 Material 與
    // 圓角；外面再剪一次會把按鈕朝外那一側的圓角削平，間隙也一起被吃掉。
    return Slidable(
      key: ValueKey('mail-${message.uid}'),
      // 同一個 tag 才會「開一列就把別列收起來」，和 iOS 信件一樣。
      groupTag: _slidableGroup,
      // 右滑露出左側：標記已讀／未讀。安全又可逆，所以只有一顆。
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: _swipeExtentOne,
        openThreshold: _swipeExtentOne * _swipeOpenFraction,
        children: [
          MailSwipeAction(
            onPressed: () => unawaited(_toggleSeen(message)),
            background: tokens.info,
            foreground: tokens.onInfo,
            icon: message.seen ? LucideIcons.mail : LucideIcons.mailOpen,
            // **只寫兩個字。** 圓鈕底下那一行的寬度大約就是一顆圓鈕，
            // 「標記為已讀」在那裡會被截成「標記為…」，等於什麼都沒說。
            label: message.seen
                ? R.current.mailUnseenShort
                : R.current.mailSeenShort,
            extentRatio: _swipeExtentOne,
          ),
        ],
      ),
      // 左滑露出右側：更多、封存、刪除。
      //
      // **「更多」排在最靠近信件卡那一側。** 它是最常用也最安全的一顆（後面
      // 接的是長按那張選單），而破壞性最強的刪除放在最外側，手指要走最遠。
      //
      // **刪除不跳確認框。** 這個 App 的「刪除」是搬到回收筒，救得回來；為一個
      // 可逆的動作攔一次對話框，等於每次都要按兩下。真正不可逆的是回收筒裡的
      // 那一次，那一層另外處理。
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: _swipeExtentTwo,
        openThreshold: _swipeExtentTwo * _swipeOpenFraction,
        children: [
          MailSwipeAction(
            onPressed: () => unawaited(_showActions(message)),
            background: context.scheme.onSurfaceVariant,
            foreground: context.scheme.surface,
            icon: LucideIcons.ellipsis,
            label: R.current.titleMore,
            extentRatio: _swipeExtentTwo,
          ),
          MailSwipeAction(
            onPressed: () => unawaited(_archive(message)),
            background: scheme.primary,
            foreground: scheme.onPrimary,
            icon: LucideIcons.archive,
            label: R.current.mailFolderArchive,
            extentRatio: _swipeExtentTwo,
          ),
          MailSwipeAction(
            onPressed: () => unawaited(_delete(message)),
            background: scheme.error,
            foreground: scheme.onError,
            icon: LucideIcons.trash2,
            label: R.current.delete,
            extentRatio: _swipeExtentTwo,
          ),
        ],
      ),
      child: _SwipeRowCard(
        message: message,
        now: now,
        index: index,
        length: length,
        onTap: () => unawaited(_openMessage(message)),
        onLongPress: () => unawaited(_showActions(message)),
      ),
    );
  }

  /// 標記已讀／未讀，滑動選單與長按選單共用。
  Future<void> _toggleSeen(MailMessageJson message) async {
    final ok = await _controller.setSeen(message.uid, seen: !message.seen);
    if (!mounted) return;
    _toast(
        ok
            ? (message.seen
                ? R.current.mailMarkedUnread
                : R.current.mailMarkRead)
            : R.current.mailActionFailed,
        error: !ok);
  }

  Future<bool> _confirmDelete(MailMessageJson message) async {
    final ok = await showTatDialog<bool>(
      dialog: TatDialog(
        title: R.current.mailMovedToTrash,
        body: message.subject.trim().isEmpty
            ? R.current.mailNoSubject
            : message.subject.trim(),
        kind: TatDialogKind.warning,
        secondary: TatDialogAction(
          label: R.current.cancel,
          onPressed: () => Get.back<bool>(result: false),
        ),
        primary: TatDialogAction(
          label: R.current.delete,
          onPressed: () => Get.back<bool>(result: true),
        ),
      ),
    );
    return ok ?? false;
  }

  Future<void> _archive(MailMessageJson message) async {
    final ok = await _controller.moveToArchive(message.uid);
    if (!mounted) return;
    _toast(ok ? R.current.mailArchived : R.current.mailActionFailed,
        error: !ok);
  }

  /// 長按一列跳出來的動作選單：標記未讀／已讀、移到資料夾、封存、刪除。
  Future<void> _showActions(MailMessageJson message) async {
    final action = await showTatActionSheet<String>(
      context: context,
      items: [
        TatSheetItem(
          icon: message.seen ? LucideIcons.mail : LucideIcons.mailOpen,
          label:
              message.seen ? R.current.mailMarkUnread : R.current.mailMarkRead,
          value: 'seen',
        ),
        TatSheetItem(
          icon: LucideIcons.folder,
          label: R.current.mailMoveToFolder,
          value: 'move',
        ),
        TatSheetItem(
          icon: LucideIcons.archive,
          label: R.current.mailFolderArchive,
          value: 'archive',
        ),
        TatSheetItem(
          icon: LucideIcons.trash2,
          label: R.current.delete,
          value: 'delete',
          destructive: true,
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'seen':
        await _toggleSeen(message);
      case 'move':
        await _moveToFolder(message);
      case 'archive':
        await _archive(message);
      case 'delete':
        if (await _confirmDelete(message)) await _delete(message);
    }
  }

  Future<void> _moveToFolder(MailMessageJson message) async {
    final folders = _controller.folders.value?.dataOrNull;
    if (folders == null || folders.isEmpty) {
      _toast(R.current.mailActionFailed, error: true);
      return;
    }
    final picked = await showMailFolderSheet(
      context: context,
      folders: folders,
      selected: _controller.folderPath.value,
      title: R.current.mailMoveToFolder,
    );
    if (!mounted || picked == null) return;
    if (picked == _controller.folderPath.value) return; // 就在這裡，不用搬。
    final ok = await _controller.moveToFolder(message.uid, picked);
    if (!mounted) return;
    _toast(ok ? R.current.mailMoved : R.current.mailActionFailed, error: !ok);
  }
}

/// 滑動選單裡的那張信件卡。
///
/// **圓角要跟著滑開的進度長。** 清單靜止時每一列照 [UIUtils.getBorderRadius]
/// 的節奏（頭尾 14、中間 4），那是「這幾列是同一群」的訊號；但拉開之後旁邊站
/// 的是自己有 12 圓角的按鈕，信件卡若還停在 4，接縫看起來像兩個不同系統的東
/// 西拼在一起。所以朝著按鈕那一側的兩個角，隨著 `Slidable` 的動畫從節奏值補
/// 到和按鈕一樣圓。
///
/// 只動朝著按鈕的那一側：另一側仍然屬於清單的節奏，一起變圓會讓整群散掉。
class _SwipeRowCard extends StatelessWidget {
  const _SwipeRowCard({
    required this.message,
    required this.now,
    required this.index,
    required this.length,
    required this.onTap,
    required this.onLongPress,
  });

  final MailMessageJson message;
  final DateTime now;
  final int index;
  final int length;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final resting = UIUtils.getBorderRadius(index, length) ?? BorderRadius.zero;
    final controller = Slidable.of(context);
    // **`child` 要放在 builder 外面。** 放進去的話每一個拖曳影格都會把整張
    // MailTile（含兩段文字排版）重建一次，手指拖起來會頓，那正是「感覺不跟手」
    // 的另一半。圓角交給外面那層 ClipRRect，信件卡本身只建一次。
    final tile = MailTile(
      message: message,
      now: now,
      index: index,
      length: length,
      borderRadius: BorderRadius.zero,
      onTap: onTap,
      onLongPress: onLongPress,
    );
    if (controller == null) {
      return ClipRRect(borderRadius: resting, child: tile);
    }
    return AnimatedBuilder(
      animation: controller.animation,
      child: tile,
      builder: (context, child) => ClipRRect(
        borderRadius: mailSwipeCardRadius(
          resting,
          controller.ratio,
          // 兩排按鈕露出的寬度不一樣，進度要各自除以自己那一邊的。
          controller.ratio > 0
              ? _MailListPageState._swipeExtentOne
              : _MailListPageState._swipeExtentTwo,
        ),
        child: child,
      ),
    );
  }
}
