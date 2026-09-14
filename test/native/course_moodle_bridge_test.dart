import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions.dart';
import 'package:flutter_app/src/native/course_moodle_bridge.dart';
import 'package:flutter_app/src/native/moodle_memo.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

class _FakeMoodle extends MoodleRepository {
  Result<List<MoodleCoreCourseGetContents>> directory =
      const Failed(FetchFailed());
  Result<MoodleModForumGetForumDiscussions> announcements =
      const Failed(FetchFailed());
  final Map<int, Result<List<Discussions>>> forums = {};
  Result<List<MoodleAssignment>> assignments = const Failed(FetchFailed());
  final Map<int, Result<MoodleAssignSubmissionStatus>> statuses = {};
  int directoryCalls = 0;
  final List<bool> statusBackgrounds = [];

  @override
  Future<Result<List<MoodleCoreCourseGetContents>>> getCourseDirectory(
      String courseId) async {
    directoryCalls++;
    await Future<void>.delayed(Duration.zero);
    return directory;
  }

  @override
  Future<Result<MoodleModForumGetForumDiscussions>> getAnnouncements(
          String courseId) async =>
      announcements;

  @override
  Future<Result<List<Discussions>>> getForumDiscussions(int forumId) async =>
      forums[forumId] ?? const Failed(FetchFailed());

  @override
  Future<Result<List<MoodleAssignment>>> getAssignments(
          String courseId) async =>
      assignments;

  @override
  Future<Result<MoodleAssignSubmissionStatus>> getSubmissionStatus(
      int assignId,
      {bool background = false}) async {
    statusBackgrounds.add(background);
    return statuses[assignId] ?? const Failed(FetchFailed());
  }
}

const String _pluginFile =
    'https://moodle2.ntust.edu.tw/webservice/pluginfile.php/1/mod_resource/content/1/week1.pdf';

List<MoodleCoreCourseGetContents> weeklyCourse() => [
      MoodleCoreCourseGetContents(id: 1, name: '一般', modules: [
        Modules(id: 10, name: '課程公佈欄', modname: 'forum', instance: 100),
        Modules(id: 13, name: '課程討論區', modname: 'forum', instance: 200),
      ]),
      MoodleCoreCourseGetContents(id: 2, name: '9月 1 日 - 9月 7 日', modules: [
        Modules(
          id: 11,
          name: '第一週講義',
          modname: 'resource',
          instance: 1,
          contents: [
            Contents(
                filename: 'week1.pdf',
                filesize: 2048,
                fileurl: _pluginFile,
                mimetype: 'application/pdf'),
          ],
        ),
      ]),
      MoodleCoreCourseGetContents(id: 3, name: '9月 8 日 - 9月 14 日'),
      MoodleCoreCourseGetContents(id: 4, name: '9月 15 日 - 9月 21 日', modules: [
        Modules(id: 12, name: '作業一', modname: 'assign', instance: 5),
        Modules(
          id: 14,
          name: '補充資料',
          modname: 'folder',
          instance: 6,
          contents: [
            Contents(filename: 'b.pdf', filepath: '/', fileurl: _pluginFile),
            Contents(filename: 'a.pdf', filepath: '/', fileurl: _pluginFile),
            Contents(filename: 'c.pdf', filepath: '/sub/', fileurl: _pluginFile),
          ],
        ),
      ]),
    ];

Discussions discussion(int id, String name, DateTime created,
        {String author = '王老師', int replies = 0, bool attachment = false}) =>
    Discussions(
      id: id * 10,
      discussion: id,
      name: name,
      created: created.millisecondsSinceEpoch ~/ 1000,
      userfullname: author,
      numreplies: replies,
      attachment: attachment,
    );

/// 原生版一門課的 Moodle 分頁。本週是哪一段、公告與討論區怎麼併、作業怎麼排、
/// 每一列寫什麼都是 Dart 的判斷——壞了，原生版會把本週藏進「其他週次」，或把
/// 已經評完的作業畫成還欠著。
void main() {
  setUpAll(() async {
    await loadTestL10n();
    await initializeDateFormatting();
  });

  late _FakeMoodle moodle;
  late CourseMoodleBridge bridge;
  final now = DateTime(2026, 9, 16, 10);

  setUp(() {
    resetAppStatics();
    AuthSession.instance = FakeAuthSession();
    moodle = _FakeMoodle();
    MoodleRepository.instance = moodle;
    bridge = CourseMoodleBridge(MoodleMemo(), now: () => now);
  });

  tearDown(() => MoodleRepository.instance = MoodleRepository());

  group('檔案', () {
    test('週次課程：本週單獨一段，其餘有內容的在下面，空白的週收起來', () async {
      moodle.directory = Ok(weeklyCourse());

      final dir = await bridge.directory('CS3039701');

      expect(dir.weekly, isTrue);
      expect(dir.currentWeek?.id, 4);
      expect(dir.sections.map((s) => s.id), [1, 2]);
      expect(dir.emptySections.map((s) => s.id), [3]);
      expect(dir.stats, '4 個檔案 · 3 週有內容');
      final file = dir.sections[1].modules.single;
      expect((file.kind, file.fileIcon, file.subtitle),
          (CourseModuleKind.resource, 'pdf', 'PDF · 2.0 KB'));
    });

    test('檔案與公告同時進場只抓一次課程目錄', () async {
      moodle.directory = Ok(weeklyCourse());
      moodle.announcements = Ok(MoodleModForumGetForumDiscussions(forumId: 100));

      await Future.wait([bridge.directory('CS1'), bridge.feed('CS1')]);

      expect(moodle.directoryCalls, 1);
    });

    test('搜尋檔名留在原本那一段底下', () async {
      moodle.directory = Ok(weeklyCourse());
      await bridge.directory('CS1');

      final hits = bridge.searchDirectory('CS1', 'WEEK1');

      expect(hits.map((s) => s.id), [2]);
      expect(hits.single.modules.map((m) => m.id), [11]);
    });

    test('點檔案帶憑證下載；沒有檔案的模組回 null', () async {
      MoodleWebApiConnector.wsToken = 'token-abc';
      moodle.directory = Ok(weeklyCourse());
      await bridge.directory('CS1');

      expect(bridge.moduleFile('CS1', 11)?.name, 'week1.pdf');
      expect(bridge.moduleFile('CS1', 11)?.url, contains('token-abc'));
      expect(bridge.moduleFile('CS1', 12), isNull);
    });

    test('資料夾：先子資料夾、再照名稱排的檔案', () async {
      moodle.directory = Ok(weeklyCourse());
      await bridge.directory('CS1');

      final root = bridge.folder('CS1', 14, '/')!;
      expect(root.title, '補充資料');
      expect(root.folders.map((f) => (f.name, f.path, f.subtitle)),
          [('sub', '/sub/', '1 個檔案')]);
      expect(root.files.map((f) => f.name), ['a.pdf', 'b.pdf']);

      final sub = bridge.folder('CS1', 14, '/sub/')!;
      expect((sub.title, sub.breadcrumb), ('sub', '補充資料 / sub'));
    });
  });

  group('公告', () {
    test('公告區與課程討論區併成一條時間軸，公告區本身不重複併進來', () async {
      moodle.directory = Ok(weeklyCourse());
      moodle.announcements = Ok(MoodleModForumGetForumDiscussions(
        forumId: 100,
        discussions: [discussion(1, '期中考範圍', DateTime(2026, 9, 10))],
      ));
      moodle.forums[200] = Ok([
        discussion(2, '第一題怎麼寫', DateTime(2026, 9, 12),
            author: 'B11230223 @ 王小明', replies: 3, attachment: true),
      ]);

      final feed = await bridge.feed('CS1');

      expect(feed.entries.where((e) => e.header != null), hasLength(1));
      final rows = [for (final e in feed.entries) if (e.row != null) e.row!];
      expect(rows.map((r) => (r.discussionId, r.kind)),
          [(2, FeedKind.discussion), (1, FeedKind.announcement)]);
      expect((rows[0].author, rows[0].studentId, rows[0].replies),
          ('王小明', 'B11230223', 3));
      expect(rows[1].replies, isNull, reason: '公告沒有回覆數');
      expect((feed.announcementCount, feed.discussionCount), (1, 1));

      final onlyAnnouncements = bridge.filterFeed('CS1', FeedKind.announcement);
      expect(
          onlyAnnouncements.entries
              .where((e) => e.row != null)
              .map((e) => e.row!.discussionId),
          [1]);
    });

    test('找不到公告區時空清單說的是沒有公告區', () async {
      moodle.directory = const Ok([]);
      moodle.announcements =
          Ok(MoodleModForumGetForumDiscussions(forumFound: false));

      final feed = await bridge.feed('CS1');

      expect(feed.entries, isEmpty);
      expect(feed.emptyMessage, '這門課沒有公告區');
    });
  });

  group('作業', () {
    final future = MoodleAssignment(
        id: 1,
        name: '報告',
        duedate: now.add(const Duration(days: 2)).millisecondsSinceEpoch ~/ 1000);
    final past = MoodleAssignment(
        id: 2,
        name: '習題',
        duedate:
            now.subtract(const Duration(days: 5)).millisecondsSinceEpoch ~/ 1000);

    test('先給清單，狀態背景抓完再重算：評完的給分數，交出去的給籤', () async {
      moodle.assignments = Ok([past, future]);
      moodle.statuses[1] = Ok(MoodleAssignSubmissionStatus(
        lastattempt: MoodleAssignLastAttempt(
          submission: MoodleAssignSubmission(
              status: 'submitted',
              timemodified: now.millisecondsSinceEpoch ~/ 1000),
        ),
      ));
      moodle.statuses[2] = Ok(MoodleAssignSubmissionStatus(
        lastattempt: MoodleAssignLastAttempt(gradingstatus: 'graded'),
        feedback: MoodleAssignFeedback(gradefordisplay: '92.00 / 100.00'),
      ));

      final first = await bridge.assignments('CS1');
      expect(first.rows.map((r) => (r.id, r.loading)), [(1, true), (2, true)]);
      expect(first.summary, '2 件');

      final done = await bridge.assignmentStatuses('CS1');
      expect(moodle.statusBackgrounds, [true, true]);
      final graded = done.rows.singleWhere((r) => r.id == 2);
      expect((graded.grade, graded.gradeSuffix, graded.statusLabel),
          ('92.00', '/100.00', null));
      final submitted = done.rows.singleWhere((r) => r.id == 1);
      expect((submitted.statusLabel, submitted.statusTone, submitted.icon),
          ('待評分', StatusTone.pending, AssignRowIcon.submitted));
      expect(done.summary, '2 件');
    });

    test('每一份都評完才說全部已評分', () async {
      moodle.assignments = Ok([past]);
      moodle.statuses[2] = Ok(MoodleAssignSubmissionStatus(
        lastattempt: MoodleAssignLastAttempt(gradingstatus: 'graded'),
      ));

      await bridge.assignments('CS1');
      final done = await bridge.assignmentStatuses('CS1');

      expect(done.summary, '1 件 · 全部已評分');
    });
  });

  group('HTML', () {
    test('圖片：自家檔案帶憑證、其他站台只收 https、重複的只留一張', () {
      MoodleWebApiConnector.wsToken = 'token-abc';

      final images = bridge.htmlImages('<p><img src="$_pluginFile">'
          '<img alt="x" src="http://example.com/x.png">'
          "<img src='https://example.com/y.png'>"
          '<img src="$_pluginFile"></p>');

      expect(images, hasLength(2));
      expect(images.first, contains('token-abc'));
      expect(images.last, 'https://example.com/y.png');
    });
  });
}
