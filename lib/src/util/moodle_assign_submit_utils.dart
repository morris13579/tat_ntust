import 'dart:io';

import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';
import 'package:flutter_app/src/util/moodle_assign_attempt_utils.dart';
import 'package:flutter_app/src/util/moodle_pluginfile_utils.dart';

/// 為什麼不能在 App 內交這份作業。null 代表可以交。
enum AssignSubmitBlock {
  /// `nosubmissions == 1`，離線評分。
  noSubmission,

  /// 有 file / onlinetext / comments 以外的繳交外掛。
  /// `assign::save_submission` 會對每一個 enabled 外掛都呼叫 save()，
  /// 而我們給不出那個外掛要的參數，也不知道它缺參數時會不會像 onlinetext
  /// 一樣把現有內容清掉。
  unsupportedPlugin,

  /// file 與 onlinetext 都沒開。
  noPlugin,

  /// 團隊作業但這位學生沒有被分到組。
  noGroup,

  /// 團隊作業但這位學生同時在多組，伺服器算不出要交給哪一組。
  multipleGroups,

  /// 伺服器說不能編輯：canedit / submissionsenabled / locked。
  closed,
}

/// 儲存鈕為什麼是 disabled。null = 可以存。
///
/// **作答時限到期不在這裡**：伺服器照收，只是標記成遲交
/// （`save_submission` / `submissions_open` 從頭到尾沒有檢查 timelimit，
/// 網頁的 timer.js 歸零時也只是換一行字）。本地擋下來就是把學生已經寫好的
/// 東西鎖死在畫面上，那是這條路上唯一會弄丟作業的失敗模式。
///
/// **「資料庫原文還沒到手」也不在這裡**：那是一趟幾百毫秒、而且重試就好的
/// 網路往返，做成 disabled 只會讓鈕閃一下又不給重試；改由
/// `CourseAssignSubmitController.save` 送出前自己再問一次。
enum AssignSaveBlock {
  filesEmptied,
  overWordLimit,
  statementNotAccepted,
  noChanges,
}

/// 一個檔案能不能收。[unverifiable] = `filetypeslist` 裡有我們看不懂的群組名。
enum FileTypeCheck { allowed, rejected, unverifiable }

/// 傳一個檔案的哪一段。要保留的舊檔案得先下載再重傳，兩段的文案不一樣——
/// 整段下載都說「正在上傳」是騙人的。
enum AssignTransferPhase { download, upload }

/// 建 draft 區的進度。帶著檔名是因為 repository 才知道現在在處理哪一個，
/// 由呼叫端拿索引去猜會在清單被改動時對錯。
class AssignTransferProgress {
  const AssignTransferProgress({
    required this.done,
    required this.total,
    required this.ratio,
    required this.phase,
    this.filename,
  });

  /// 已經完成的檔案數與總數。
  final int done;
  final int total;

  /// 這一個檔案的 0..1。
  final double ratio;

  final AssignTransferPhase phase;

  /// 這一刻在處理的檔名；全部做完時是 null。
  final String? filename;

  /// 整體的 0..1；[total] 為 0 時是 null（沒有東西可以量）。
  double? get overall => total <= 0 ? null : (done + ratio) / total;
}

/// 未經算繪的線上文字，由 `MoodleWebApiConnector.getOnlineTextForEdit` 回傳。
///
/// **刻意不是 `MoodleAssignSubmissionStatus`**：[rawText] 是資料庫原文
/// （含 `@@PLUGINFILE@@`），包成狀態物件就會有人拿去畫面上畫、或寫進
/// `cache_moodle_assign_status`——那一頁會把佔位字串當成圖片網址畫出破圖，
/// 而且是從快取來的，下次進來還是破的。用不同的型別讓它不可能發生。
typedef AssignOnlineTextEdit = ({
  String rawText,
  List<MoodleAssignFile> inlineFiles,
});

/// 編輯頁上的一份草稿；repository 與 UI 共用的值型別。
class AssignSubmissionDraft {
  const AssignSubmissionDraft({
    this.onlineText,
    this.files,
    this.submitForGrading = false,
    this.acceptStatement = false,
  });

  /// null **只有在這份作業沒開 onlinetext 外掛時才對**。
  ///
  /// 不送 `plugindata[onlinetext_editor]` 不是「保留現有文字」：
  /// `assign_submission_onlinetext::save()` 沒有 isset 把關，而
  /// `assign::save_submission` 會對每一個 enabled 外掛都呼叫 save()——
  /// 缺了這個鍵，`file_postupdate_standard_editor` 會拿到 null 覆蓋回去。
  /// 外掛開著就一定要送，沒動過也要把伺服器原本那一份原樣送回去。
  final String? onlineText;

  /// null = 不動檔案（伺服器保留繳交區現有的）。非 null 時約定必定非空，
  /// 而且必須是「繳交區最後應該長的樣子」的完整清單——`files_filemanager`
  /// 是同步不是附加，見 [MoodleAssignSubmitUtils]。
  final List<AssignDraftFile>? files;

  final bool submitForGrading;

  /// 只有使用者真的勾了才會是 true：那會在伺服器留下 statement_accepted 稽核事件。
  final bool acceptStatement;

  bool get isEmpty => onlineText == null && files == null;
}

/// 草稿清單裡的一個檔案：本機剛挑的，或伺服器上已經交過的。
sealed class AssignDraftFile {
  const AssignDraftFile();

  String get filename;
}

/// 使用者這次從裝置挑的檔案。
final class LocalDraftFile extends AssignDraftFile {
  const LocalDraftFile(this.file, this.filename, {this.size = 0});

  final File file;

  @override
  final String filename;

  /// 位元組；0 代表還沒量過。
  final int size;
}

/// 已經在繳交區裡的檔案。要保留它就得先下載再重傳，見 [MoodleAssignSubmitUtils]。
final class OnlineDraftFile extends AssignDraftFile {
  const OnlineDraftFile(this.filename, this.fileurl,
      {this.mimetype = '', this.filesize = 0});

  @override
  final String filename;

  final String fileurl;

  final String mimetype;

  /// 伺服器說的位元組數；0 = 這一筆沒帶（`external_files` 是 VALUE_OPTIONAL）。
  final int filesize;
}

/// 交作業那條路的純函式。不 import connector、不碰 R.current、不碰時鐘。
///
/// **`files_filemanager` 是同步不是附加**：`file_save_draft_area_files` 會把
/// 繳交區裡「不在這個 draft 區」的舊檔案 `delete()` 掉，而超過
/// `maxfilesubmissions` / `maxsubmissionsizebytes` 的檔案是靜靜 `continue`，
/// `save_submission` 照樣回 `[]`。所以清單沒變就完全不送，要送就送完整清單，
/// 而且大小與數量必須在本地先擋。
class MoodleAssignSubmitUtils {
  MoodleAssignSubmitUtils._();

  static const String subtypeSubmission = 'assignsubmission';
  static const String pluginFile = 'file';
  static const String pluginOnlineText = 'onlinetext';

  /// 只讀不寫的那一個：老師開了它我們也不用送任何 plugindata。
  static const String pluginComments = 'comments';

  /// App 送得出 plugindata 的繳交外掛。其餘一律導網頁，見
  /// [AssignSubmitBlock.unsupportedPlugin]。
  static const Set<String> supportedSubmissionPlugins = {
    pluginFile,
    pluginOnlineText,
    pluginComments,
  };

  /// 判定順序刻意固定：先講「這個功能不支援」，最後才講「伺服器不讓交」。
  ///
  /// [AssignSubmitBlock.noGroup] / [AssignSubmitBlock.multipleGroups] 排在
  /// [AssignSubmitBlock.closed] **前面**：沒被分到組的人 `canedit` 也是 false，
  /// 而「你還沒有被分到組別」是可以行動的，「不能交」不是。
  static AssignSubmitBlock? blockOf(
      MoodleAssignment a, MoodleAssignSubmissionStatus s) {
    if (a.noSubmissionRequired) return AssignSubmitBlock.noSubmission;
    if (hasUnsupportedPlugin(a)) return AssignSubmitBlock.unsupportedPlugin;
    if (!pluginEnabled(a, pluginFile) && !pluginEnabled(a, pluginOnlineText)) {
      return AssignSubmitBlock.noPlugin;
    }
    if (a.isTeamSubmission) {
      switch (MoodleAssignAttemptUtils.teamState(a, s)) {
        case AssignTeamState.noGroup:
          return AssignSubmitBlock.noGroup;
        case AssignTeamState.multipleGroups:
          return AssignSubmitBlock.multipleGroups;
        case AssignTeamState.notTeam:
        case AssignTeamState.ok:
          break;
      }
    }
    // lastattempt 缺席 = 沒有 viewownsubmissionsummary，什麼都不該顯示。
    if (s.lastattempt == null ||
        !s.submissionsEnabled ||
        s.isLocked ||
        !s.canEdit) {
      return AssignSubmitBlock.closed;
    }
    return null;
  }

  /// 有沒有我們送不出 plugindata 的繳交外掛（Turnitin、PoodLL……）。
  /// `configs[]` 只收錄 enabled 且 visible 的外掛，所以「有沒有這一列」就是答案。
  static bool hasUnsupportedPlugin(MoodleAssignment a) {
    for (final c in a.configs) {
      if (c.subtype != subtypeSubmission) continue;
      if (!supportedSubmissionPlugins.contains(c.plugin)) return true;
    }
    return false;
  }

  /// 儲存鈕為什麼不能按。判定順序刻意固定（同 [blockOf]）：先講結構上改不了的，
  /// 再講學生自己修得好的，最後才講最不緊張、也最不言而喻的「還沒改東西」。
  /// 只回第一個理由——列出全部會把動作列撐成四行，而常見的單一理由看起來
  /// 反而像出了大事。
  static AssignSaveBlock? saveBlockOf({
    required bool filesEmptied,
    required bool overWordLimit,
    required bool statementOk,
    required bool dirty,
  }) {
    if (filesEmptied) return AssignSaveBlock.filesEmptied;
    if (overWordLimit) return AssignSaveBlock.overWordLimit;
    if (!statementOk) return AssignSaveBlock.statementNotAccepted;
    if (!dirty) return AssignSaveBlock.noChanges;
    return null;
  }

  /// `configs[]` 裡的一個設定值，找不到回 null。只認 `assignsubmission`
  /// 子型別：`assignfeedback` 底下也有同名的 file 外掛。
  static String? configOf(MoodleAssignment a,
      {required String plugin, required String name}) {
    for (final c in a.configs) {
      if (c.subtype == subtypeSubmission &&
          c.plugin == plugin &&
          c.name == name) {
        return c.value;
      }
    }
    return null;
  }

  /// 這個繳交外掛有沒有開。`configs[]` 只收錄 enabled 且 visible 的外掛，
  /// 所以「有沒有任何一列」就是答案。
  static bool pluginEnabled(MoodleAssignment a, String plugin) {
    for (final c in a.configs) {
      if (c.subtype == subtypeSubmission && c.plugin == plugin) return true;
    }
    return false;
  }

  /// 最多幾個檔案。缺席退回 1（Moodle 的預設）。
  static int maxFiles(MoodleAssignment a) {
    final raw = configOf(a, plugin: pluginFile, name: 'maxfilesubmissions');
    final value = int.tryParse(raw ?? '') ?? 0;
    return value > 0 ? value : 1;
  }

  /// 單一檔案的位元組上限。0 = 未知，不擋（伺服器已把 0 解析成真的 bytes，
  /// 拿不到值時寧可讓伺服器自己回答）。
  static int maxBytes(MoodleAssignment a) {
    final raw = configOf(a, plugin: pluginFile, name: 'maxsubmissionsizebytes');
    final value = int.tryParse(raw ?? '') ?? 0;
    return value > 0 ? value : 0;
  }

  /// 允許的檔案類型，切開、去空白、小寫。空清單 = 不限。
  static List<String> fileTypes(MoodleAssignment a) {
    final raw = configOf(a, plugin: pluginFile, name: 'filetypeslist') ?? '';
    return [
      for (final part in raw.split(RegExp(r'[,;\s]+')))
        if (part.trim().isNotEmpty) part.trim().toLowerCase(),
    ];
  }

  /// 字數上限；`wordlimitenabled` 為假時回 0。
  static int wordLimit(MoodleAssignment a) {
    final enabled =
        configOf(a, plugin: pluginOnlineText, name: 'wordlimitenabled');
    if (enabled == null || enabled == '0' || enabled.isEmpty) return 0;
    final value = int.tryParse(
        configOf(a, plugin: pluginOnlineText, name: 'wordlimit') ?? '');
    return (value != null && value > 0) ? value : 0;
  }

  /// 字數。`check_word_count` 是伺服器唯一會擋下整趟 `save_submission` 的
  /// 內容限制，而它失敗時只回一句 `couldnotsavesubmission`——連「是字數超過」
  /// 都說不出來，所以只能在本地先算一次。
  ///
  /// 分隔符照 Moodle `count_words` 的 `~[\p{Z}\p{Cc}—–]+~u`：不加空白的中文
  /// 整段算一個字，跟伺服器同一套（用 `\s` 會多切出破折號兩側，在這裡算多了
  /// 就是把交得出去的作業擋下來）。算在純文字上，伺服器也是先 `content_to_text`。
  static int countWords(String plainText) =>
      plainText.split(_wordSeparator).where((w) => w.isNotEmpty).length;

  static final RegExp _wordSeparator =
      RegExp(r'[\p{Z}\p{Cc}—–]+', unicode: true);

  /// 這個檔名合不合 [types]。
  ///
  /// `filetypeslist` **伺服器端根本不驗**（`accepted_types` 只餵給網頁表單的
  /// filepicker），所以只有客戶端擋得住；但 Moodle 的群組名（`document`、
  /// `archive`、`web_image`）要整張 file types 表才解得開，遇到就整份降級成
  /// [FileTypeCheck.unverifiable]，只顯示原始字串不擋——寧可讓老師看到一個
  /// 格式不對的檔案，也不要讓學生交不出來。
  static FileTypeCheck checkFileType(String filename, List<String> types) {
    if (types.isEmpty) return FileTypeCheck.allowed;

    final name = filename.toLowerCase();
    final dot = name.lastIndexOf('.');
    final ext =
        dot >= 0 && dot < name.length - 1 ? name.substring(dot + 1) : '';

    var matched = false;
    var unverifiable = false;
    for (final type in types) {
      if (type.contains('/')) {
        if (_mimeMatches(ext, type)) matched = true;
        continue;
      }
      final bare = type.startsWith('.') ? type.substring(1) : type;
      if (_looksLikeExtension(type)) {
        if (bare.isNotEmpty && bare == ext) matched = true;
        continue;
      }
      // document / archive / web_image ……這一項無法判讀。
      unverifiable = true;
    }
    if (matched) return FileTypeCheck.allowed;
    if (unverifiable) return FileTypeCheck.unverifiable;
    return FileTypeCheck.rejected;
  }

  /// 只有帶 `.` 或純英數的短字串才當副檔名看；`document` 之類的群組名沒有
  /// 點、也不是我們認得的副檔名，交給呼叫端降級。
  static bool _looksLikeExtension(String type) {
    if (type.startsWith('.')) return true;
    return RegExp(r'^[a-z0-9]{1,5}$').hasMatch(type);
  }

  /// 只用副檔名推得出來的那幾種 mime；`image/*` 這種前綴也支援。
  static bool _mimeMatches(String ext, String mime) {
    final actual = _mimeOfExtension(ext);
    if (actual == null) return false;
    if (mime.endsWith('/*')) {
      return actual.startsWith(mime.substring(0, mime.length - 1));
    }
    return actual == mime;
  }

  static const Map<String, String> _mimeByExtension = {
    'pdf': 'application/pdf',
    'txt': 'text/plain',
    'csv': 'text/csv',
    'html': 'text/html',
    'htm': 'text/html',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'heic': 'image/heic',
    'zip': 'application/zip',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'mp4': 'video/mp4',
    'mp3': 'audio/mpeg',
  };

  static String? _mimeOfExtension(String ext) => _mimeByExtension[ext];

  /// [maxBytes] <= 0（未知）時一律回 false。
  static bool exceedsSize(int bytes, int maxBytes) =>
      maxBytes > 0 && bytes > maxBytes;

  /// 第一個重複的檔名，沒有重複回 null。大小寫視為相同：`upload.php` 的比對
  /// 是精確的，但 `clean_param` 會改寫檔名，寧可保守。
  static String? duplicateFilename(List<AssignDraftFile> files) {
    final seen = <String>{};
    for (final f in files) {
      final key = f.filename.toLowerCase();
      if (!seen.add(key)) return f.filename;
    }
    return null;
  }

  /// 純文字 → 送得出去的 HTML。空字串回空字串：包成 `<p></p>` 會讓伺服器的
  /// `new_submission_empty` 判斷失準。
  static String plainToHtml(String text) {
    if (text.isEmpty) return '';
    final escaped = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
    // 段落＝空行分隔；段落內的換行用 <br>。
    final paragraphs = escaped.replaceAll('\r\n', '\n').split('\n\n');
    return [
      for (final p in paragraphs) '<p>${p.replaceAll('\n', '<br>')}</p>',
    ].join();
  }

  /// `file_rewrite_pluginfile_urls` 的客戶端反向操作：把絕對網址換回
  /// `@@PLUGINFILE@@`，也就是資料庫裡原本的那個字串。
  ///
  /// 只跑在 `getOnlineTextForEdit` 拿回來的原文上，而且**每一次都要跑**：
  /// 送出的字串會被逐字寫進 `assignsubmission_onlinetext.onlinetext`
  /// （`empty($editor['itemid'])` 分支），一次把絕對網址存回去就再也救不
  /// 回來——之後不論用什麼設定重抓，拿到的都是那個網址，而
  /// `webservice/pluginfile.php` 要憑證，連瀏覽器看那份繳交都會壞掉。
  ///
  /// 對已經是 `@@PLUGINFILE@@` 的原文（raw 那一趟拿到的）是 identity：
  /// 前綴根本不在裡面。前綴含 `/{contextid}/assignsubmission_onlinetext/
  /// submissions_onlinetext/{submissionid}/`，所以指向別的地方的
  /// pluginfile 網址動都不會動。
  static String restorePluginfileUrls(
      String html, List<MoodleAssignFile> inlineFiles) {
    if (html.isEmpty || inlineFiles.isEmpty) return html;
    final base = MoodlePluginFileUtils.baseOf([
      for (final f in inlineFiles)
        (filepath: f.filepath, filename: f.filename, url: f.fileurl),
    ]);
    if (base == null || base.isEmpty) return html;
    return html.replaceAll(base, MoodlePluginFileUtils.token);
  }

  /// 反向，只給編輯框當初值用。
  static String htmlToPlain(String html) {
    if (html.isEmpty) return '';
    var text = html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'</div\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '');
    text = text
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&');
    // 尾端那個 </p> 產生的空行不是內容。
    return text.replaceFirst(RegExp(r'\n+$'), '');
  }

  /// 現有的線上文字適不適合用純文字框編輯——**這是「開哪一種編輯器」的判斷，
  /// 不是「能不能存檔」**。判 false 就走所見即所得編輯器。
  ///
  /// 因果不要寫反：`onlinetext_editor.itemid` 送 0 會讓
  /// `file_postupdate_standard_editor()` 走 `empty($editor['itemid'])` 分支，
  /// **跳過 draft 同步正是既有內嵌圖片活下來的原因**；真正會殺檔案的是送一個
  /// 非 0、內容不完整的 draft itemid。官方 App 也是送 0
  /// （`handler.ts`：`itemid: 0, // Can't add new files yet`）。
  static bool onlineTextIsPlain(String html) {
    if (html.isEmpty) return true;
    final lower = html.toLowerCase();
    for (final marker in const [
      '<img',
      '<video',
      '<audio',
      '<iframe',
      '<object',
      '<embed',
      '@@pluginfile@@',
      'pluginfile.php',
    ]) {
      if (lower.contains(marker)) return false;
    }
    return true;
  }

  /// 送出的清單跟伺服器上的一樣嗎——一樣就不要送 `files_filemanager`。
  /// 順序不同也算有變：重排要重傳才會是使用者看到的順序。
  static bool fileListChanged(
      List<AssignDraftFile> draft, List<MoodleAssignFile> current) {
    if (draft.length != current.length) return true;
    for (var i = 0; i < draft.length; i++) {
      final d = draft[i];
      // 本機檔案一定要重傳，即使名字對得上。
      if (d is! OnlineDraftFile) return true;
      if (d.filename != current[i].filename) return true;
      if (d.fileurl != current[i].fileurl) return true;
    }
    return false;
  }
}
