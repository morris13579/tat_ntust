import 'package:flutter_app/src/util/file_icon_table.dart';

/// 依檔名、MIME type 或 Moodle 的 modicon 網址決定檔案類型 icon，
/// 規則照 Moodle 官方 App 的 CoreMimetype（src/core/static/mimetype.ts）。
///
/// icon 檔在 assets/image/files/<名稱>.svg，取自 moodlehq/moodleapp
/// src/assets/img/files（Apache-2.0）的單色 SVG，用 svgTint 上色。
class FileIconUtils {
  FileIconUtils._();

  static const String assetDir = "assets/image/files";
  static const String unknown = "unknown";

  /// assets/image/files/ 裡實際存在的 icon。modicon 解析出的名稱要先過這一關：
  /// Moodle 4.0 以前的 f/avi-24、f/jpeg-24 這類舊名稱沒有對應檔案。
  static const Set<String> iconNames = {
    "archive",
    "audio",
    "calc",
    "chart",
    "database",
    "document",
    "draw",
    "eps",
    "epub",
    "flash",
    "gif",
    "h5p",
    "image",
    "impress",
    "isf",
    "markup",
    "math",
    "moodle",
    "oth",
    "pdf",
    "powerpoint",
    "psd",
    "publisher",
    "sourcecode",
    "spreadsheet",
    "text",
    unknown,
    "video",
    "writer",
  };

  static String assetPath(String iconName) => "$assetDir/$iconName.svg";

  /// 依序試 MIME type、檔名副檔名、modicon 網址，都查不到回 [unknown]。
  ///
  /// 官方 App 有 mimetype 就只看 mimetype；這裡在 mimetype 認不得
  /// （例如 application/octet-stream）時退回檔名，不直接畫問號。
  static String iconFor({
    String filename = "",
    String mimetype = "",
    String modicon = "",
  }) {
    return iconNameForMimetype(mimetype) ??
        iconNameForFilename(filename) ??
        iconNameFromModicon(modicon) ??
        unknown;
  }

  static String? iconNameForFilename(String filename) {
    final ext = extensionOf(filename);
    return ext == null ? null : iconNameForExtension(ext);
  }

  static String? iconNameForExtension(String extension) {
    final ext = cleanExtension(extension).toLowerCase();
    return ext.isEmpty ? null : FileIconTable.byExtension[ext];
  }

  /// `;` 之後的參數（codecs、charset）會先切掉。
  static String? iconNameForMimetype(String mimetype) {
    final type = mimetype.split(";").first.trim().toLowerCase();
    return type.isEmpty ? null : FileIconTable.byMimetype[type];
  }

  /// 最後一個點之後的部分，轉小寫；沒有副檔名回 null。
  static String? extensionOf(String filename) {
    final dot = filename.lastIndexOf(".");
    if (dot < 0) {
      return null;
    }
    final ext = cleanExtension(filename.substring(dot + 1)).toLowerCase();
    return ext.isEmpty ? null : ext;
  }

  /// 官方 App 的 cleanExtension：去掉 `?query`、`#anchor`、
  /// filepool 加的 `_<32 碼 hash>` 與開頭的點。
  static String cleanExtension(String extension) {
    var ext = extension;
    final query = ext.indexOf("?");
    if (query >= 0) {
      ext = ext.substring(0, query);
    }
    final anchor = ext.indexOf("#");
    if (anchor >= 0) {
      ext = ext.substring(0, anchor);
    }
    ext = ext.replaceFirst(RegExp(r"_.{32}$"), "");
    if (ext.startsWith(".")) {
      ext = ext.substring(1);
    }
    return ext;
  }

  /// 從 modicon 網址撈 icon 名稱，認得 `.../core/1700000000/f/pdf`、
  /// `.../f/pdf-24`、`...&image=f%2Fpdf-24`；不是檔案 icon 回 null。
  static String? iconNameFromModicon(String url) {
    final match =
        RegExp(r"(?:^|[/=])f(?:/|%2F)([A-Za-z0-9]+)", caseSensitive: false)
            .firstMatch(url);
    if (match == null) {
      return null;
    }
    final name = match.group(1)!.toLowerCase();
    return iconNames.contains(name) ? name : null;
  }
}
