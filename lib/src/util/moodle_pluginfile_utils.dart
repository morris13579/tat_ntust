/// `pluginfile.php` 網址與 `@@PLUGINFILE@@` 之間那一段前綴的推導。
///
/// 不 import 任何東西：討論區與作業的檔案模型是兩個型別，共用的只有
/// 「filepath + filename 是網址的結尾」這一條事實，所以介面收 record。
class MoodlePluginFileUtils {
  MoodlePluginFileUtils._();

  static const String token = '@@PLUGINFILE@@';

  /// 同一個 filearea 底下所有檔案共用的網址前綴，推不出來回 null。
  ///
  /// 伺服器兩個方向都只是前綴的 `str_replace`（`file_rewrite_pluginfile_urls`），
  /// 檔名那一截從頭到尾原封不動——所以還原也只能是前綴比對，不能拿檔名去猜。
  ///
  /// 回傳值**不含結尾的 `/`**：`filepath` 本身以 `/` 開頭，那一槓算在被切掉的
  /// 後綴裡，於是 `前綴 == $baseurl 去掉結尾斜線`，正好對上不含斜線的 [token]。
  static String? baseOf(
      Iterable<({String filepath, String filename, String url})> files) {
    for (final f in files) {
      final raw = '${f.filepath}${f.filename}';
      if (raw.isEmpty || f.url.isEmpty) continue;
      // 有些 exporter 組網址時會帶 query（`stored_file_exporter` 寫死
      // `$forcedownload = true`），留著的話三種寫法一個都對不上。
      final path = _withoutQuery(f.url);
      for (final suffix in [raw, encodePath(raw), rawEncodePath(raw)]) {
        if (path.endsWith(suffix)) {
          return path.substring(0, path.length - suffix.length);
        }
      }
    }
    return null;
  }

  /// 逐段 encode，`/` 留著當分隔符。
  static String encodePath(String path) =>
      path.split('/').map(Uri.encodeComponent).join('/');

  /// 伺服器那邊是 PHP `rawurlencode`（`moodle_url::set_slashargument` 對每一
  /// 段呼叫），只留 `A-Za-z0-9-_.~`；Dart 的 `encodeComponent` 還會留
  /// `!*'()`，`Lecture (1).png` 這種檔名就對不起來。
  static String rawEncodePath(String path) => encodePath(path)
      .replaceAllMapped(_notRawUrlEncoded, (m) => _percent(m[0]!));

  static final RegExp _notRawUrlEncoded = RegExp(r"[!*'()]");

  static String _percent(String char) =>
      '%${char.codeUnitAt(0).toRadixString(16).toUpperCase()}';

  static String _withoutQuery(String url) {
    final cut = url.indexOf(_queryOrFragment);
    return cut < 0 ? url : url.substring(0, cut);
  }

  static final RegExp _queryOrFragment = RegExp(r'[?#]');
}
