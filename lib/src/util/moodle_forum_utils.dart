import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_discussion_posts.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions.dart';

/// 攤平後的一則貼文與它的縮排層級。
class ThreadPost {
  const ThreadPost(this.post, this.depth);

  final MoodleForumPost post;
  final int depth;
}

/// 討論串的純函式：攤平、內嵌檔案還原與退路貼文。不碰 R.current 也不碰時鐘。
class MoodleForumUtils {
  MoodleForumUtils._();

  static const String pluginFileToken = '@@PLUGINFILE@@';

  /// 標題的長度上限。`forum_discussions.name` 與 `forum_posts.subject` 都是
  /// varchar(255)，而兩支寫入函式都沒有截斷——超過就是 dmlwriteexception，
  /// 對應不到任何 forum errorcode，畫面只能說一句通用的送出失敗。
  static const int subjectMaxLength = 255;

  /// post_exporter 不跑 format_text，訊息裡的 `@@PLUGINFILE@@` 原封不動送回來；
  /// 檔案的 url 是 `<前綴><filepath><filename>`，佔位字串代表的就是那個前綴。
  static String resolveInlinePluginFiles(
      String message, List<MoodleForumFile> files) {
    if (!message.contains(pluginFileToken)) return message;
    for (final f in files) {
      final base = _pluginFileBase(f);
      if (base != null) return message.replaceAll(pluginFileToken, base);
    }
    return message;
  }

  static String? _pluginFileBase(MoodleForumFile f) {
    final raw = '${f.filepath}${f.filename}';
    if (raw.isEmpty || f.url.isEmpty) return null;
    // `stored_file_exporter` 組網址時第七個引數寫死 true
    // （`make_pluginfile_url($…, $forcedownload = true)`），所以這裡的 url
    // 一定以 `?forcedownload=1` 結尾。不先切掉，三種寫法沒有一個對得上，
    // `@@PLUGINFILE@@` 會原封不動留在畫面上。
    final path = _withoutQuery(f.url);
    for (final suffix in [raw, _encodePath(raw), _rawEncodePath(raw)]) {
      if (path.endsWith(suffix)) {
        return path.substring(0, path.length - suffix.length);
      }
    }
    return null;
  }

  static String _withoutQuery(String url) {
    final cut = url.indexOf(_queryOrFragment);
    return cut < 0 ? url : url.substring(0, cut);
  }

  static final RegExp _queryOrFragment = RegExp(r'[?#]');

  /// 逐段 encode，`/` 留著當分隔符。
  static String _encodePath(String path) =>
      path.split('/').map(Uri.encodeComponent).join('/');

  /// 伺服器那邊是 PHP `rawurlencode`，只留 `A-Za-z0-9-_.~`；Dart 的
  /// `encodeComponent` 還會留 `!*'()`，`Lecture (1).png` 這種檔名就對不起來。
  static final RegExp _notRawUrlEncoded = RegExp(r"[!*'()]");

  static String _rawEncodePath(String path) => _encodePath(path)
      .replaceAllMapped(_notRawUrlEncoded, (m) => _percent(m[0]!));

  static String _percent(String char) =>
      '%${char.codeUnitAt(0).toRadixString(16).toUpperCase()}';

  /// 依 parentid 攤平成「深度優先、同層照伺服器順序」的串。
  /// 找不到父貼文的（私訊回覆被濾掉時會發生）當成根，接在後面；
  /// visited 擋住互指的父子關係，最後再補走沒走到的，一篇都不會掉。
  static List<ThreadPost> buildThread(List<MoodleForumPost> posts) {
    final byId = {for (final p in posts) p.id: p};
    final children = <int, List<MoodleForumPost>>{};
    final roots = <MoodleForumPost>[];
    for (final p in posts) {
      final parent = p.parentid;
      if (!p.hasparent || parent == null || !byId.containsKey(parent)) {
        roots.add(p);
      } else {
        children.putIfAbsent(parent, () => []).add(p);
      }
    }

    final visited = <int>{};
    final flat = <ThreadPost>[];
    void walk(MoodleForumPost p, int depth) {
      if (!visited.add(p.id)) return;
      flat.add(ThreadPost(p, depth));
      for (final c in children[p.id] ?? const <MoodleForumPost>[]) {
        walk(c, depth + 1);
      }
    }

    for (final r in roots) {
      walk(r, 0);
    }
    // 全部互指成環時一個根都挑不出來，補走剩下的，免得整串貼文憑空消失。
    for (final p in posts) {
      walk(p, 0);
    }
    return flat;
  }

  /// 純文字 → HTML。escape 五個字元後把換行換成 `<br>`。
  ///
  /// 兩條路用得到：顯示 FORMAT_PLAIN 的貼文（[messageToDisplayHtml]），以及
  /// 純文字編輯器送回伺服器的內文（`MoodleForumEditUtils.plainEditPayload`）。
  /// 少了這一步，手機上打的多行文字會變成一整段，而 `a < b` 會被
  /// HTMLPurifier 吃掉。
  static String plainTextToHtml(String text) {
    final escaped = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
    return escaped
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\n', '<br>');
  }

  static const int formatMoodle = 0;
  static const int formatHtml = 1;
  static const int formatPlain = 2;
  static const int formatMarkdown = 4;

  /// 伺服器存的 `message` + `messageformat` → 可以直接餵給 HtmlWidget 的 HTML。
  ///
  /// `topreferredformat` 只在站台的預設編輯器是 TinyMCE/Atto 時才會把
  /// FORMAT_PLAIN 轉成 HTML；預設編輯器是 textarea 的站台會原樣存成
  /// FORMAT_PLAIN，那時要靠這裡轉，否則整篇擠成一行。
  static String messageToDisplayHtml(String message, int format) =>
      switch (format) {
        formatPlain => plainTextToHtml(message),
        // text_to_html() 只做 nl2br，不 escape——照抄它，不要多做。
        formatMoodle => message
            .replaceAll('\r\n', '\n')
            .replaceAll('\r', '\n')
            .replaceAll('\n', '<br>'),
        _ => message,
      };

  /// 這一篇能不能回覆。`capabilities` 是 null（舊快取／站台沒回）時一律不行：
  /// 不知道就不要給一顆按下去才失敗的鈕。
  static bool canReply(MoodleForumPost p) =>
      p.capabilities?.reply == true && !p.isdeleted;

  /// 把剛送出的貼文併進手上的清單：同 id 就地取代，否則接在最後。
  /// 送出成功但重抓失敗時用，`buildThread` 之後會依 parentid 掛回父貼文底下。
  static List<MoodleForumPost> mergePost(
      List<MoodleForumPost> posts, MoodleForumPost added) {
    final merged = [...posts];
    final index = merged.indexWhere((p) => p.id == added.id);
    if (index >= 0) {
      merged[index] = added;
    } else {
      merged.add(added);
    }
    return merged;
  }

  /// 抓不到回覆時的退路：討論串清單那一列本身就是第一篇貼文。
  /// 它的 message 已經過 format_text，不需要再換 `@@PLUGINFILE@@`。
  static MoodleForumPost rootPostOf(Discussions d) => MoodleForumPost(
        id: d.id,
        subject: d.subject,
        message: d.message,
        discussionid: d.discussion,
        hasparent: false,
        timecreated: d.created,
        timemodified: d.modified,
        author: MoodleForumAuthor(fullname: d.userfullname),
        attachments: [
          for (final a in d.attachments)
            MoodleForumFile(filename: a.filename, url: a.fileurl),
        ],
      );
}
