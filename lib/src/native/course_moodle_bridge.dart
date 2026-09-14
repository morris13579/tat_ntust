import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions.dart';
import 'package:flutter_app/src/native/bridge_results.dart';
import 'package:flutter_app/src/native/moodle_memo.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/util/course_section_tree.dart';
import 'package:flutter_app/src/util/file_icon_utils.dart';
import 'package:flutter_app/src/util/forum_feed_utils.dart';
import 'package:flutter_app/src/util/html_image_sources.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:flutter_app/src/util/moodle_assign_text.dart';
import 'package:flutter_app/src/util/moodle_assign_utils.dart';
import 'package:flutter_app/src/util/moodle_folder_utils.dart';
import 'package:flutter_app/src/util/moodle_pluginfile_utils.dart';
import 'package:flutter_app/src/util/web_view_url_policy.dart';
import 'package:sprintf/sprintf.dart';

/// 原生版一門課的 Moodle。分頁怎麼分組、怎麼排、每一列寫什麼，照
/// `course_directory_page.dart`、`course_announcement_page.dart` 與
/// `course_assignment_page.dart`；點下去做什麼照 `CourseModuleActions`。
///
/// 抓回來的東西留在這裡：搜尋、篩選與資料夾都從同一份算，不再打網路。
class CourseMoodleBridge implements TatCourseMoodleApi {
  CourseMoodleBridge(this._memo, {DateTime Function()? now})
      : _now = now ?? MoodleWebApiConnector.serverNow;

  static void install(MoodleMemo memo) =>
      TatCourseMoodleApi.setUp(CourseMoodleBridge(memo));

  final MoodleMemo _memo;
  final DateTime Function() _now;

  /// 檔案與公告兩個分頁同時進場，公告要從同一份課程目錄找討論區：共用同一趟請求。
  final Map<String, Future<Result<List<MoodleCoreCourseGetContents>>>>
      _inflight = {};
  final Map<String, List<MoodleCoreCourseGetContents>> _contents = {};
  final Map<String, ({List<ForumFeedItem> items, bool forumFound})> _feeds =
      {};

  @override
  Future<CourseDirectory> directory(String courseId) async {
    final result = await _loadDirectory(courseId);
    final data = result.dataOrNull;
    final tree = CourseSectionTree.of(data ?? const [], now: _now());
    final current = tree.currentWeek;
    return CourseDirectory(
      weekly: tree.weekly,
      stats: tree.weekly
          ? sprintf(R.current.fileStatsWeekly,
              [tree.totalFiles, tree.sectionsWithContent])
          : sprintf(
              R.current.fileStatsTopic, [tree.totalFiles, tree.nonEmpty.length]),
      currentWeek: current == null ? null : _section(current, current.modules),
      sections: [
        for (final s in tree.weekly ? tree.otherWithContent : tree.nonEmpty)
          _section(s, s.modules),
      ],
      emptySections: [
        if (tree.weekly)
          for (final s in tree.empty) _section(s, s.modules),
      ],
      error: BridgeResults.errorOf(result),
      notice: BridgeResults.noticeOf(result),
      signedIn: AuthSession.instance.isSignedIn,
    );
  }

  @override
  List<CourseSectionItem> searchDirectory(String courseId, String query) => [
        for (final (section, modules) in CourseSectionTree.of(
                _contents[courseId] ?? const [],
                now: _now())
            .search(query))
          _section(section, modules),
      ];

  @override
  MoodleFileLink? moduleFile(String courseId, int moduleId) {
    final contents = _module(courseId, moduleId)?.contents ?? const [];
    if (contents.isEmpty) return null;
    final file = contents.first;
    return MoodleFileLink(
      name: file.filename,
      url: MoodleWebApiConnector.fileUrlWithToken(file.fileurl),
    );
  }

  @override
  String? moduleUrl(String courseId, int moduleId) {
    final contents = _module(courseId, moduleId)?.contents ?? const [];
    return contents.isEmpty ? null : contents.first.fileurl;
  }

  @override
  Future<WebLink?> moduleWebLink(String courseId, int moduleId) async {
    final url = _module(courseId, moduleId)?.url ?? '';
    return url.isEmpty ? null : webLinkOf(withLang(url));
  }

  @override
  CourseFolder? folder(String courseId, int moduleId, String path) {
    final module = _module(courseId, moduleId);
    if (module == null) return null;
    final listing = MoodleFolderUtils.listing(module.contents, path: path);
    final segments = MoodleFolderUtils.segments(path);
    return CourseFolder(
      title: segments.isEmpty ? module.name : segments.last,
      breadcrumb: [module.name, ...segments].join(' / '),
      folders: [
        for (final f in listing.folders)
          FolderEntry(
            name: f.name,
            path: f.path,
            subtitle: sprintf(R.current.folderFileCount, [f.fileCount]),
          ),
      ],
      files: [
        for (final c in listing.files)
          MoodleFileRow(
            name: c.filename,
            subtitle: CourseModuleUtils.folderFileSubtitle(c),
            fileIcon:
                FileIconUtils.iconFor(filename: c.filename, mimetype: c.mimetype),
            url: MoodleWebApiConnector.fileUrlWithToken(c.fileurl),
          ),
      ],
    );
  }

  @override
  Future<CoursePage> page(String courseId, int moduleId) async {
    final contents = _module(courseId, moduleId)?.contents ?? const [];
    if (contents.isEmpty) return CoursePage(error: R.current.nothingHere);
    // 相對連結的基準刻意用沒有憑證的原始網址，`?token=` 才不會被帶進教材裡的連結。
    final raw = contents.first.fileurl;
    try {
      final html = await DioConnector.instance.getDataByGet(
          ConnectorParameter(MoodleWebApiConnector.fileUrlWithToken(raw)));
      return CoursePage(html: html, baseUrl: raw);
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return CoursePage(error: R.current.somethingError);
    }
  }

  @override
  Future<CourseFeed> feed(String courseId) async {
    final announcements = MoodleRepository.instance.getAnnouncements(courseId);
    final contents = await _contentsOf(courseId);
    final result = await announcements;
    final data = result.dataOrNull;
    if (data == null) {
      _feeds.remove(courseId);
      return _feedOf(courseId, null,
          error: BridgeResults.errorOf(result),
          notice: BridgeResults.noticeOf(result));
    }
    final forumIds = forumModulesToMerge(
      contents,
      announcementForumId: data.forumId,
      looksLikeAnnouncement: MoodleWebApiConnector.looksLikeAnnouncementName,
    );
    final forums = await Future.wait([
      for (final id in forumIds) MoodleRepository.instance.getForumDiscussions(id),
    ]);
    // 依 discussion 去重：公告區的 id 在舊快取裡是 0，名稱又可能被站台改過，
    // 兩條線索都沒認出來時同一則會從兩邊各進來一次。
    final seen = <int>{};
    final items = [
      for (final item in mergeForumFeed([
        [
          for (final d in data.discussions)
            ForumFeedItem.announcement(d, forumId: data.forumId),
        ],
        for (var i = 0; i < forumIds.length; i++)
          [
            for (final d in forums[i].dataOrNull ?? const <Discussions>[])
              ForumFeedItem.discussion(d, forumId: forumIds[i]),
          ],
      ]))
        if (seen.add(item.discussion.discussion)) item,
    ];
    _feeds[courseId] = (items: items, forumFound: data.forumFound);
    for (final item in items) {
      _memo.discussions[item.discussion.discussion] = item.discussion;
    }
    return _feedOf(courseId, null, notice: BridgeResults.noticeOf(result));
  }

  @override
  CourseFeed filterFeed(String courseId, FeedKind? kind) =>
      _feedOf(courseId, kind);

  @override
  Future<ForumDiscussions> forumDiscussions(int forumId) async {
    final result = await MoodleRepository.instance.getForumDiscussions(forumId);
    final list = result.dataOrNull ?? const <Discussions>[];
    for (final d in list) {
      _memo.discussions[d.discussion] = d;
    }
    return ForumDiscussions(
      entries: _entries([
        for (final d in list) ForumFeedItem.discussion(d, forumId: forumId),
      ]),
      error: BridgeResults.errorOf(result),
      notice: BridgeResults.noticeOf(result),
      signedIn: AuthSession.instance.isSignedIn,
    );
  }

  @override
  Future<AssignmentList> assignments(String courseId) async {
    final result = await MoodleRepository.instance.getAssignments(courseId);
    final list = result.dataOrNull;
    if (list != null) _memo.assignments[courseId] = list;
    return _assignmentList(list ?? const [], const {},
        error: BridgeResults.errorOf(result),
        notice: BridgeResults.noticeOf(result));
  }

  @override
  Future<AssignmentList> assignmentStatuses(String courseId) async {
    final list = _memo.assignments[courseId] ?? const <MoodleAssignment>[];
    // 背景抓：清單上 N 份並行，不彈框、不開登入頁。
    final results = await Future.wait([
      for (final a in list)
        MoodleRepository.instance.getSubmissionStatus(a.id, background: true),
    ]);
    final statuses = {
      for (var i = 0; i < list.length; i++) list[i].id: results[i],
    };
    for (final entry in statuses.entries) {
      if (entry.value.hasData) _memo.statuses[entry.key] = entry.value;
    }
    return _assignmentList(list, statuses);
  }

  @override
  AssignmentList cachedAssignments(String courseId) {
    final list = _memo.assignments[courseId] ?? const <MoodleAssignment>[];
    return _assignmentList(list, {
      for (final a in list)
        a.id: _memo.statuses[a.id] ??
            const Failed<MoodleAssignSubmissionStatus>(FetchFailed()),
    });
  }

  @override
  Future<WebLink> discussionWebLink(int discussionId) => webLinkOf(withLang(
      '${MoodleWebApiConnector.host}/mod/forum/discuss.php?d=$discussionId'));

  @override
  Future<MoodleLinkTarget> linkTarget(String url) async {
    final target = url.trim();
    if (MoodleWebApiConnector.isOwnPluginFileUrl(target)) {
      return MoodleLinkTarget(
        kind: MoodleLinkKind.download,
        url: MoodleWebApiConnector.fileUrlWithToken(target),
        filename: MoodlePluginFileUtils.downloadNameOf(target),
      );
    }
    if (!WebViewUrlPolicy.isSafe(target)) {
      return MoodleLinkTarget(kind: MoodleLinkKind.blocked, url: target);
    }
    final link = await webLinkOf(target);
    return MoodleLinkTarget(
        kind: MoodleLinkKind.web, url: link.url, fallbackUrl: link.fallbackUrl);
  }

  @override
  bool isAutologinScript(String url) =>
      MoodleWebApiConnector.isAutologinScript(Uri.tryParse(url));

  @override
  List<String> htmlImages(String html) => [
        for (final src in htmlImageSources(html))
          if (MoodleWebApiConnector.isOwnPluginFileUrl(src))
            MoodleWebApiConnector.fileUrlWithToken(src)
          else if (Uri.tryParse(src)?.scheme == 'https')
            src,
      ];

  /// 網頁版的網址帶上介面語系。
  static String withLang(String url) => Connector.uriAddQuery(url, {
        "lang": LanguageUtils.getLangIndex() == LangEnum.zh ? "zh_tw" : "en"
      });

  static Future<WebLink> webLinkOf(String raw) async {
    final url = await MoodleWebApiConnector.autologinUrl(raw);
    return WebLink(url: url, fallbackUrl: url == raw ? null : raw);
  }

  Future<Result<List<MoodleCoreCourseGetContents>>> _loadDirectory(
      String courseId) async {
    final request = _requestDirectory(courseId);
    try {
      final result = await request;
      final data = result.dataOrNull;
      if (data != null) _contents[courseId] = data;
      return result;
    } finally {
      _inflight.removeWhere(
          (id, pending) => id == courseId && identical(pending, request));
    }
  }

  Future<Result<List<MoodleCoreCourseGetContents>>> _requestDirectory(
      String courseId) {
    final pending = _inflight[courseId];
    if (pending != null) return pending;
    final request = MoodleRepository.instance.getCourseDirectory(courseId);
    _inflight[courseId] = request;
    return request;
  }

  /// 公告分頁重新整理時不重抓課程目錄：討論區的 id 不會變。
  Future<List<MoodleCoreCourseGetContents>> _contentsOf(String courseId) async {
    final cached = _contents[courseId];
    if (cached != null && !_inflight.containsKey(courseId)) return cached;
    return (await _loadDirectory(courseId)).dataOrNull ??
        _contents[courseId] ??
        const [];
  }

  Modules? _module(String courseId, int moduleId) {
    for (final section in _contents[courseId] ?? const []) {
      for (final m in section.modules) {
        if (m.id == moduleId) return m;
      }
    }
    return null;
  }

  static CourseSectionItem _section(
          CourseSection section, List<Modules> modules) =>
      CourseSectionItem(
        id: section.raw.id,
        title: section.title,
        summary: section.summaryText,
        modules: [for (final m in modules) moduleItem(m)],
      );

  /// 課程模組表的一個模組，行事曆的待辦也用它開 App 內的頁面。
  static CourseModuleItem moduleItem(Modules m) {
    final file = m.contents.isEmpty ? null : m.contents.first;
    return CourseModuleItem(
      id: m.id,
      instance: m.instance,
      kind: _kindOf(m.modname),
      name: m.name,
      subtitle: CourseModuleUtils.fileSubtitle(m),
      fileIcon: m.modname == 'resource'
          ? FileIconUtils.iconFor(
              filename: file?.filename ?? '',
              mimetype: file?.mimetype ?? '',
              modicon: m.modicon,
            )
          : null,
      descriptionHtml: m.description.trim().isEmpty ? null : m.description,
    );
  }

  static CourseModuleKind _kindOf(String modname) => switch (modname) {
        'resource' => CourseModuleKind.resource,
        'folder' => CourseModuleKind.folder,
        'forum' => CourseModuleKind.forum,
        'assign' => CourseModuleKind.assign,
        'quiz' => CourseModuleKind.quiz,
        'url' => CourseModuleKind.url,
        'page' => CourseModuleKind.page,
        'label' => CourseModuleKind.label,
        _ => CourseModuleKind.other,
      };

  CourseFeed _feedOf(String courseId, FeedKind? kind,
      {String? error, String? notice}) {
    final feed = _feeds[courseId];
    final items = feed?.items ?? const <ForumFeedItem>[];
    final discussions =
        items.where((i) => i.kind == ForumFeedKind.discussion).length;
    final wanted = switch (kind) {
      null => null,
      FeedKind.announcement => ForumFeedKind.announcement,
      FeedKind.discussion => ForumFeedKind.discussion,
    };
    return CourseFeed(
      entries: _entries([
        for (final i in items)
          if (wanted == null || i.kind == wanted) i,
      ]),
      announcementCount: items.length - discussions,
      discussionCount: discussions,
      emptyMessage: (feed?.forumFound ?? true)
          ? R.current.announcementEmpty
          : R.current.announcementNoForum,
      error: error,
      notice: notice,
      signedIn: AuthSession.instance.isSignedIn,
    );
  }

  static List<FeedEntry> _entries(List<ForumFeedItem> items) {
    final now = DateTime.now();
    return [
      for (final entry in groupDiscussionsByMonth(items))
        entry.isHeader
            ? FeedEntry(header: entry.label)
            : FeedEntry(row: _forumRow(entry, now)),
    ];
  }

  static ForumRow _forumRow(ForumListEntry entry, DateTime now) {
    final item = entry.item!;
    final d = item.discussion;
    final author = ForumAuthorName.of(d.userfullname);
    final discussion = item.kind == ForumFeedKind.discussion;
    return ForumRow(
      discussionId: d.discussion,
      forumId: item.forumId,
      name: d.name,
      pinned: d.pinned,
      author: author.name,
      studentId: author.studentId,
      day: forumDayLabel(d.created, now),
      hasAttachment: d.attachment,
      // 純公告頁沒有回覆數：那一頁的每一列都是單向的公告。
      replies: discussion && d.numreplies > 0 ? d.numreplies : null,
      kind: discussion ? FeedKind.discussion : FeedKind.announcement,
      indexInGroup: entry.indexInGroup,
      groupLength: entry.groupLength,
    );
  }

  AssignmentList _assignmentList(List<MoodleAssignment> list,
      Map<int, Result<MoodleAssignSubmissionStatus>> statuses,
      {String? error, String? notice}) {
    // 截止時間全是伺服器寫的，所以「現在」也照伺服器的時鐘。
    final now = _now();
    final sorted = MoodleAssignUtils.sortForList(list, now,
        dueOf: (a) => MoodleAssignUtils.effectiveDueDate(
            a, statuses[a.id]?.dataOrNull));
    return AssignmentList(
      rows: [for (final a in sorted) assignmentRow(a, statuses[a.id], now)],
      summary: MoodleAssignText.listSummary(
          [for (final a in sorted) (a, statuses[a.id]?.dataOrNull)], now),
      error: error,
      notice: notice,
      signedIn: AuthSession.instance.isSignedIn,
    );
  }

  /// 已評分就給分數，其餘給狀態籤。快取（Stale）一律留在籤上：那顆籤才有
  /// 「這是舊資料」的記號，一個裸分數說不出自己是什麼時候的。
  static AssignmentRow assignmentRow(MoodleAssignment a,
      Result<MoodleAssignSubmissionStatus>? result, DateTime now) {
    final data = result?.dataOrNull;
    final status = data == null
        ? null
        : MoodleAssignUtils.resolveStatus(a, data, now: now);
    ({String big, String? small})? grade;
    if (result is Ok<MoodleAssignSubmissionStatus> &&
        status == AssignDisplayStatus.graded) {
      final text = result.data.feedback?.gradefordisplay.trim() ?? '';
      if (text.isNotEmpty) grade = MoodleAssignText.splitGrade(text);
    }
    final chip = grade == null ? status : null;
    return AssignmentRow(
      id: a.id,
      name: a.name,
      subtitle: MoodleAssignText.rowSubtitle(a, data, status, now),
      icon: _iconOf(status),
      grade: grade?.big,
      gradeSuffix: grade?.small,
      statusLabel: chip == null
          ? null
          : MoodleAssignText.statusLabel(chip,
              extended: MoodleAssignText.isExtended(chip, data)),
      statusTone: chip == null ? null : toneOf(chip),
      stale: result is Stale,
      loading: result == null,
    );
  }

  static AssignRowIcon _iconOf(AssignDisplayStatus? status) => switch (status) {
        null => AssignRowIcon.unknown,
        AssignDisplayStatus.overdue => AssignRowIcon.overdue,
        AssignDisplayStatus.draft => AssignRowIcon.draft,
        AssignDisplayStatus.notSubmitted ||
        AssignDisplayStatus.reopened =>
          AssignRowIcon.attention,
        AssignDisplayStatus.submitted => AssignRowIcon.submitted,
        AssignDisplayStatus.graded => AssignRowIcon.graded,
        AssignDisplayStatus.noSubmissionRequired => AssignRowIcon.noSubmission,
      };

  /// 未繳交、已延長、草稿、重新開放是同一件事的幾種說法：還沒交出去，而時間在走。
  static StatusTone toneOf(AssignDisplayStatus status) => switch (status) {
        AssignDisplayStatus.notSubmitted ||
        AssignDisplayStatus.draft ||
        AssignDisplayStatus.reopened =>
          StatusTone.attention,
        AssignDisplayStatus.submitted ||
        AssignDisplayStatus.noSubmissionRequired =>
          StatusTone.pending,
        AssignDisplayStatus.graded => StatusTone.graded,
        AssignDisplayStatus.overdue => StatusTone.overdue,
      };
}
