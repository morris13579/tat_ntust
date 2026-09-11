import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/util/file_icon_utils.dart';
import 'package:flutter_app/src/util/file_utils.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/components/file_type_icon.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
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

/// 清單裡的一列。圓角靠 [index] / [length] 算，一列一塊、彼此差 2px，
/// 與 App 其他清單同一套。
abstract class _Block extends StatelessWidget {
  const _Block({
    super.key,
    required this.index,
    required this.length,
  });

  final int index;
  final int length;

  /// 一列的底色。展開中的段要跟接在它底下的檔案列分得開，所以留給子類覆寫。
  Color background(BuildContext context) => context.tokens.card;

  Widget buildContent(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: index == 0 ? 0 : 2),
      child: Material(
        color: background(context),
        borderRadius: UIUtils.getBorderRadius(index, length),
        clipBehavior: Clip.antiAlias,
        child: buildContent(context),
      ),
    );
  }
}

/// 週次／主題的一列：名稱、摘要、檔案數與展開箭頭。點下去就地展開，不換頁。
class CourseSectionRow extends _Block {
  const CourseSectionRow({
    super.key,
    required this.title,
    required this.expanded,
    required this.onTap,
    required super.index,
    required super.length,
    this.badge,
    this.summary,
    this.count,
    this.showFolderIcon = false,
    this.highlight = false,
  });

  final String title;

  /// 標題前面的小字，目前只有「本週」。
  final String? badge;

  final String? summary;

  /// null 就不畫那一格。
  final int? count;

  /// 主題式的列有資料夾圖示，週次的沒有——日期前面放資料夾只是裝飾。
  final bool showFolderIcon;

  /// 本週那一張：底色換成 tint，字換成 accent。
  final bool highlight;

  final bool expanded;
  final VoidCallback onTap;

  /// 展開中的段也套本週那一套色：它底下接的檔案列同樣是圓角塊，兩層一樣白的
  /// 話會看成同一層，分不出哪一行是週次標題。
  bool get _active => highlight || expanded;

  @override
  Color background(BuildContext context) =>
      _active ? context.scheme.primaryContainer : context.tokens.card;

  @override
  Widget buildContent(BuildContext context) {
    final scheme = context.scheme;
    final text = context.text;
    final foreground = _active ? scheme.primary : scheme.onSurface;
    final secondary = _active ? scheme.primary : scheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            if (showFolderIcon) ...[
              // 細筆畫：展開後檔案列的圖示是 1px 的 SVG，兩層要同粗。
              Icon(LucideIconsThin.folder, size: 20, color: secondary),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (badge != null) ...[
                        Text(
                          badge!,
                          style: text.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600, color: secondary),
                        ),
                        const SizedBox(width: 9),
                      ],
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.tabular(
                              (text.bodyLarge ?? const TextStyle()).copyWith(
                                  color: foreground,
                                  fontWeight:
                                      badge == null ? null : FontWeight.w400,
                                  height: 1.45)),
                        ),
                      ),
                    ],
                  ),
                  if (summary != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      summary!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall
                          ?.copyWith(color: secondary, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 12),
              Text(
                '$count',
                style: AppTypography.tabular(
                    (text.labelLarge ?? const TextStyle())
                        .copyWith(color: secondary)),
              ),
            ],
            const SizedBox(width: 10),
            Icon(expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                size: 18, color: secondary),
          ],
        ),
      ),
    );
  }
}

/// 置中的一列文字加箭頭：「顯示沒有檔案的 12 週」「顯示其餘 6 個檔案」。
class CourseDisclosureRow extends _Block {
  const CourseDisclosureRow({
    super.key,
    required this.label,
    required this.onTap,
    required super.index,
    required super.length,
    this.expanded = false,
    this.showChevron = true,
    this.accent = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool expanded;

  /// 「顯示其餘 N 個檔案」那一列在設計稿裡只有文字。
  final bool showChevron;

  /// true 時文字用 accent 色：它是一個連結，不是一段說明。
  final bool accent;

  @override
  Widget buildContent(BuildContext context) {
    final scheme = context.scheme;
    final color = accent ? scheme.primary : scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.text.labelLarge?.copyWith(color: color),
              ),
            ),
            if (showChevron) ...[
              const SizedBox(width: 9),
              Icon(expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 17, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

/// 課程模組的一列：檔案是「類型 icon + 檔名 + PDF · 2.4 MB + 下載」，
/// 其他模組依 modname 換圖示與尾端動作。
///
/// 說明（description）是可有可無的第二層，展開的箭頭與整列的動作分開：點列是
/// 「做那件事」（下載、進討論區），點箭頭才是「先看看老師寫了什麼」。
class CourseModuleRow extends StatefulWidget {
  const CourseModuleRow({
    super.key,
    required this.module,
    required this.onTap,
    required this.index,
    required this.length,
  });

  final Modules module;

  /// 依 modname 決定要做什麼。由呼叫端注入，這一層才不必 import 路由。
  final void Function(Modules module) onTap;

  final int index;
  final int length;

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

  /// 這一排會和 [FileTypeIcon] 的檔案圖示交錯出現，所以用細的那一組，
  /// 兩者筆畫才一致。
  static IconData iconFor(String modname) {
    switch (modname) {
      case 'forum':
        return LucideIconsThin.messageSquare;
      case 'assign':
        return LucideIconsThin.clipboardList;
      case 'folder':
        return LucideIconsThin.folder;
      case 'quiz':
        return LucideIconsThin.fileQuestion;
      case 'label':
        return LucideIconsThin.tag;
      case 'url':
        return LucideIconsThin.link;
      default:
        return LucideIconsThin.copy;
    }
  }

  @override
  State<CourseModuleRow> createState() => _CourseModuleRowState();
}

class _CourseModuleRowState extends State<CourseModuleRow> {
  bool _descriptionOpen = false;

  Modules get _module => widget.module;

  /// resource 模組跟官方 App 一樣畫檔案類型 icon，其他模組依 modname 挑圖。
  Widget _leading() {
    if (_module.modname == 'resource') {
      final file = _module.contents.isEmpty ? null : _module.contents.first;
      return FileTypeIcon(
        filename: file?.filename ?? '',
        mimetype: file?.mimetype ?? '',
        modicon: _module.modicon,
        size: 20,
      );
    }
    return Icon(CourseModuleRow.iconFor(_module.modname), size: 20);
  }

  /// 右邊那一格。檔案是下載、其餘是「還有下一頁」；label 兩者都不是。
  Widget? _trailing() {
    final scheme = context.scheme;
    switch (_module.modname) {
      case 'label':
        return null;
      case 'resource':
        return Icon(LucideIconsThin.download, size: 18, color: scheme.primary);
      case 'url':
        return Icon(LucideIcons.externalLink,
            size: 17, color: scheme.onSurfaceVariant);
      default:
        return Icon(LucideIcons.chevronRight,
            size: 17, color: scheme.onSurfaceVariant);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final text = context.text;
    final subtitle = CourseModuleRow.fileSubtitle(_module);
    final hasDescription =
        _module.modname != 'label' && _module.description.trim().isNotEmpty;
    final trailing = _trailing();

    return Padding(
      padding: EdgeInsets.only(top: widget.index == 0 ? 0 : 2),
      child: Material(
        color: context.tokens.card,
        borderRadius: UIUtils.getBorderRadius(widget.index, widget.length),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              // label 沒有可以做的事，就不要給一個什麼都不做的漣漪。
              onTap: _module.modname == 'label'
                  ? null
                  : () => widget.onTap(_module),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    _leading(),
                    const SizedBox(width: 11),
                    Expanded(
                      child: _module.modname == 'label'
                          ? HtmlWidget(_module.description,
                              renderMode: RenderMode.column)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _module.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodyLarge?.copyWith(
                                      color: scheme.onSurface, height: 1.45),
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    subtitle,
                                    style: AppTypography.tabular(
                                        (text.bodySmall ?? const TextStyle())
                                            .copyWith(
                                                color: scheme.onSurfaceVariant,
                                                height: 1.4)),
                                  ),
                                ],
                              ],
                            ),
                    ),
                    if (hasDescription) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: _module.name,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                            width: 32, height: 32),
                        icon: Icon(
                            _descriptionOpen
                                ? LucideIcons.chevronUp
                                : LucideIcons.chevronDown,
                            size: 17,
                            color: scheme.onSurfaceVariant),
                        onPressed: () => setState(
                            () => _descriptionOpen = !_descriptionOpen),
                      ),
                    ],
                    if (trailing != null) ...[
                      const SizedBox(width: 10),
                      trailing,
                    ],
                  ],
                ),
              ),
            ),
            if (hasDescription && _descriptionOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: HtmlWidget(_module.description,
                      renderMode: RenderMode.column),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
