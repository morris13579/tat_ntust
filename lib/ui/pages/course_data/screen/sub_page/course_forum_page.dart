import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/controller/course_data/course_forum_controller.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:flutter_app/ui/components/card/section_card.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/page/empty_state.dart';
import 'package:flutter_app/ui/components/page/result_view.dart';
import 'package:flutter_app/ui/components/page/web_view_opener.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_forum_thread_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/forum_discussion_card.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/forum_month_groups.dart';
import 'package:get/get.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';

/// 一個討論區的主題清單。錯誤畫面與 WebView 開啟器由呼叫端注入，
/// 見 docs/ARCHITECTURE.md「UI 慣例」。
class CourseForumPage extends StatefulWidget {
  const CourseForumPage(
    this.courseInfo, {
    required this.forumId,
    required this.forumName,
    required this.forumUrl,
    required this.errorBuilder,
    required this.openWebView,
    super.key,
  });

  final CourseInfoJson courseInfo;

  /// forum instance id（`Modules.instance`），三支 ws function 要的都是它。
  final int forumId;

  final String forumName;

  /// 課程目錄那一列自己帶的網址，用來「在網頁開啟」。
  final String forumUrl;

  final Widget Function(String message) errorBuilder;
  final WebViewOpener openWebView;

  @override
  State<StatefulWidget> createState() => _CourseForumPageState();
}

class _CourseForumPageState extends State<CourseForumPage> {
  late final CourseForumController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CourseForumController(forumId: widget.forumId);
    unawaited(_controller.loadDiscussions());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: baseAppbar(
        title: widget.forumName,
        action: [
          IconButton(
            tooltip: R.current.forumOpenInWeb,
            icon: const Icon(LucideIcons.externalLink, size: 18),
            onPressed: () =>
                unawaited(widget.openWebView(widget.forumName, _forumUrl())),
          ),
        ],
      ),
      body: ResultView<List<Discussions>>(
        state: _controller.discussions,
        onRetry: _controller.loadDiscussions,
        errorBuilder: widget.errorBuilder,
        builder: _list,
      ),
    );
  }

  /// 課程目錄那一列帶的網址加上語系。不呼叫 `autologinUrl`：注入的
  /// [CourseForumPage.openWebView] 自己會換。
  String _forumUrl() => Connector.uriAddQuery(
        widget.forumUrl,
        {"lang": LanguageUtils.getLangIndex() == LangEnum.zh ? "zh_tw" : "en"},
      );

  Widget _list(List<Discussions> discussions) {
    if (discussions.isEmpty) {
      return EmptyState(
          icon: LucideIconsThin.messagesSquare, message: R.current.forumEmpty);
    }
    final entries = groupDiscussionsByMonth([
      for (final d in discussions)
        ForumFeedItem.discussion(d, forumId: widget.forumId),
    ]);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        if (entry.isHeader) {
          return SectionHeader(title: entry.label, first: index == 0);
        }
        final d = entry.discussion;
        return Padding(
          padding: EdgeInsets.only(top: entry.indexInGroup == 0 ? 0 : 2),
          child: ForumDiscussionCard(
            discussion: d,
            index: entry.indexInGroup,
            length: entry.groupLength,
            onTap: () => unawaited(_openThread(d)),
          ),
        );
      },
    );
  }

  /// 主文被刪掉、或第一篇被編輯過時清單那一列就過期了（標題、迴紋針、
  /// 回覆數），討論串頁會回頭喊一聲，這裡負責重抓。
  void _refreshDiscussions() {
    if (!mounted) return;
    unawaited(_controller.loadDiscussions(keepVisible: true));
  }

  Future<void> _openThread(Discussions d) async {
    await Get.to<void>(() => CourseForumThreadPage(
          widget.courseInfo,
          // discussion 才是討論串 id；id 是第一篇貼文的 id。
          discussionId: d.discussion,
          title: d.name,
          forumId: widget.forumId,
          fallbackDiscussion: d,
          onDiscussionChanged: _refreshDiscussions,
          openWebView: widget.openWebView,
        ));
  }
}
