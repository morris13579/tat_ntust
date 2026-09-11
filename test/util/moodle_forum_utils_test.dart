import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_discussion_posts.dart';
import 'package:flutter_app/src/util/html_utils.dart';
import 'package:flutter_app/src/util/moodle_forum_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/moodle_forum_fixtures.dart';

/// 討論串攤平、內嵌檔案還原與退路貼文的純函式規格。
void main() {
  group('buildThread', () {
    test('深度優先、同層照伺服器順序', () {
      final flat = MoodleForumUtils.buildThread(fixturePosts());

      expect(flat.map((t) => t.post.id), [900, 901, 902, 903]);
      expect(flat.map((t) => t.depth), [0, 1, 2, 1]);
    });

    test('父貼文不在清單裡的當成根，接在真正的根後面而不是被丟掉', () {
      final flat = MoodleForumUtils.buildThread(
          fixturePosts('get_discussion_posts_orphan'));

      expect(flat.map((t) => t.post.id), [910, 912]);
      expect(flat.map((t) => t.depth), [0, 0]);
    });

    test('父子互指也會結束，而且兩篇各出現一次', () {
      final a = MoodleForumPost(id: 1, hasparent: true, parentid: 2);
      final b = MoodleForumPost(id: 2, hasparent: true, parentid: 1);

      final flat = MoodleForumUtils.buildThread([a, b]);

      expect(flat.map((t) => t.post.id), unorderedEquals([1, 2]));
      expect(flat, hasLength(2));
    });

    test('空清單 → 空清單', () {
      expect(MoodleForumUtils.buildThread(const []), isEmpty);
    });
  });

  group('resolveInlinePluginFiles', () {
    MoodleForumFile file(String filename, String url) =>
        MoodleForumFile(filename: filename, filepath: '/', url: url);

    test('檔名有空白（url 是 percent-encoded）也對得起來', () {
      const url = 'https://x/pluginfile.php/1/mod_forum/post/9/a%20b.png';

      expect(
        MoodleForumUtils.resolveInlinePluginFiles(
            '<img src="@@PLUGINFILE@@/a%20b.png">', [file('a b.png', url)]),
        '<img src="https://x/pluginfile.php/1/mod_forum/post/9/a%20b.png">',
      );
    });

    test("檔名帶 !*'() 也對得起來（伺服器是 rawurlencode，比 Dart 多轉這幾個）", () {
      const url =
          'https://x/pluginfile.php/1/mod_forum/post/9/Lecture%20%281%29.png';

      expect(
        MoodleForumUtils.resolveInlinePluginFiles(
            '<img src="@@PLUGINFILE@@/Lecture%20%281%29.png">',
            [file('Lecture (1).png', url)]),
        '<img src="$url">',
      );
    });

    test('純 ASCII 檔名照樣對得起來', () {
      const url = 'https://x/pluginfile.php/1/mod_forum/post/9/a.png';

      expect(
        MoodleForumUtils.resolveInlinePluginFiles(
            '<img src="@@PLUGINFILE@@/a.png">', [file('a.png', url)]),
        '<img src="https://x/pluginfile.php/1/mod_forum/post/9/a.png">',
      );
    });

    test('沒有檔案時原樣回傳（佔位字串留著，是看得見的破圖不是靜默錯誤）', () {
      const message = '<img src="@@PLUGINFILE@@/a.png">';

      expect(MoodleForumUtils.resolveInlinePluginFiles(message, const []),
          message);
    });

    test('訊息裡沒有佔位字串就原樣回傳', () {
      const message = '<p>沒有圖片</p>';

      expect(
        MoodleForumUtils.resolveInlinePluginFiles(
            message, [file('a.png', 'https://x/a.png')]),
        message,
      );
    });

    test('url 的結尾對不上 filepath+filename 時不亂猜', () {
      const message = '<img src="@@PLUGINFILE@@/a.png">';

      expect(
        MoodleForumUtils.resolveInlinePluginFiles(
            message, [file('a.png', 'https://x/other.png')]),
        message,
      );
    });
  });

  group('plainTextToHtml', () {
    test('五個字元都 escape，a < b 原樣活下來', () {
      expect(MoodleForumUtils.plainTextToHtml('a < b & c > d'),
          'a &lt; b &amp; c &gt; d');
      expect(MoodleForumUtils.plainTextToHtml('"雙" \'單\''),
          '&quot;雙&quot; &#39;單&#39;');
      // & 一定要先換，否則 &lt; 會被二次 escape 成 &amp;lt;
      expect(MoodleForumUtils.plainTextToHtml('<b>'), '&lt;b&gt;');
      expect(MoodleForumUtils.plainTextToHtml('&amp;'), '&amp;amp;');
    });

    test('CRLF、單獨的 CR 與空行都變成 <br>', () {
      expect(MoodleForumUtils.plainTextToHtml('a\r\nb'), 'a<br>b');
      expect(MoodleForumUtils.plainTextToHtml('a\rb'), 'a<br>b');
      expect(MoodleForumUtils.plainTextToHtml('a\n\nb'), 'a<br><br>b');
    });

    test('空字串 → 空字串', () {
      expect(MoodleForumUtils.plainTextToHtml(''), '');
    });

    test('輸出再過 HtmlUtils.clean 會拿回原本那一行字', () {
      const original = 'a < b & "c" 的 <script> 不是標籤';

      expect(HtmlUtils.clean(MoodleForumUtils.plainTextToHtml(original)),
          original);
    });
  });

  group('messageToDisplayHtml', () {
    test('FORMAT_PLAIN：escape 加換行', () {
      expect(
          MoodleForumUtils.messageToDisplayHtml(
              'a < b\nc', MoodleForumUtils.formatPlain),
          'a &lt; b<br>c');
    });

    test('FORMAT_MOODLE：只換行、不 escape（照抄 text_to_html）', () {
      expect(
          MoodleForumUtils.messageToDisplayHtml(
              '<b>粗體</b>\n第二行', MoodleForumUtils.formatMoodle),
          '<b>粗體</b><br>第二行');
    });

    test('FORMAT_HTML 與 FORMAT_MARKDOWN 原封不動', () {
      const html = '<p>已經是 HTML</p>\n<p>第二段</p>';

      expect(MoodleForumUtils.messageToDisplayHtml(html, 1), html);
      expect(MoodleForumUtils.messageToDisplayHtml(html, 4), html);
    });
  });

  group('canReply', () {
    test('capabilities 是 null（舊快取／站台沒回）→ 不能回覆', () {
      expect(MoodleForumUtils.canReply(MoodleForumPost(id: 1)), isFalse);
    });

    test('reply 為 true 但貼文已刪除 → 不能回覆', () {
      final p = MoodleForumPost(id: 1, isdeleted: true)
        ..capabilities = MoodleForumPostCapabilities(reply: true);

      expect(MoodleForumUtils.canReply(p), isFalse);
    });

    test('reply 為 true 且沒被刪除 → 可以回覆；reply 為 false → 不行', () {
      final ok = MoodleForumPost(id: 1)
        ..capabilities = MoodleForumPostCapabilities(reply: true);
      final no = MoodleForumPost(id: 2)
        ..capabilities = MoodleForumPostCapabilities(reply: false);

      expect(MoodleForumUtils.canReply(ok), isTrue);
      expect(MoodleForumUtils.canReply(no), isFalse);
    });
  });

  group('mergePost', () {
    test('新的 id 接在最後，buildThread 之後掛在 parentid 底下', () {
      final posts = fixturePosts();
      final added = MoodleForumPost(
          id: 950, hasparent: true, parentid: 901, discussionid: 7701);

      final merged = MoodleForumUtils.mergePost(posts, added);

      expect(merged.map((p) => p.id), [900, 901, 902, 903, 950]);
      final flat = MoodleForumUtils.buildThread(merged);
      final index = flat.indexWhere((t) => t.post.id == 950);
      expect(flat[index].depth, 2, reason: '901 在第 1 層，它的回覆在第 2 層');
    });

    test('已存在的 id 就地取代，不會變成兩篇', () {
      final posts = fixturePosts();
      final replaced = MoodleForumPost(id: 901, message: '改過了');

      final merged = MoodleForumUtils.mergePost(posts, replaced);

      expect(merged, hasLength(posts.length));
      expect(merged[1].message, '改過了');
    });

    test('原本的清單不會被就地改動', () {
      final posts = fixturePosts();

      MoodleForumUtils.mergePost(posts, MoodleForumPost(id: 950));

      expect(posts, hasLength(4));
    });
  });

  group('rootPostOf', () {
    test('discussionid 來自 discussion 而不是 id，附件的 fileurl 對映到 url', () {
      final d = fixtureDiscussions().discussions.first;

      final p = MoodleForumUtils.rootPostOf(d);

      expect(p.id, 8801);
      expect(p.discussionid, 7701, reason: 'id 是第一篇貼文的 id，不是討論串 id');
      expect(p.subject, d.subject);
      expect(p.message, d.message);
      expect(p.timecreated, d.created);
      expect(p.timemodified, d.modified);
      expect(p.author?.fullname, '王老師');
      expect(p.hasparent, isFalse);
      expect(p.parentid, isNull);
      expect(p.attachments.single.filename, 'exam_scope.pdf');
      expect(p.attachments.single.url, d.attachments.single.fileurl);
    });
  });
}
