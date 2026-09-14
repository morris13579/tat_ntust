import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/util/course_section_tree.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/components/file_type_icon.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

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
    final subtitle = CourseModuleUtils.fileSubtitle(_module);
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
