import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';

/// 資料夾頁某一層的內容：先子資料夾、再檔案。
class MoodleFolderListing {
  const MoodleFolderListing({required this.folders, required this.files});

  final List<MoodleSubFolder> folders;
  final List<Contents> files;

  bool get isEmpty => folders.isEmpty && files.isEmpty;
}

/// 由 `contents[].filepath` 推出來的子資料夾。Moodle 只回檔案，
/// 空資料夾不會出現在回應裡，所以每一個子資料夾底下至少有一個檔案。
class MoodleSubFolder {
  const MoodleSubFolder({
    required this.name,
    required this.path,
    required this.fileCount,
  });

  final String name;

  /// 頭尾都有 '/' 的完整路徑，可直接餵回 [MoodleFolderUtils.listing]。
  final String path;

  /// 這一整個子樹底下的檔案數（含更深的層）。
  final int fileCount;
}

/// 把 `core_course_get_contents` 的平坦 `contents` 依 `filepath` 攤成一層一層。
///
/// 與官方 App（`AddonModFolderHelperProvider.formatContents`）刻意有兩點不同：
/// 一是這裡照名稱排序，不留伺服器的 `sortorder DESC, id ASC`；二是子資料夾路徑
/// 保留結尾斜線，可以直接餵回 [listing]。
class MoodleFolderUtils {
  MoodleFolderUtils._();

  static const String rootPath = '/';

  /// 取出 [path] 這一層的子資料夾與檔案。[path] 不存在時回空的 listing。
  static MoodleFolderListing listing(
    List<Contents> contents, {
    String path = rootPath,
  }) {
    final base = normalizePath(path);
    final counts = <String, int>{};
    final files = <(int, Contents)>[];
    for (var i = 0; i < contents.length; i++) {
      final p = normalizePath(contents[i].filepath);
      if (p == base) {
        files.add((i, contents[i]));
        continue;
      }
      if (!p.startsWith(base)) continue;
      final name = p.substring(base.length).split('/').first;
      if (name.isEmpty) continue;
      counts[name] = (counts[name] ?? 0) + 1;
    }

    final folders = counts.entries
        .map((e) => MoodleSubFolder(
              name: e.key,
              path: '$base${e.key}/',
              fileCount: e.value,
            ))
        .toList()
      ..sort((a, b) => compareNames(a.name, b.name));
    // 同名檔案用原始索引收尾，排序才不會隨輸入順序跳動。
    files.sort((a, b) {
      final c = compareNames(a.$2.filename, b.$2.filename);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });

    return MoodleFolderListing(
      folders: folders,
      files: files.map((e) => e.$2).toList(),
    );
  }

  /// url 這種非檔案項目的 filepath 是 null（模型收成空字串），當成根目錄。
  static String normalizePath(String filepath) {
    var p = filepath.replaceAll('\\', '/').replaceAll(RegExp(r'/+'), '/');
    if (!p.startsWith('/')) p = '/$p';
    if (!p.endsWith('/')) p = '$p/';
    return p;
  }

  /// '/a/b/' -> ['a', 'b']
  static List<String> segments(String path) => normalizePath(path)
      .split('/')
      .where((s) => s.isNotEmpty)
      .toList(growable: false);

  /// 大小寫不敏感、數字段落照數值比（week2 排在 week10 前面）。
  /// 不是 ICU 定序：中文只會照 Unicode 碼位，不是筆畫或拼音。
  static int compareNames(String a, String b) {
    final x = a.toLowerCase();
    final y = b.toLowerCase();
    var i = 0;
    var j = 0;
    while (i < x.length && j < y.length) {
      final cx = x.codeUnitAt(i);
      final cy = y.codeUnitAt(j);
      if (_isDigit(cx) && _isDigit(cy)) {
        var ei = i;
        while (ei < x.length && _isDigit(x.codeUnitAt(ei))) {
          ei++;
        }
        var ej = j;
        while (ej < y.length && _isDigit(y.codeUnitAt(ej))) {
          ej++;
        }
        final nx = int.tryParse(x.substring(i, ei)) ?? 0;
        final ny = int.tryParse(y.substring(j, ej)) ?? 0;
        if (nx != ny) return nx < ny ? -1 : 1;
        i = ei;
        j = ej;
        continue;
      }
      if (cx != cy) return cx < cy ? -1 : 1;
      i++;
      j++;
    }
    final rest = (x.length - i).compareTo(y.length - j);
    // 忽略大小寫後一模一樣時仍要有確定的順序。
    return rest != 0 ? rest : a.compareTo(b);
  }

  static bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;
}
