import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/util/file_icon_utils.dart';
import 'package:flutter_app/src/util/file_utils.dart';
import 'package:intl/intl.dart';

/// 課程內容的一段（Moodle 的 section）加上解析結果。
///
/// 週次格式的課程，section 的 `name` 就是日期區間（「09月 7 日 - 09月 13 日」），
/// 主題式的課程則是主題名（「課程教材」）。兩種格式差在能不能把 `name` 解析成
/// 日期區間，所以判斷格式不需要另一支 API。
class CourseSection {
  CourseSection._(this.raw, this.start, this.end);

  factory CourseSection.of(MoodleCoreCourseGetContents raw) {
    final range = _parseRange(raw.name);
    return CourseSection._(raw, range?.$1, range?.$2);
  }

  final MoodleCoreCourseGetContents raw;

  /// 只有解析得出日期區間的段才有；「一般」那一段永遠是 null。
  final DateTime? start;
  final DateTime? end;

  bool get isWeek => start != null && end != null;

  /// 標題。日期區間重新格式化過，Moodle 回來的字串在不同站台空格數不一樣。
  String get title {
    if (!isWeek) return raw.name;
    // 每次現做：DateFormat 讀的是 Intl.defaultLocale，存成靜態欄位的話
    // 切語言之後週次標題會停在舊語系。
    final format = DateFormat.MMMd();
    return '${format.format(start!)} – ${format.format(end!)}';
  }

  List<Modules> get modules => raw.modules;

  /// 這一段有幾個真的下載得到的檔案。
  ///
  /// 沒有 contents 的 resource 算 0：那是老師開了一列卻沒上傳東西
  /// （fixture 裡的「尚未上傳的檔案」），點下去只會吐「沒有任何資料」。
  /// 附檔跟主檔一起回來時只算一列，因為清單上就是一列。
  ///
  /// url 不算：它的 contents 是 type: "url" 的外部連結而不是檔案，NTUST 的
  /// 「課程錄影」整段都是這種，算進去整段就變成「有檔案」。討論區、作業、
  /// 測驗、標籤同樣不算——分組要回答的問題是「這一段有沒有東西可以下載」。
  int get fileCount => raw.modules.fold(0, (sum, m) {
        switch (m.modname) {
          case 'resource':
            return sum + (m.contents.isEmpty ? 0 : 1);
          case 'folder':
            return sum + m.contents.length;
          default:
            return sum;
        }
      });

  bool get hasFiles => fileCount > 0;

  /// 這一段有沒有東西。**分組看的是這個、不是 [fileCount]**：作業、測驗、
  /// 討論區與外部連結都是這一週的內容，被收進「沒有內容的週次」裡，使用者
  /// 展開就會發現裡面明明有東西。
  bool get hasContent => raw.modules.isNotEmpty;

  /// 卡片第二行。Moodle 的 summary 是 HTML，這裡只取文字。
  String? get summaryText {
    final plain = raw.summary
        .replaceAll(_brTag, ' ')
        .replaceAll(_htmlTag, '')
        .replaceAll(_nbsp, ' ')
        .replaceAll(_whitespace, ' ')
        .trim();
    return plain.isEmpty ? null : plain;
  }

  /// 今天是不是落在這一段裡。年份 Moodle 不給，用當年推；區間跨年（12 月底到
  /// 1 月初）時把結束日往後挪一年，跨年那一週才不會算成「結束早於開始」。
  bool containsToday([DateTime? now]) {
    if (!isWeek) return false;
    final today = _dateOnly(now ?? DateTime.now());
    final from = DateTime(today.year, start!.month, start!.day);
    var to = DateTime(today.year, end!.month, end!.day);
    if (to.isBefore(from)) to = DateTime(today.year + 1, end!.month, end!.day);
    return !today.isBefore(from) && !today.isAfter(to);
  }

  /// 檔名或模組名稱裡有沒有這段字。空字串一律 true，呼叫端就不必先判斷。
  static bool moduleMatches(Modules module, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    if (module.name.toLowerCase().contains(needle)) return true;
    return module.contents
        .any((c) => c.filename.toLowerCase().contains(needle));
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 「09月 7 日 - 09月 13 日」與「9/7 - 9/13」都收。抓到剛好兩組月日才算數，
  /// 主題名稱裡出現一個日期不該被當成週次。
  static (DateTime, DateTime)? _parseRange(String name) {
    for (final pattern in [_cjkDate, _slashDate]) {
      final found = pattern.allMatches(name).toList();
      if (found.length != 2) continue;
      final parts = found
          .map((m) => (int.parse(m.group(1)!), int.parse(m.group(2)!)))
          .toList();
      // 先驗證再建 DateTime：DateTime(2000, 13, 5) 會自己滾成隔年一月，
      // 不擋的話「13月」這種字串會靜默變成一個合法的週次。
      final valid = parts
          .every((p) => p.$1 >= 1 && p.$1 <= 12 && p.$2 >= 1 && p.$2 <= 31);
      if (!valid) continue;
      // 年份只是佔位，真正比較日期時會換成當年，見 containsToday。
      return (
        DateTime(2000, parts[0].$1, parts[0].$2),
        DateTime(2000, parts[1].$1, parts[1].$2),
      );
    }
    return null;
  }

  static final RegExp _cjkDate = RegExp(r'(\d{1,2})\s*月\s*(\d{1,2})\s*日');
  static final RegExp _slashDate = RegExp(r'\b(\d{1,2})/(\d{1,2})\b');
  static final RegExp _htmlTag = RegExp(r'<[^>]*>');
  static final RegExp _brTag =
      RegExp(r'<br\s*/?>|</p\s*>', caseSensitive: false);
  static final RegExp _nbsp = RegExp(r'&nbsp;|&#160;');
  static final RegExp _whitespace = RegExp(r'\s+');
}

/// 整棵樹的分組結果。週次與主題式共用同一個型別，差別只在 [weekly]。
class CourseSectionTree {
  CourseSectionTree._(this.sections, this.weekly, this.currentWeek);

  factory CourseSectionTree.of(List<MoodleCoreCourseGetContents> raw,
      {DateTime? now}) {
    final sections = raw.map(CourseSection.of).toList();
    // 有任何一段解析得出日期區間就是週次格式：週次課程的第一段「一般」
    // 本來就不是日期。
    final weekly = sections.any((s) => s.isWeek);
    CourseSection? current;
    if (weekly) {
      for (final section in sections) {
        if (section.containsToday(now)) {
          current = section;
          break;
        }
      }
    }
    return CourseSectionTree._(sections, weekly, current);
  }

  final List<CourseSection> sections;
  final bool weekly;

  /// 今天所在的那一段。學期已經結束（或還沒開始）時是 null，本週卡就不畫。
  final CourseSection? currentWeek;

  int get totalFiles => sections.fold(0, (sum, s) => sum + s.fileCount);

  /// 有內容的段數（含本週）。統計列的第二個數字。
  int get sectionsWithContent => sections.where((s) => s.hasContent).length;

  /// 主題式列出來的段：完全沒有模組的段不畫，一列 0 沒有意義。
  List<CourseSection> get nonEmpty =>
      sections.where((s) => s.hasContent).toList();

  /// 有內容、但不是本週的那些段。
  List<CourseSection> get otherWithContent => sections
      .where((s) => s.hasContent && !identical(s, currentWeek))
      .toList();

  /// 真的一片空白的那幾段。收在「顯示沒有內容的 N 週」後面。
  List<CourseSection> get empty => sections
      .where((s) => !s.hasContent && !identical(s, currentWeek))
      .toList();

  /// 搜尋結果：每一段只留下對得上的模組，全空的段直接不出現。
  List<(CourseSection, List<Modules>)> search(String query) {
    final result = <(CourseSection, List<Modules>)>[];
    for (final section in sections) {
      final hits = section.modules
          .where((m) => CourseSection.moduleMatches(m, query))
          .toList();
      if (hits.isNotEmpty) result.add((section, hits));
    }
    return result;
  }
}

/// 模組列與資料夾頁檔案列的第二行。Flutter 的檔案分頁、資料夾頁與原生版共用。
class CourseModuleUtils {
  CourseModuleUtils._();

  /// resource 模組的第二行：「PDF · 2.4 MB」。沒有檔案資訊就整列維持單行。
  static String? fileSubtitle(Modules module) {
    if (module.modname != 'resource' || module.contents.isEmpty) return null;
    final file = module.contents.first;
    final extension = FileIconUtils.extensionOf(file.filename)?.toUpperCase();
    final parts = [
      if (extension != null && extension.isNotEmpty) extension,
      if (file.filesize > 0) FileUtils.formatBytes(file.filesize, 1),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// 「PDF · 2.4 MB · 3/1/2025 10:00」。副檔名排在最前面，和檔案分頁的
  /// 檔案列同一個順序。全部都沒有時回 null，那一列就維持單行。
  static String? folderFileSubtitle(Contents c) {
    final extension = FileIconUtils.extensionOf(c.filename)?.toUpperCase();
    final parts = [
      if (extension != null && extension.isNotEmpty) extension,
      if (c.filesize > 0) FileUtils.formatBytes(c.filesize, 1),
      if (c.timemodified > 0) _formatTime(c.timemodified),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static String _formatTime(int unix) => DateFormat.yMd()
      .add_jm()
      .format(DateTime.fromMillisecondsSinceEpoch(unix * 1000));
}
