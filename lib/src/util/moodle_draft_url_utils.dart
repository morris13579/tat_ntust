import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_discussion_posts.dart';

/// 內嵌圖片在三種寫法之間的換算：資料庫的 `@@PLUGINFILE@@`、編輯器看得見的
/// 帶憑證 pluginfile 網址、送回伺服器時的 `draftfile.php` 網址。
///
/// 為什麼另開一檔而不是塞進 `moodle_forum_edit_utils.dart`：那一支是「編輯
/// 與附件」的判斷，這裡全部是網址改寫，而且 repository 兩支都要 import——
/// 讓它們互相 import 就是一條沒必要的 util → util 橫向邊。
///
/// **不 import connector**（那是上行邊），所以 host、token、accesskey 與
/// 加憑證的動作全部由呼叫端傳進來。
class MoodleDraftUrlUtils {
  MoodleDraftUrlUtils._();

  /// `prepare_draft_area_for_post(area: 'post')` 回的 `messagetext` 裡，那個
  /// draft 區的網址前綴。
  ///
  /// 伺服器端是 `file_prepare_draft_area()` 最後一行
  /// `file_rewrite_pluginfile_urls($text, 'draftfile.php', $usercontext->id,
  /// 'user', 'draft', $draftitemid, ...)`，組出來就是
  /// `{wwwroot}/draftfile.php/{usercontextid}/user/draft/{itemid}/`。
  ///
  /// **一定要用讀的，不可以自己組**：usercontextid 沒有第二個可靠的來源。
  /// 而且尾巴的 itemid 必須等於 [draftItemId]——別的 draft 區的前綴組出來的
  /// 網址存進貼文之後，`file_save_draft_area_files()` 的反向 `str_ireplace`
  /// 對不上，那些絕對網址會原樣留在資料庫裡，圖片永久壞掉。
  static String? draftPrefixIn(String messageText, int draftItemId,
      {required String host}) {
    if (draftItemId <= 0 || host.isEmpty) return null;
    final pattern = RegExp('${RegExp.escape(host)}'
        r'/draftfile\.php/\d+/user/draft/'
        '$draftItemId/');
    return pattern.firstMatch(messageText)?.group(0);
  }

  /// 這個內嵌檔案在站台上的識別片段：砍掉 host 與檔案服務程式那一段之後，
  /// 剩下的 `/<contextid>/<component>/<filearea>/<itemid>/<路徑><檔名>`。
  ///
  /// **改寫與檢查都認這一段，不可以改成列舉網址寫法。** 同一個檔案至少有四種
  /// 長相：`/pluginfile.php`（`messageinlinefiles` 給的就是這種，還帶著
  /// `?forcedownload=1`）、`/webservice/pluginfile.php?token=<wsToken>`、
  /// `/tokenpluginfile.php/<accesskey>`，而 `fileUrlWithToken` 不是純函式——
  /// `tokenPluginFileWorks` 的探測可能剛好翻在「打開編輯器」與「按下儲存」
  /// 之間，編輯器裡那一個寫法不見得是現在 tokenize() 產出的。差別全都在這一段
  /// 前面，認尾巴就四種一起認得。
  static String? fileTailOf(String url) {
    if (url.isEmpty) return null;
    final path = _withoutQuery(url);
    final match = _fileScript.firstMatch(path);
    if (match == null) return null;
    final tail = path.substring(match.end);
    return tail.length > 1 ? tail : null;
  }

  /// [inlineFiles] 全部的識別片段，認不出來的（不是 pluginfile 網址）跳過。
  static List<String> inlineTailsOf(List<MoodleForumFile> inlineFiles) {
    final tails = <String>[];
    for (final f in inlineFiles) {
      final tail = fileTailOf(f.url);
      if (tail != null) tails.add(tail);
    }
    return tails;
  }

  /// 這段 HTML 還指不指得到 [inlineFiles] 裡的任何一個檔案。
  ///
  /// **存檔那條路要用它決定開不開 draft 區，不可以問「檔案區裡有沒有東西」**：
  /// 使用者在網頁版刪掉 `<img>` 之後 Moodle 不會把檔案從貼文的 filearea 拿掉
  /// （`file_save_draft_area_files()` 只做合併），`messageinlinefiles` 於是
  /// 留著一個沒人引用的孤兒。
  static bool referencesInlineFiles(
          String html, List<MoodleForumFile> inlineFiles) =>
      inlineTailsOf(inlineFiles).any(html.contains);

  /// 開編輯器時：HTML 裡指向 [inlineFiles] 的網址 → 當下就載得動的帶憑證網址。
  ///
  /// [tokenize] 由呼叫端注入（`MoodleWebApiConnector.fileUrlWithToken`），
  /// 這個檔案才不必 import connector，測試也不必有一顆真的 token。
  static String rewriteInlineUrlsForDisplay(
          String html,
          List<MoodleForumFile> inlineFiles,
          String Function(String) tokenize) =>
      _rewrite(html, inlineFiles, (f) => tokenize(_withoutQuery(f.url)));

  /// 存檔時：反過來換成那一區 draft 的網址。
  static String rewriteInlineUrlsForSave(
          String html, List<MoodleForumFile> inlineFiles, String draftPrefix) =>
      _rewrite(html, inlineFiles,
          (f) => draftPrefix + _rawEncodePath(_relativePathOf(f)));

  static String _rewrite(String html, List<MoodleForumFile> inlineFiles,
      String Function(MoodleForumFile) target) {
    if (html.isEmpty) return html;
    final byTail = <String, MoodleForumFile>{};
    for (final f in inlineFiles) {
      final tail = fileTailOf(f.url);
      if (tail != null) byTail.putIfAbsent(tail, () => f);
    }
    if (byTail.isEmpty) return html;
    // 長的尾巴先比，同一區裡的 `a.png` 與 `sub/a.png` 才不會互相認錯。
    final tails = byTail.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    return html.replaceAllMapped(_absoluteUrl, (m) {
      final url = m.group(0)!;
      if (!url.contains(_pluginFileMarker)) return url;
      for (final tail in tails) {
        if (url.contains(tail)) return target(byTail[tail]!);
      }
      return url;
    });
  }

  /// `filepath` 開頭那個 `/` 要拿掉：draft 區的前綴已經以 `/` 結尾。
  static String _relativePathOf(MoodleForumFile f) {
    final raw = '${f.filepath}${f.filename}';
    return raw.startsWith('/') ? raw.substring(1) : raw;
  }

  /// 逐段照 PHP `rawurlencode`。Dart 的 `encodeComponent` 會留下 `!*'()`，
  /// `Lecture (1).png` 這種檔名就對不起來。
  ///
  /// 刻意複製 `MoodleForumUtils` 裡同名的私有實作而不是 import 它：那是
  /// util → util 的橫向邊，換來的只是五行。
  static String _rawEncodePath(String path) => path
      .split('/')
      .map(Uri.encodeComponent)
      .join('/')
      .replaceAllMapped(_notRawUrlEncoded, (m) => _percent(m[0]!));

  static final RegExp _notRawUrlEncoded = RegExp(r"[!*'()]");

  static String _percent(String char) =>
      '%${char.codeUnitAt(0).toRadixString(16).toUpperCase()}';

  /// `stored_file_exporter` 組網址時第七個引數寫死 true
  /// （`make_pluginfile_url($…, $forcedownload = true)`），所以
  /// `messageinlinefiles[].url` 一定帶著 `?forcedownload=1`。比對與顯示都要
  /// 先切掉——留著就沒有一個尾巴對得上，整套改寫會靜靜地什麼都不做。
  static String _withoutQuery(String url) {
    final cut = url.indexOf(_queryOrFragment);
    return cut < 0 ? url : url.substring(0, cut);
  }

  static final RegExp _queryOrFragment = RegExp(r'[?#]');

  /// 檔案服務程式那一段。`tokenpluginfile.php` 的 key 只到下一個 `/`。
  static final RegExp _fileScript =
      RegExp(r'/tokenpluginfile\.php/[^/?#]+|/(?:webservice/)?pluginfile\.php');

  /// HTML 屬性裡的一個絕對網址；引號、空白與 `<>` 是邊界。
  static final RegExp _absoluteUrl = RegExp(r'''https?://[^\s"'<>]+''');

  /// `tokenpluginfile.php` 也含這一段，一句比對就認得出三種寫法。
  static const String _pluginFileMarker = 'pluginfile.php';

  static final RegExp _tokenParam = RegExp(r'[?&]token=');

  /// 存檔前最後一道關卡：回第一個不該出現的片段，乾淨時回 null。
  /// **非 null 一定要中止存檔**，不可以就地清掉再送。
  ///
  /// 為什麼一定要有：編輯器要顯示內嵌圖片就得讓 `<img src>` 帶著憑證
  /// （`?token=<wsToken>` 或 `/tokenpluginfile.php/<accesskey>/`）。只要有一張
  /// 圖沒有被換回去，那個網址就會被寫進一則同學都看得到的貼文，等於把使用者的
  /// web service token 公開。
  ///
  /// [inlineTails] 是**這一篇**內嵌檔案的識別片段（[inlineTailsOf]）。沒帶憑證
  /// 的 pluginfile 網址只有落在這份名單裡才算違規——它不是外洩，是「這張圖沒換
  /// 成功」：存進去之後伺服器不會再改寫它，`webservice/pluginfile.php` 對沒有
  /// token 的網頁版是 404，圖片會永久壞掉。
  ///
  /// **不可以擋掉站台上所有的 pluginfile 網址，也不可以擋掉 `token=` 這四個
  /// 字。** 貼文裡常常有從課程頁複製過來的絕對檔案網址（別的 filearea，永遠
  /// 不會出現在內嵌清單裡），而談 API token 的貼文本來就會寫 `token=`；把它們
  /// 一起擋掉，就是把「請去網頁編輯」那條死路原封不動搬到儲存鈕上。
  static String? tokenLeakIn(
    String html, {
    required String host,
    required String? wsToken,
    String? accessKey,
    Iterable<String> inlineTails = const [],
  }) {
    if (html.isEmpty) return null;
    final token = wsToken ?? '';
    if (token.isNotEmpty && html.contains(token)) return token;
    final key = accessKey ?? '';
    if (key.isNotEmpty && html.contains(key)) return key;

    final bare = Uri.tryParse(host)?.host ?? '';
    if (bare.isNotEmpty) {
      final siteUrl =
          RegExp('https?://${RegExp.escape(bare)}' r'''[^\s"'<>]*''');
      for (final m in siteUrl.allMatches(html)) {
        final url = m.group(0)!;
        if (!url.contains(_pluginFileMarker)) continue;
        // 換過 token 之後舊的那一把比對不到，但 query 還在。
        if (url.contains('/tokenpluginfile.php/') ||
            _tokenParam.hasMatch(url)) {
          return url;
        }
      }
    }
    for (final tail in inlineTails) {
      if (tail.isNotEmpty && html.contains(tail)) return tail;
    }
    return null;
  }
}
