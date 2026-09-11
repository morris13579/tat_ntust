import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_discussion_posts.dart';
import 'package:flutter_app/src/util/moodle_forum_utils.dart';

/// 傳一個附件的哪一段。上傳可以取消（伺服器上什麼都還沒動），送出不行
/// （`add_discussion_post` / `update_discussion_post` 都沒有冪等鍵）。
enum ForumTransferPhase { upload, posting }

/// 附件傳輸的進度。帶著檔名是因為 repository 才知道現在在處理哪一個。
///
/// 刻意不重用 `moodle_assign_submit_utils.dart` 的 `AssignTransferProgress`：
/// 那是 util → util 的橫向 import，而且論壇這條路**永遠不需要「下載再重傳」**
/// （既有附件靠 `prepare_draft_area_for_post` 的 `filestokeep` 留在伺服器端），
/// 兩者的 phase 語意不同。二十行的重複換一條乾淨的邊。
class ForumTransferProgress {
  const ForumTransferProgress({
    required this.done,
    required this.total,
    required this.ratio,
    required this.phase,
    this.filename,
  });

  final int done;
  final int total;

  /// 這一個檔案的 0..1。
  final double ratio;

  final ForumTransferPhase phase;

  final String? filename;

  /// 整體的 0..1；[total] 為 0 時是 null（沒有東西可以量）。
  double? get overall => total <= 0 ? null : (done + ratio) / total;
}

/// 一個討論區的附件政策。三個來源 AND 起來的結論，不是原始欄位。
class ForumAttachPolicy {
  const ForumAttachPolicy({
    required this.enabled,
    required this.maxFiles,
    required this.maxBytes,
  });

  /// 不知道就是不給：問不到 forum record、站台關掉 upload.php、
  /// `cancreateattachment` 缺席，全部走這一個。
  const ForumAttachPolicy.off()
      : enabled = false,
        maxFiles = 0,
        maxBytes = 0;

  /// 站台 `uploadfiles == 1` ∧ `cancreateattachment` ∧ `maxattachments > 0`
  /// ∧ `maxbytes != 1`。
  final bool enabled;

  final int maxFiles;

  /// 0 ＝不知道／不限。
  final int maxBytes;
}

/// 帶附件的回覆送出去之後的結果。[warning] 非 null 代表**貼文真的發出去了**，
/// 但有東西不如預期（多半是附件被伺服器靜靜丟掉）——不可以報成失敗，也不可以
/// 裝作全部都上去了。
class ForumReplyOutcome {
  const ForumReplyOutcome(this.post, {this.warning});

  final MoodleForumPost post;
  final String? warning;
}

/// 編輯送出去之後的結果。語意同 [ForumReplyOutcome]：[warning] 非 null 代表
/// **更新真的發生了**，只是附件那邊有話要說。
///
/// 刻意不帶更新後的貼文：`update_discussion_post` 的回傳只有 `status`，
/// 而重讀那一趟拿到的是原文（`ForumPostEdit`），不能拿去覆蓋畫面上算繪好的
/// 版本——呼叫端一律重載整串。
class ForumEditOutcome {
  const ForumEditOutcome({this.warning});

  final String? warning;
}

/// 編輯頁需要的那幾格，由 `MoodleWebApiConnector.getPostForEdit` 回傳。
///
/// **刻意不是 `MoodleForumPost`**：[rawMessage] 是資料庫裡的**原文**（含
/// `@@PLUGINFILE@@`）、[rawFormat] 是它真正的 messageformat，一旦包成
/// `MoodleForumPost` 就會有人拿去正規化或寫進 `cache_moodle_forum_posts`，
/// 那會把原文換成算繪好的 HTML 再存起來。用一個不同的型別讓這件事在型別上
/// 不可能發生。
typedef ForumPostEdit = ({
  int id,
  String subject,
  String rawMessage,
  int rawFormat,
  bool canEdit,
  List<MoodleForumFile> attachments,
});

/// 按下編輯時要開哪一種編輯器。
///
/// 三種都是真的能編輯，沒有一條是死路：
/// - [plainText]：純文字框（`CourseForumComposePage.edit`）。
/// - [rawSource]：同一個純文字框，但內容是**原始碼本身**。FORMAT_MARKDOWN
///   走這一條——Moodle 自己的 Markdown 編輯器就是一個純 textarea。
/// - [rich]：所見即所得（`CourseForumRichEditPage`）。
enum ForumEditorKind { plainText, rawSource, rich }

/// 編輯與附件那條路的純函式。不 import connector、不碰 `R.current`、不碰時鐘。
///
/// 為什麼另開一檔而不是塞進 `moodle_forum_utils.dart`：那一支已經 169 行，
/// 而且它是「讀」那條路的（攤平、內嵌檔案還原）；這裡全部是「寫」的判斷。
class MoodleForumEditUtils {
  MoodleForumEditUtils._();

  /// 這篇貼文適不適合用純文字框編輯。**只在 [editorKindFor] 裡被呼叫。**
  ///
  /// 這是「開哪一種編輯器」的判斷，不是「能不能編輯」：判 false 的
  /// FORMAT_HTML 貼文走所見即所得編輯器，不會再被擋下來。所以這裡寧可保守，
  /// 誤判成 false 只是多開一個功能更全的編輯器。
  ///
  /// **但 false 不等於 rich**：FORMAT_MARKDOWN 也會拿到 false，而拿 HTML
  /// 編輯器去開 Markdown 原始碼再以 HTML 存回去是救不回來的。那一格由
  /// [editorKindFor] 擋著。
  ///
  /// 不送 `inlineattachmentsid` 時 `update_discussion_post` 的
  /// `$updatepost->itemid` 是 `IGNORE_FILE_MERGE`，`file_save_draft_area_files()`
  /// 直接 early return，既有內嵌檔案動都不會動——所以覆蓋原文不會弄出孤兒檔。
  ///
  /// FORMAT_PLAIN / FORMAT_MOODLE 一律適合（伺服器存的就是純文字）。
  /// FORMAT_HTML 要求：不含 `@@PLUGINFILE@@`、不含 `<img`，而且
  /// `plainTextToHtml(htmlToPlain(raw))` 正規化後等於 `raw`。
  static bool isPlainRoundTrip(String rawMessage, int rawFormat) {
    if (rawFormat == MoodleForumUtils.formatPlain ||
        rawFormat == MoodleForumUtils.formatMoodle) {
      return true;
    }
    if (rawFormat != MoodleForumUtils.formatHtml) return false;
    final lower = rawMessage.toLowerCase();
    if (lower.contains('@@pluginfile@@') || lower.contains('<img')) {
      return false;
    }
    final canonical = _canonical(rawMessage);
    return MoodleForumUtils.plainTextToHtml(htmlToPlain(canonical)) ==
        canonical;
  }

  /// 比對前把兩邊拉到同一種寫法。伺服器不管走 `format_text(FORMAT_PLAIN)` 的
  /// `nl2br` 還是 HTMLPurifier（XHTML 1.0 Transitional）都吐 `<br />`，而
  /// [MoodleForumUtils.plainTextToHtml] 產的是 `<br>`；單引號同理，PHP `s()`
  /// 是 ENT_QUOTES 的 `&#039;`，我們產的是 `&#39;`。少了這一步，**任何多行或
  /// 含單引號的貼文**——包含 App 自己幾秒鐘前發出去的那則——都會被判成不適合。
  static String _canonical(String html) => _normalizeNewlines(html)
      .replaceAll(_brTag, '<br>')
      .replaceAll('&#039;', '&#39;');

  /// [MoodleForumUtils.plainTextToHtml] 的反向：`<br>`／`<br />` → 換行、
  /// 反解那五個實體（單引號兩種寫法都要）。
  ///
  /// **不要改用 `MoodleAssignSubmitUtils.htmlToPlain`**：那是 util → util 的
  /// 橫向 import，而且它為 onlinetext 的 `<p>` 語意調過（`</p>` 變成兩個換行），
  /// 拿來做這裡的 round-trip 判斷會把不安全的內容判成安全。
  ///
  /// `&amp;` 一定要最後解：先解它的話使用者打的 `&lt;` 會被還原成 `<`。
  static String htmlToPlain(String html) {
    if (html.isEmpty) return '';
    return _normalizeNewlines(html)
        .replaceAll(_brTag, '\n')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&');
  }

  static final RegExp _brTag = RegExp(r'<br\s*/?>', caseSensitive: false);

  static String _normalizeNewlines(String text) =>
      text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  /// 純文字框的內容 → 送回伺服器的 `(message, messageformat)`。
  ///
  /// **原文是 FORMAT_HTML 就要先轉成 HTML 再送。** 直接把純文字配
  /// FORMAT_HTML 送出去，換行會被 HTML 吃掉；而配 FORMAT_PLAIN 送則會把這篇
  /// 貼文永久降級成純文字——`update_discussion_post` 不吃 `topreferredformat`
  /// （見 `MoodleWebApiConnector.updateDiscussionPost`），之後救不回來。
  static ({String message, int format}) plainEditPayload(
          String plainText, int rawFormat) =>
      rawFormat == MoodleForumUtils.formatHtml
          ? (
              message: MoodleForumUtils.plainTextToHtml(plainText),
              format: rawFormat
            )
          : (message: plainText, format: rawFormat);

  /// 這一篇底下有沒有回覆（遞迴，由 `parentid` 推）。
  ///
  /// **會少算**：伺服器端 `delete_post` 算的是
  /// `get_reply_count_for_post_id_in_discussion_id(..., $canseeprivatereplies = true)`
  /// ——第四個參數寫死 true，把學生看不到、也不在 `get_discussion_posts` 回應
  /// 裡的私訊回覆一起數。所以這裡只能當 UI 提示（把刪除項改成停用＋一句理由），
  /// 伺服器的 `couldnotdeletereplies` 才是答案。
  static bool hasVisibleReplies(List<MoodleForumPost> posts, int postId) {
    for (final p in posts) {
      if (p.id != postId && p.parentid == postId) return true;
    }
    return false;
  }

  /// 單一附件的有效位元組上限，取正值中的最小；一個都沒有就回 0（不限／不知道）。
  ///
  /// [siteMax] 是 `site_info.usermaxuploadfilesize`，`-1` 是
  /// `USER_CAN_IGNORE_FILE_SIZE_LIMITS`（不限），與 0 一樣不參與比較。
  /// [forumMax] 是 `forum.maxbytes`（0 ＝用課程／站台預設）。
  /// [areaMax] 是 `prepare_draft_area_for_post` 的 `areaoptions.maxbytes`
  /// ——**伺服器解析過、含課程層級的真值**，編輯路徑一定要優先用它；
  /// 新增路徑拿不到，只能用前兩者的近似值（`$COURSE->maxbytes` 沒有 API）。
  static int effectiveMaxBytes({
    required int siteMax,
    required int forumMax,
    int areaMax = 0,
  }) {
    var best = 0;
    for (final candidate in [siteMax, forumMax, areaMax]) {
      if (candidate <= 0) continue;
      if (best == 0 || candidate < best) best = candidate;
    }
    return best;
  }

  /// [maxBytes] <= 0（不知道）時一律不擋——由伺服器自己回答。
  static bool exceedsSize(int bytes, int maxBytes) =>
      maxBytes > 0 && bytes > maxBytes;

  /// 檔案數超過上限了嗎。[maxFiles] <= 0 時不擋（政策已經把 0 當成不給附件）。
  static bool exceedsCount(int count, int maxFiles) =>
      maxFiles > 0 && count > maxFiles;

  /// 第一個重複的檔名，沒有重複回 null。大小寫視為相同：`upload.php` 的比對
  /// 是精確的，但 `clean_param` 會改寫檔名，寧可保守。
  ///
  /// 編輯路徑要跨「保留的既有附件」與「新挑的檔案」兩份清單一起檢查：
  /// 既有附件被 `prepare_draft_area_for_post` 種進 draft 區之後，再上傳一個
  /// 同名的新檔案會回 `filenameexist`，而那時 draft 區已經是半套的。
  static String? duplicateFilename(List<String> filenames) {
    final seen = <String>{};
    for (final name in filenames) {
      if (!seen.add(name.toLowerCase())) return name;
    }
    return null;
  }

  /// 送出去的檔名裡，伺服器沒有收下的那些。
  ///
  /// 這是「附件靜默丟掉」唯一可靠的一層防線：沒有 `mod/forum:createattachment`
  /// 時 `attachmentsid` 被靜靜改成 0，超過 `maxbytes` / `maxfiles` 的檔案在
  /// `file_save_draft_area_files` 的迴圈裡是 `continue`——兩種情形伺服器都
  /// **不回任何 warning**，寫入照樣成功。
  static List<String> missingAttachments(
      List<String> sent, List<MoodleForumFile> got) {
    final received = {for (final f in got) f.filename.toLowerCase()};
    return [
      for (final name in sent)
        if (!received.contains(name.toLowerCase())) name,
    ];
  }

  /// 這一篇要開哪一種編輯器。**這是這個功能唯一的守門。**
  ///
  /// FORMAT_HTML 之外一律不給所見即所得：`isPlainRoundTrip` 對
  /// FORMAT_MARKDOWN（4）與任何未知格式都回 false，若直接把 false 當成
  /// 「開 rich」，Markdown 原始碼會被塞進 HTML 編輯器，存回去時再宣告成
  /// FORMAT_HTML——`update_discussion_post` 不吃 `topreferredformat`，
  /// 這一步之後救不回來。
  static ForumEditorKind editorKindFor(String rawMessage, int rawFormat) {
    if (rawFormat == MoodleForumUtils.formatPlain ||
        rawFormat == MoodleForumUtils.formatMoodle) {
      return ForumEditorKind.plainText;
    }
    if (rawFormat != MoodleForumUtils.formatHtml) {
      return ForumEditorKind.rawSource;
    }
    return isPlainRoundTrip(rawMessage, rawFormat)
        ? ForumEditorKind.plainText
        : ForumEditorKind.rich;
  }

  /// 純文字框要預填的字。
  ///
  /// **只有 FORMAT_HTML 才可以還原成純文字。** 其他格式伺服器存的本來就是
  /// 原始文字，再過一次 [htmlToPlain] 會把使用者真的打的 `a &amp; b` 悄悄
  /// 改成 `a & b`——[plainEditPayload] 對非 HTML 是原樣送回，於是這一次編輯
  /// 就把貼文改掉了，而使用者一個鍵都沒按。
  static String initialTextFor(String rawMessage, int rawFormat) =>
      rawFormat == MoodleForumUtils.formatHtml
          ? htmlToPlain(rawMessage)
          : rawMessage;

  /// 路徑的最後一段。挑檔回來的是完整路徑，送出去與畫面上要的是檔名。
  static String basename(String path) {
    final index = path.lastIndexOf(RegExp(r'[/\\]'));
    return index < 0 ? path : path.substring(index + 1);
  }
}
