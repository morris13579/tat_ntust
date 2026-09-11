import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_discussion_posts.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/moodle_forum_fixtures.dart';

/// 論壇貼文的解析契約：伺服器缺席、送 null、或多送欄位時都不能拋。
void main() {
  group('MoodleForumPost.fromJson', () {
    test('fixture 的四篇都解得開，不建模的欄位被忽略', () {
      final parsed = rawFixturePosts();

      expect(parsed.posts, hasLength(4));
      expect(parsed.posts.first.discussionid, 7701);
      expect(parsed.posts.first.messageinlinefiles, hasLength(1));
    });

    test('parentid 缺席、timecreated 明確是 null 都解得開', () {
      final root = rawFixturePosts().posts.first;
      final deleted = rawFixturePosts().posts.last;

      expect(root.hasparent, isFalse);
      expect(root.parentid, isNull);
      expect(deleted.timecreated, isNull);
      expect(deleted.timemodified, 1756930000);
    });

    test('messageinlinefiles / unread / urls / tags / html 缺席都不拋', () {
      final p = MoodleForumPost.fromJson(const {
        'id': 1,
        'subject': 'x',
        'message': '<p>x</p>',
        'discussionid': 2,
        'hasparent': false,
        'isdeleted': false,
        'isprivatereply': false,
        'attachments': [],
      });

      expect(p.messageinlinefiles, isEmpty);
      expect(p.timecreated, isNull);
      expect(p.attachments, isEmpty);
    });

    test('author 缺席回 null，author.fullname 是 null 時回空字串', () {
      final noAuthor = MoodleForumPost.fromJson(const {'id': 1});
      final deleted = rawFixturePosts().posts.last;

      expect(noAuthor.author, isNull);
      expect(deleted.author, isNotNull);
      expect(deleted.author!.fullname, '');
      expect(deleted.author!.isdeleted, isTrue);
    });

    test('附件走 stored_file_exporter：url 而不是 fileurl，filepath 預設是 /', () {
      final f = MoodleForumFile.fromJson(const {
        'filename': 'a.pdf',
        'url': 'https://x/a.pdf',
      });

      expect(f.url, 'https://x/a.pdf');
      expect(f.filepath, '/');
      expect(f.filesize, 0);
      expect(f.isimage, isFalse);
    });
  });

  group('MoodleModForumGetForumDiscussions 的 forumFound', () {
    test('toJson / fromJson 來回都留著', () {
      final encoded = MoodleModForumGetForumDiscussions(forumFound: false)
          .toJson()
          .cast<String, dynamic>();

      expect(MoodleModForumGetForumDiscussions.fromJson(encoded).forumFound,
          isFalse);
    });

    test('沒有 forumFound 的 JSON（既有快取與伺服器原始回應）解成 true', () {
      final parsed = MoodleModForumGetForumDiscussions.fromJson(
          const {'discussions': <dynamic>[]});

      expect(parsed.forumFound, isTrue);
      expect(parsed.discussions, isEmpty);
    });
  });
}
