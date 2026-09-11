import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_discussion_posts.dart';
import 'package:flutter_app/src/util/moodle_forum_edit_utils.dart';
import 'package:flutter_app/src/util/moodle_forum_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// 編輯與附件那條路的純函式規格。不碰網路、不碰 R.current。
void main() {
  const html = MoodleForumUtils.formatHtml;
  const plain = MoodleForumUtils.formatPlain;
  const moodle = MoodleForumUtils.formatMoodle;

  group('isPlainRoundTrip', () {
    test('FORMAT_PLAIN 與 FORMAT_MOODLE 一律安全——伺服器存的就是純文字', () {
      expect(
          MoodleForumEditUtils.isPlainRoundTrip('<b>不是標籤</b>', plain), isTrue);
      expect(MoodleForumEditUtils.isPlainRoundTrip('a < b', moodle), isTrue);
    });

    test('App 自己產的 HTML（escape + <br>）過得了——不然使用者剛用 App 發的文自己編輯不了', () {
      for (final source in [
        '謝謝老師',
        '第一行\n第二行',
        'a < b && c > d',
        '他說「"引號"」與 \'單引號\'',
        '空白行\n\n中間',
      ]) {
        final stored = MoodleForumUtils.plainTextToHtml(source);
        expect(MoodleForumEditUtils.isPlainRoundTrip(stored, html), isTrue,
            reason: '這是 App 自己發的：$stored');
        expect(MoodleForumEditUtils.htmlToPlain(stored), source);
      }
    });

    test('含排版標籤 → 不安全：純文字覆蓋會把粗體與連結弄丟', () {
      expect(
          MoodleForumEditUtils.isPlainRoundTrip('<p>期中考 <b>重要</b></p>', html),
          isFalse);
      expect(
          MoodleForumEditUtils.isPlainRoundTrip(
              '<a href="https://x">連結</a>', html),
          isFalse);
    });

    test('含 <img> 或 @@PLUGINFILE@@ → 不安全：內嵌圖片會斷、舊檔案變孤兒', () {
      expect(
          MoodleForumEditUtils.isPlainRoundTrip('看這張 <img src="a.png">', html),
          isFalse);
      expect(
          MoodleForumEditUtils.isPlainRoundTrip(
              '看這張 @@PLUGINFILE@@/a.png', html),
          isFalse);
      // 大小寫不同也要擋下來。
      expect(MoodleForumEditUtils.isPlainRoundTrip('<IMG SRC="a.png">', html),
          isFalse);
    });

    test('伺服器真正吐回來的寫法（`<br />` + `&#039;`）要判成安全', () {
      // 這一組不是 plainTextToHtml() 的輸出，是伺服器的：`format_text` 的
      // nl2br 與 HTMLPurifier（XHTML 1.0 Transitional）都吐 `<br />`，
      // PHP `s()` 是 ENT_QUOTES 的 `&#039;`。以前拿 `<br>` 去比，於是**任何
      // 多行或含單引號的貼文**都被判成不安全——包含 App 自己幾秒鐘前發的那則。
      expect(MoodleForumEditUtils.isPlainRoundTrip('一<br />二', html), isTrue);
      expect(MoodleForumEditUtils.isPlainRoundTrip('一<br/>二', html), isTrue);
      expect(MoodleForumEditUtils.isPlainRoundTrip('他說 &#039;單引號&#039;', html),
          isTrue);
      expect(MoodleForumEditUtils.htmlToPlain('一<br />二'), '一\n二');
      expect(MoodleForumEditUtils.htmlToPlain('&#039;x&#039;'), "'x'");
    });

    test('plainEditPayload：FORMAT_HTML 的貼文要轉成 HTML 再送回去', () {
      // 純文字直接配 FORMAT_HTML 送出去，換行會被 HTML 吃掉；配 FORMAT_PLAIN
      // 送則會把貼文永久降級成純文字，而這一支不吃 topreferredformat。
      final p = MoodleForumEditUtils.plainEditPayload('一\n二', html);
      expect(p.message, '一<br>二');
      expect(p.format, html);
    });

    test('plainEditPayload：原本就是純文字的貼文原樣送回，format 不變', () {
      for (final f in [plain, moodle]) {
        final p = MoodleForumEditUtils.plainEditPayload('一\n二', f);
        expect(p.message, '一\n二');
        expect(p.format, f, reason: '不可以趁編輯把 format 改掉');
      }
    });

    test('認不得的 format（MARKDOWN=4）一律不安全', () {
      expect(MoodleForumEditUtils.isPlainRoundTrip('**粗體**', 4), isFalse);
    });
  });

  group('htmlToPlain', () {
    test('&amp; 最後解：使用者打的 &lt; 不會被還原成 <', () {
      // 使用者實際打的是「&lt;」這五個字。
      final stored = MoodleForumUtils.plainTextToHtml('&lt;');
      expect(stored, '&amp;lt;');
      expect(MoodleForumEditUtils.htmlToPlain(stored), '&lt;');
    });

    test('空字串回空字串', () {
      expect(MoodleForumEditUtils.htmlToPlain(''), '');
    });
  });

  group('effectiveMaxBytes', () {
    test('取正值中的最小', () {
      expect(
          MoodleForumEditUtils.effectiveMaxBytes(
              siteMax: 5000000, forumMax: 512000),
          512000);
      expect(
          MoodleForumEditUtils.effectiveMaxBytes(
              siteMax: 100000, forumMax: 512000),
          100000);
    });

    test('siteMax == -1 是 USER_CAN_IGNORE_FILE_SIZE_LIMITS，不參與比較', () {
      expect(
          MoodleForumEditUtils.effectiveMaxBytes(siteMax: -1, forumMax: 512000),
          512000);
    });

    test('forumMax == 0（用課程／站台預設）不參與比較', () {
      expect(MoodleForumEditUtils.effectiveMaxBytes(siteMax: 5000, forumMax: 0),
          5000);
    });

    test('一個正值都沒有 → 0＝不知道／不限', () {
      expect(
          MoodleForumEditUtils.effectiveMaxBytes(siteMax: -1, forumMax: 0), 0);
    });

    test('areaMax 是伺服器解析過的真值，比近似值小就用它', () {
      expect(
          MoodleForumEditUtils.effectiveMaxBytes(
              siteMax: 5000000, forumMax: 512000, areaMax: 262144),
          262144);
    });
  });

  group('hasVisibleReplies', () {
    List<MoodleForumPost> thread() => [
          MoodleForumPost(id: 900),
          MoodleForumPost(id: 901, hasparent: true, parentid: 900),
          MoodleForumPost(id: 902, hasparent: true, parentid: 901),
        ];

    test('有子貼文的算有回覆，葉節點沒有', () {
      expect(MoodleForumEditUtils.hasVisibleReplies(thread(), 900), isTrue);
      expect(MoodleForumEditUtils.hasVisibleReplies(thread(), 901), isTrue);
      expect(MoodleForumEditUtils.hasVisibleReplies(thread(), 902), isFalse);
    });

    test('自己指向自己不算回覆', () {
      final posts = [MoodleForumPost(id: 900, hasparent: true, parentid: 900)];
      expect(MoodleForumEditUtils.hasVisibleReplies(posts, 900), isFalse);
    });
  });

  group('duplicateFilename', () {
    test('大小寫視為相同——clean_param 會改寫檔名，寧可保守', () {
      expect(
          MoodleForumEditUtils.duplicateFilename(['a.pdf', 'A.PDF']), 'A.PDF');
      expect(
          MoodleForumEditUtils.duplicateFilename(['a.pdf', 'b.pdf']), isNull);
      expect(MoodleForumEditUtils.duplicateFilename([]), isNull);
    });
  });

  group('missingAttachments', () {
    test('伺服器沒收下的那些——這是靜默丟棄唯一可靠的一層', () {
      final got = [MoodleForumFile(filename: 'slides.pdf')];
      expect(
          MoodleForumEditUtils.missingAttachments(
              ['slides.pdf', 'note.txt'], got),
          ['note.txt']);
      expect(MoodleForumEditUtils.missingAttachments(['slides.pdf'], got),
          isEmpty);
    });

    test('伺服器回的檔名大小寫不同不算少', () {
      final got = [MoodleForumFile(filename: 'Slides.PDF')];
      expect(MoodleForumEditUtils.missingAttachments(['slides.pdf'], got),
          isEmpty);
    });

    test('一個都沒送出去時（attachmentsid 被靜靜改成 0）整份都算少', () {
      expect(
          MoodleForumEditUtils.missingAttachments(['a.pdf', 'b.pdf'], const []),
          ['a.pdf', 'b.pdf']);
    });
  });

  group('exceedsCount / exceedsSize', () {
    test('上限為 0（不知道）時一律不擋，交給伺服器回答', () {
      expect(MoodleForumEditUtils.exceedsCount(5, 0), isFalse);
      expect(MoodleForumEditUtils.exceedsSize(999999, 0), isFalse);
    });

    test('正好等於上限不算超過', () {
      expect(MoodleForumEditUtils.exceedsCount(3, 3), isFalse);
      expect(MoodleForumEditUtils.exceedsCount(4, 3), isTrue);
      expect(MoodleForumEditUtils.exceedsSize(100, 100), isFalse);
      expect(MoodleForumEditUtils.exceedsSize(101, 100), isTrue);
    });
  });

  group('editorKindFor', () {
    const markdown = 4;

    test('FORMAT_PLAIN / FORMAT_MOODLE 不管內容一律純文字框', () {
      for (final format in [plain, moodle]) {
        for (final message in [
          'a &amp; b',
          '<img src="x">',
          '<table></table>'
        ]) {
          expect(MoodleForumEditUtils.editorKindFor(message, format),
              ForumEditorKind.plainText,
              reason: '$format / $message');
        }
      }
    });

    test('FORMAT_HTML 而且過得了 round-trip → 純文字框', () {
      // `<p>` 本身過不了 round-trip（htmlToPlain 不認 <p>），所以那種貼文
      // 走 rich——這裡要挑真的過得了的：App 自己發出去的那種。
      expect(MoodleForumEditUtils.editorKindFor('謝謝老師！', html),
          ForumEditorKind.plainText);
      expect(
          MoodleForumEditUtils.editorKindFor(
              MoodleForumUtils.plainTextToHtml('第一行\n第二行'), html),
          ForumEditorKind.plainText);
    });

    test('FORMAT_HTML 而且撐不進純文字框 → 所見即所得', () {
      for (final message in [
        '<p><img src="@@PLUGINFILE@@/a.png"></p>',
        '<p><img src="https://x/y.png"></p>',
        '<table><tr><td>1</td></tr></table>',
        '<p>期中考範圍如圖 <b>重要</b></p>',
      ]) {
        expect(MoodleForumEditUtils.editorKindFor(message, html),
            ForumEditorKind.rich,
            reason: message);
      }
    });

    test('FORMAT_MARKDOWN 與未知格式 → 原始碼，**永遠不是 rich**', () {
      // 把 Markdown 塞進 HTML 編輯器再以 FORMAT_HTML 存回去是救不回來的：
      // update_discussion_post 不吃 topreferredformat。
      expect(MoodleForumEditUtils.editorKindFor('## 標題', markdown),
          ForumEditorKind.rawSource);
      expect(MoodleForumEditUtils.editorKindFor('<img src="x">', markdown),
          ForumEditorKind.rawSource);
      expect(MoodleForumEditUtils.editorKindFor('whatever', 7),
          ForumEditorKind.rawSource);
    });

    test('每一個格式都答得出來，而且只有 FORMAT_HTML 可能是 rich', () {
      for (var format = -1; format <= 8; format++) {
        final kind =
            MoodleForumEditUtils.editorKindFor('<img src="x">', format);
        if (kind == ForumEditorKind.rich) expect(format, html);
      }
    });
  });

  group('initialTextFor', () {
    const markdown = 4;

    test('非 HTML 的格式原樣帶進去，來回一趟一個位元組都不變', () {
      const fixtures = [
        (message: 'a &amp; b <br> c', format: plain),
        (message: '第一行\n第二行', format: plain),
        (message: 'a < b &amp;&amp; c', format: moodle),
        (message: '## 標題\n\n- 一\n- 二', format: markdown),
        (message: '`code &amp; more`', format: markdown),
      ];
      for (final f in fixtures) {
        final seeded = MoodleForumEditUtils.initialTextFor(f.message, f.format);
        expect(seeded, f.message, reason: '${f.format}');
        final payload = MoodleForumEditUtils.plainEditPayload(seeded, f.format);
        expect(payload.message, f.message);
        expect(payload.format, f.format);
      }
    });

    test('FORMAT_HTML 才還原成純文字', () {
      expect(MoodleForumEditUtils.initialTextFor('a &amp; b<br>c', html),
          'a & b\nc');
    });
  });

  group('basename', () {
    test('兩種分隔符都認', () {
      expect(MoodleForumEditUtils.basename('/a/b/c.pdf'), 'c.pdf');
      expect(MoodleForumEditUtils.basename(r'C:\a\c.pdf'), 'c.pdf');
      expect(MoodleForumEditUtils.basename('c.pdf'), 'c.pdf');
    });
  });
}
