import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_discussion_posts.dart';
import 'package:flutter_app/src/util/moodle_draft_url_utils.dart';
import 'package:flutter_app/src/util/moodle_forum_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// 內嵌圖片各種網址寫法的換算規格。錯一格就是「貼文永久壞掉」「token 被寫進
/// 一則同學都看得到的貼文」或「這則貼文從此存不回去」，所以每一條都要用
/// **伺服器真的會回的形狀**。
void main() {
  const host = 'https://moodle2.ntust.edu.tw';
  const token = 'abc123token';
  const accessKey = 'privatekey99';

  /// 伺服器的路徑是逐段 rawurlencode 過的——測試一定要照這個形狀，
  /// 不然括號檔名那條會假綠。
  String rawEncode(String name) => Uri.encodeComponent(name).replaceAllMapped(
      RegExp(r"[!*'()]"),
      (m) => '%${m[0]!.codeUnitAt(0).toRadixString(16).toUpperCase()}');

  /// `messageinlinefiles[].url` 真正的樣子。**注意那個 query**：
  /// stored_file_exporter 組網址時第七個引數寫死 true
  /// （`make_pluginfile_url($…, $forcedownload = true)`），而且用的是
  /// `pluginfile.php`，不是 `webservice/pluginfile.php`。
  String exporterUrl(String name) =>
      '$host/pluginfile.php/8801/mod_forum/post/951/${rawEncode(name)}'
      '?forcedownload=1';

  String bare(String name) => exporterUrl(name).split('?').first;

  MoodleForumFile file(String name) =>
      MoodleForumFile(filename: name, filepath: '/', url: exporterUrl(name));

  /// `fileUrlWithToken` 探測完成前的樣子（會先換成吃 token 的那一支）。
  String withQueryToken(String url) =>
      '${url.replaceFirst('/pluginfile.php', '/webservice/pluginfile.php')}'
      '?token=$token';

  /// 探測完成後的樣子。
  String withAccessKey(String url) =>
      url.replaceFirst('/pluginfile.php', '/tokenpluginfile.php/$accessKey');

  group('draftPrefixIn', () {
    // 伺服器端 file_prepare_draft_area() 最後一行組出來的就是這個形狀。
    const messageText = '<p>圖：<img src="$host/draftfile.php/123/user/draft/'
        '999/scope.png"></p>';

    test('itemid 對得上時挑得出前綴', () {
      expect(MoodleDraftUrlUtils.draftPrefixIn(messageText, 999, host: host),
          '$host/draftfile.php/123/user/draft/999/');
    });

    test('itemid 不一樣就回 null——別的 draft 區的前綴會存出永久壞掉的網址', () {
      expect(MoodleDraftUrlUtils.draftPrefixIn(messageText, 1000, host: host),
          isNull);
    });

    test('不是自家站台就回 null', () {
      expect(
          MoodleDraftUrlUtils.draftPrefixIn(messageText, 999,
              host: 'https://evil.example.com'),
          isNull);
    });

    test('itemid <= 0 一律回 null', () {
      expect(MoodleDraftUrlUtils.draftPrefixIn(messageText, 0, host: host),
          isNull);
      expect(MoodleDraftUrlUtils.draftPrefixIn(messageText, -1, host: host),
          isNull);
    });

    test('messagetext 是空的（area=attachment）時回 null', () {
      expect(MoodleDraftUrlUtils.draftPrefixIn('', 999, host: host), isNull);
    });
  });

  group('fileTailOf', () {
    const tail = '/8801/mod_forum/post/951/scope.png';

    test('三種寫法（含 ?forcedownload=1）認出來的是同一段', () {
      expect(MoodleDraftUrlUtils.fileTailOf(exporterUrl('scope.png')), tail);
      expect(MoodleDraftUrlUtils.fileTailOf(withQueryToken(bare('scope.png'))),
          tail);
      expect(MoodleDraftUrlUtils.fileTailOf(withAccessKey(bare('scope.png'))),
          tail);
    });

    test('不是檔案網址就回 null', () {
      expect(MoodleDraftUrlUtils.fileTailOf('$host/mod/forum/discuss.php?d=1'),
          isNull);
      expect(MoodleDraftUrlUtils.fileTailOf(''), isNull);
    });
  });

  group('顯示 → 存檔的來回', () {
    const draftPrefix = '$host/draftfile.php/123/user/draft/999/';

    test('兩張圖（含帶括號與空白的檔名）都換成 draft 網址，一個 pluginfile 都不剩', () {
      final files = [file('scope.png'), file('Lecture (1).png')];
      // 伺服器回的原文長這樣：post_exporter 不跑 format_text。
      const raw = '<p>期中考範圍</p>'
          '<p><img src="${MoodleForumUtils.pluginFileToken}/scope.png"></p>'
          '<p><img src="${MoodleForumUtils.pluginFileToken}'
          '/Lecture%20%281%29.png"></p>';

      final resolved = MoodleForumUtils.resolveInlinePluginFiles(raw, files);
      expect(resolved, isNot(contains(MoodleForumUtils.pluginFileToken)));

      final display = MoodleDraftUrlUtils.rewriteInlineUrlsForDisplay(
          resolved, files, withQueryToken);
      expect(display, contains('token=$token'));
      // 帶著 `?forcedownload=1` 的原網址不可以整段留在 src 裡。
      expect(display.contains('forcedownload'), isFalse);

      final saved = MoodleDraftUrlUtils.rewriteInlineUrlsForSave(
          display, files, draftPrefix);

      expect(saved, contains('src="${draftPrefix}scope.png"'));
      // PHP rawurlencode 會逃 `(` `)`，Uri.encodeComponent 不會。
      expect(saved, contains('src="${draftPrefix}Lecture%20%281%29.png"'));
      expect(saved.contains('pluginfile.php'), isFalse);
      expect(saved.contains('token='), isFalse);
    });

    test('探測翻轉落在開 editor 與存檔之間，存檔照樣換得回來', () {
      final files = [file('scope.png')];
      // 打開編輯器時探測還沒完成 → `?token=`。
      final display = MoodleDraftUrlUtils.rewriteInlineUrlsForDisplay(
          '<p><img src="${bare('scope.png')}"></p>', files, withQueryToken);
      expect(display, contains('token=$token'));

      // 按下儲存時探測已經翻成 tokenpluginfile；存檔不看 tokenize()，看尾巴。
      final saved = MoodleDraftUrlUtils.rewriteInlineUrlsForSave(
          display, files, draftPrefix);

      expect(saved, '<p><img src="${draftPrefix}scope.png"></p>');
    });

    test('編輯器裡是 tokenpluginfile 寫法時也換得回來', () {
      final files = [file('scope.png')];
      final saved = MoodleDraftUrlUtils.rewriteInlineUrlsForSave(
          '<p><img src="${withAccessKey(bare('scope.png'))}"></p>',
          files,
          draftPrefix);

      expect(saved, '<p><img src="${draftPrefix}scope.png"></p>');
    });

    test('不在名單上的檔案網址原封不動——那是別的 filearea，不是這一篇的內嵌圖', () {
      const other = '$host/pluginfile.php/1200101/course/section/5/banner.png';
      final saved = MoodleDraftUrlUtils.rewriteInlineUrlsForSave(
          '<img src="$other">', [file('scope.png')], draftPrefix);

      expect(saved, '<img src="$other">');
    });

    test('沒有網址的檔案直接跳過', () {
      expect(
          MoodleDraftUrlUtils.rewriteInlineUrlsForSave(
              '<p>x</p>', [MoodleForumFile(filename: 'x.png')], draftPrefix),
          '<p>x</p>');
    });
  });

  group('referencesInlineFiles', () {
    test('內文引用得到就是 true，不管網址是哪一種寫法', () {
      final files = [file('scope.png')];
      expect(
          MoodleDraftUrlUtils.referencesInlineFiles(
              '<img src="${withAccessKey(bare('scope.png'))}">', files),
          isTrue);
    });

    test('孤兒檔案（使用者在網頁版刪掉 img，Moodle 沒把檔案拿掉）是 false', () {
      expect(
          MoodleDraftUrlUtils.referencesInlineFiles(
              '<p><strong>重要</strong>：期中考改期</p>', [file('orphan.png')]),
          isFalse);
    });
  });

  group('tokenLeakIn', () {
    const draftPrefix = '$host/draftfile.php/123/user/draft/999/';
    final tails = MoodleDraftUrlUtils.inlineTailsOf([file('a.png')]);

    String? leak(String html) => MoodleDraftUrlUtils.tokenLeakIn(html,
        host: host, wsToken: token, accessKey: accessKey, inlineTails: tails);

    test('token 本身出現就擋', () {
      expect(leak('<p>$token</p>'), isNotNull);
    });

    test('站台檔案網址帶 ?token= 就擋，不必比對值', () {
      expect(leak('<img src="${bare('a.png')}?token=whatever">'), isNotNull);
    });

    test('tokenpluginfile.php 就擋', () {
      expect(leak('<img src="${withAccessKey(bare('a.png'))}">'), isNotNull);
    });

    test('這一篇的內嵌圖沒換成功就擋——存進去伺服器不會再改寫它，圖片永久壞掉', () {
      expect(leak('<img src="${bare('a.png')}">'), isNotNull);
      expect(leak('<img src="${exporterUrl('a.png')}">'), isNotNull);
    });

    test('只有 draftfile 網址時放行', () {
      expect(leak('<p>好</p><img src="${draftPrefix}a.png">'), isNull);
    });

    test('站台上的一般連結不算違規——貼文本來就常常互相連結', () {
      expect(
          leak('<a href="$host/mod/forum/discuss.php?d=7701">前一則</a>'), isNull);
    });

    test('別的 filearea 的絕對檔案網址放行——擋掉等於這種貼文一個字都改不了', () {
      expect(
          leak('<img src="$host/pluginfile.php/1200101/course/section/5/'
              'banner.png">'),
          isNull);
      expect(
          leak('<a href="$host/pluginfile.php/1200102/mod_resource/content/2/'
              'intro.pptx">投影片</a>'),
          isNull);
    });

    test('內文寫到 token= 這四個字不算違規——談 API token 的貼文也要能編輯', () {
      expect(leak('<p>把 <code>token=</code> 加在 query 後面</p>'), isNull);
    });

    test('沒有 token 時（登出後）仍然擋得住沒換成功的內嵌圖', () {
      expect(
          MoodleDraftUrlUtils.tokenLeakIn('<img src="${bare('a.png')}">',
              host: host, wsToken: null, inlineTails: tails),
          isNotNull);
    });
  });
}
