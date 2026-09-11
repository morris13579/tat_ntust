import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/controller/course_data/course_data_controller.dart';
import 'package:flutter_app/src/controller/course_data/course_forum_controller.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/ui/components/card/section_card.dart';
import 'package:flutter_app/ui/components/chip/tat_filter_chip.dart';
import 'package:flutter_app/ui/components/page/empty_state.dart';
import 'package:flutter_app/ui/components/page/result_view.dart';
import 'package:flutter_app/ui/components/page/web_view_opener.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_forum_thread_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/forum_discussion_card.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/forum_month_groups.dart';
import 'package:get/get.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:sprintf/sprintf.dart';

/// 課程頁的「公告」分頁。錯誤畫面與 WebView 開啟器由呼叫端注入，
/// 見 docs/ARCHITECTURE.md「UI 慣例」。
///
/// 有課程討論區的課，這一頁會把討論區的主題與公告**併成同一條時間軸**
/// （設計稿 7g）：兩者都是 `mod_forum` 的討論串，只差在誰能發文，分成兩個
/// 入口只會讓人以為公告頁沒有新東西。沒有討論區的課就是純公告（7e）——
/// 少的只是 filter chip 與回覆數，列型完全一樣。
class CourseAnnouncementPage extends StatefulWidget {
  const CourseAnnouncementPage(
    this.courseInfo, {
    required this.controller,
    required this.errorBuilder,
    required this.openWebView,
    super.key,
  });

  final CourseInfoJson courseInfo;

  /// 四個分頁共用的狀態；請求在進入頁面時已一次發完。
  final CourseDataController controller;

  final Widget Function(String message) errorBuilder;
  final WebViewOpener openWebView;

  @override
  State<StatefulWidget> createState() => _CourseAnnouncementPageState();
}

class _CourseAnnouncementPageState extends State<CourseAnnouncementPage>
    with AutomaticKeepAliveClientMixin {
  Rxn<Result<MoodleModForumGetForumDiscussions>> get _state =>
      widget.controller.announcements;

  /// 公告區以外的討論區。課程目錄回來之後才知道有沒有，所以是後補的。
  final _forums = <_MergedForum>[];

  /// null ＝「全部」。
  ForumFeedKind? _filter;

  // 沒有 initState 觸發請求，見 CourseDataController.loadAll。

  @override
  void dispose() {
    for (final f in _forums) {
      f.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() => widget.controller.loadAnnouncements();

  /// 課程目錄裡的討論區，扣掉公告區本身。
  ///
  /// 只認第一次算出來的那一組：目錄重抓時 id 不會變，重建 controller 只會
  /// 讓已經畫出來的主題閃一次。
  ///
  /// 從 `build` 裡叫（外面那層 [Obx] 已經在追課程目錄），所以這裡不 setState、
  /// 也不當場發請求——**不用 `ever` 是刻意的**：那個 worker 綁在共用
  /// controller 的 Rx 上，而共用 controller 常常比這一頁先被 dispose，
  /// 那時 `Worker.dispose` 會在一條已經關掉的 stream 上炸開。
  void _syncForums() {
    // 兩個 `.value` 都要無條件讀到：外面那層 Obx 是靠這兩行訂閱的，提早
    // return 會讓它一個 observable 都沒追到，GetX 會直接當成誤用丟出來。
    final contents = widget.controller.directory.value?.dataOrNull;
    // 公告與課程目錄是平行發出去的，誰先到都有可能；公告還沒到（forumId 是
    // 0）時只剩名稱這條線索。
    final announcementForumId = _state.value?.dataOrNull?.forumId ?? 0;
    if (_forums.isNotEmpty || contents == null) return;
    final found = <_MergedForum>[];
    final seen = <int>{};
    for (final section in contents) {
      for (final m in section.modules) {
        if (m.modname != _forumModName || m.instance <= 0) continue;
        // 公告區不併進來——它已經是這一頁的主體。id 是 0 的舊快取還有名稱
        // 這條退路（connector 找公告區時用的是同一組線索）。
        if (m.instance == announcementForumId) continue;
        if (announcementForumId == 0 &&
            MoodleWebApiConnector.looksLikeAnnouncementName(m.name)) {
          continue;
        }
        if (!seen.add(m.instance)) continue;
        found.add(_MergedForum(m));
      }
    }
    if (found.isEmpty) return;
    _forums.addAll(found);
    // 請求排到這一幀之後：在 build 中途寫 Rx 會撞到正在進行的重建。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final f in found) {
        unawaited(f.controller.loadDiscussions());
      }
    });
  }

  static const String _forumModName = 'forum';

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // 這一層 Obx 追的是課程目錄：有沒有課程討論區要從它算出來。
    return Obx(() {
      _syncForums();
      return ResultView<MoodleModForumGetForumDiscussions>(
        state: _state,
        onRetry: _load,
        errorBuilder: widget.errorBuilder,
        builder: buildTree,
      );
    });
  }

  /// 沒有討論區時不包 [Obx]：那時候沒有任何可追的 observable，而空的 Obx
  /// 會被 GetX 當成誤用直接丟。
  Widget buildTree(MoodleModForumGetForumDiscussions data) => _forums.isEmpty
      ? _body(data)
      // 各討論區的清單比公告晚到，到了才把列補上去。
      : Obx(() => _body(data));

  Widget _body(MoodleModForumGetForumDiscussions data) {
    final feed = _feed(data);
    if (feed.isEmpty) {
      return _empty(data.forumFound
          ? R.current.announcementEmpty
          : R.current.announcementNoForum);
    }
    final discussions =
        feed.where((i) => i.kind == ForumFeedKind.discussion).length;
    final announcements = feed.length - discussions;
    final visible = _filter == null
        ? feed
        : [
            for (final i in feed)
              if (i.kind == _filter) i
          ];
    return Column(
      // 少了 stretch，Column 會把 chip 那一列縮到內容寬再置中，看起來就是
      // 「chip 沒有靠左」。
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 兩種都真的有列時才給 chip：數字是 0 的那一顆點下去只會清空畫面，
        // 那不是篩選，是死路。
        if (discussions > 0 && announcements > 0)
          _filters(
            announcements: announcements,
            discussions: discussions,
          ),
        Expanded(child: _list(visible)),
      ],
    );
  }

  /// 公告與各討論區併成一條時間軸。
  ///
  /// 依 `discussion` 去重：公告區的 forum id 在舊快取裡是 0，名稱又可能被
  /// 站台改過，兩條線索都沒認出來時同一則會從兩邊各進來一次。
  List<ForumFeedItem> _feed(MoodleModForumGetForumDiscussions data) {
    final announcements = [
      for (final d in data.discussions)
        ForumFeedItem.announcement(d, forumId: data.forumId),
    ];
    final sources = [
      announcements,
      for (final f in _forums)
        [
          for (final d
              in f.controller.discussions.value?.dataOrNull ?? const [])
            ForumFeedItem.discussion(d, forumId: f.id),
        ],
    ];
    final seen = <int>{};
    return [
      for (final item in mergeForumFeed(sources))
        if (seen.add(item.discussion.discussion)) item,
    ];
  }

  /// M3 的 filter chip。數字必須等於清單實際的列數，所以兩個數都從同一份
  /// feed 算出來，不是各問各的來源。
  Widget _filters({required int announcements, required int discussions}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          TatFilterChip(
            label: R.current.forumFilterAll,
            selected: _filter == null,
            onTap: () => setState(() => _filter = null),
          ),
          TatFilterChip(
            label: sprintf(
                R.current.forumFilterAnnouncements, [announcements.toString()]),
            selected: _filter == ForumFeedKind.announcement,
            onTap: () => setState(() => _filter = ForumFeedKind.announcement),
          ),
          TatFilterChip(
            label: sprintf(
                R.current.forumFilterDiscussions, [discussions.toString()]),
            selected: _filter == ForumFeedKind.discussion,
            onTap: () => setState(() => _filter = ForumFeedKind.discussion),
          ),
        ],
      ),
    );
  }

  Widget _list(List<ForumFeedItem> feed) {
    final entries = groupDiscussionsByMonth(feed);
    return ListView.builder(
      // 底部讓開手勢區：這一頁不在任何 SafeArea 裡。
      padding: EdgeInsets.fromLTRB(
          12, 12, 12, MediaQuery.paddingOf(context).bottom + 32),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        if (entry.isHeader) {
          return SectionHeader(title: entry.label, first: index == 0);
        }
        final item = entry.item!;
        return Padding(
          padding: EdgeInsets.only(top: entry.indexInGroup == 0 ? 0 : 2),
          child: ForumDiscussionCard(
            discussion: item.discussion,
            // 純公告頁沒有回覆數：那一頁的每一列都是單向的公告。
            showReplies: item.kind == ForumFeedKind.discussion,
            index: entry.indexInGroup,
            length: entry.groupLength,
            onTap: () => unawaited(_openThread(item)),
          ),
        );
      },
    );
  }

  Future<void> _openThread(ForumFeedItem item) async {
    final isAnnouncement = item.kind == ForumFeedKind.announcement;
    await Get.to<void>(() => CourseForumThreadPage(
          widget.courseInfo,
          // discussion 才是討論串 id；id 是第一篇貼文的 id。
          discussionId: item.discussion.discussion,
          title: item.discussion.name,
          // 合成欄位，由 connector 填；舊快取是 0，那時附件入口收起來。
          forumId: item.forumId,
          fallbackDiscussion: item.discussion,
          // 公告區對學生是唯讀的（`replynews` 只給老師），網頁版也一樣，
          // 所以那裡不該掛一條「去網頁回覆」的列。課程討論區不受影響。
          readOnly: isAnnouncement,
          // 主文被刪掉或被編輯過時這一頁的清單就過期了。少了這一行，被刪掉
          // 的那一列會留在畫面上，點進去還會把剛刪掉的貼文再畫一次。
          onDiscussionChanged: () => _refresh(item),
          openWebView: widget.openWebView,
        ));
  }

  void _refresh(ForumFeedItem item) {
    if (!mounted) return;
    if (item.kind == ForumFeedKind.announcement) {
      unawaited(_load());
      return;
    }
    for (final f in _forums) {
      if (f.id == item.forumId) {
        unawaited(f.controller.loadDiscussions(keepVisible: true));
      }
    }
  }

  Widget _empty(String message) =>
      EmptyState(icon: LucideIconsThin.messageSquare, message: message);

  @override
  bool get wantKeepAlive => true;
}

/// 併進公告頁的一個課程討論區。
class _MergedForum {
  _MergedForum(Modules module)
      : id = module.instance,
        controller = CourseForumController(forumId: module.instance);

  final int id;
  final CourseForumController controller;
}
