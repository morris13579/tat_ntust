import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/store/extra_table_store.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/page/note_icon.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 管理課表。
///
/// 三區各自的刪除語意不同：自己的課表刪掉只是清掉本機快取，下次選那個學期會
/// 再抓一次；他人課表與模擬課表刪掉就真的沒了，前者是掃描當下的快照，後者是
/// 自己排的草稿。刪除的確認由呼叫端注入——這一頁不 import route_utils 也不開
/// 對話框。
class ManageTablesPage extends StatefulWidget {
  const ManageTablesPage({
    super.key,
    required this.myTables,
    required this.currentLabel,
    required this.labelOf,
    required this.summaryOf,
    required this.importedAtOf,
    required this.draftSummaryOf,
    required this.onDeleteMine,
    required this.confirmDelete,
    required this.onScan,
  });

  final List<CourseTableJson> myTables;

  /// 目前畫面上那一份的標籤，用來標「目前」。
  final String currentLabel;

  final String Function(CourseTableJson table) labelOf;
  final String Function(CourseTableJson table) summaryOf;
  final String Function(ExtraTable table) importedAtOf;

  /// 草稿的「幾門課、幾學分、幾處衝堂」。跟切換課表那張清單算的是同一份。
  final String Function(ExtraTable table) draftSummaryOf;

  final Future<void> Function(CourseTableJson table) onDeleteMine;

  /// 刪除前的確認。回 true 才刪。
  final Future<bool> Function(String label) confirmDelete;

  /// 掃描他人課表。還沒做時傳 null，那一列就不會出現。
  final VoidCallback? onScan;

  @override
  State<ManageTablesPage> createState() => _ManageTablesPageState();
}

class _ManageTablesPageState extends State<ManageTablesPage> {
  late List<CourseTableJson> _mine = [...widget.myTables];
  List<ExtraTable> _shared = ExtraTableStore.instance.shared;
  List<ExtraTable> _drafts = ExtraTableStore.instance.drafts;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: mainAppbar(title: R.current.manageTablesTitle, isShowBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        children: [
          _header(R.current.manageTablesMine),
          for (var i = 0; i < _mine.length; i++) ...[
            if (i > 0) const SizedBox(height: 2),
            _myRow(_mine[i], i, _mine.length),
          ],
          _note(R.current.manageTablesMineHint),
          _header(R.current.manageTablesShared),
          for (var i = 0; i < _shared.length; i++) ...[
            if (i > 0) const SizedBox(height: 2),
            _sharedRow(_shared[i], i,
                _shared.length + (widget.onScan == null ? 0 : 1)),
          ],
          if (widget.onScan != null) ...[
            if (_shared.isNotEmpty) const SizedBox(height: 2),
            _scanRow(_shared.length, _shared.length + 1),
          ],
          _note(R.current.manageTablesSharedHint),
          // 草稿是從切換課表那張清單開出來的，刪除只有這一頁做得到。
          if (_drafts.isNotEmpty) ...[
            _header(R.current.manageTablesDrafts),
            for (var i = 0; i < _drafts.length; i++) ...[
              if (i > 0) const SizedBox(height: 2),
              _draftRow(_drafts[i], i, _drafts.length),
            ],
            _note(R.current.manageTablesDraftsHint),
          ],
        ],
      ),
    );
  }

  Widget _header(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Text(
          title,
          style: context.text.labelMedium
              ?.copyWith(color: context.scheme.onSurfaceVariant),
        ),
      );

  Widget _note(String text) {
    final scheme = context.scheme;
    final style =
        context.text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NoteIcon(LucideIcons.info,
              style: style, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }

  Widget _myRow(CourseTableJson table, int index, int length) {
    final label = widget.labelOf(table);
    final isCurrent = label == widget.currentLabel;
    return _row(
      index: index,
      length: length,
      icon: LucideIcons.graduationCap,
      label: label,
      supporting: widget.summaryOf(table),
      // 目前這一份不給刪：刪掉之後畫面上還顯示著它，狀態會對不起來。
      trailing: isCurrent
          ? _CurrentBadge()
          : _deleteButton(label, () => _deleteMine(table)),
    );
  }

  Widget _sharedRow(ExtraTable table, int index, int length) => _row(
        index: index,
        length: length,
        icon: LucideIcons.users,
        label: table.label,
        supporting: widget.importedAtOf(table),
        trailing: _deleteButton(table.label, () => _deleteShared(table)),
      );

  Widget _draftRow(ExtraTable table, int index, int length) => _row(
        index: index,
        length: length,
        icon: LucideIcons.flaskConical,
        label: table.label,
        supporting: widget.draftSummaryOf(table),
        trailing: _deleteButton(table.label, () => _deleteDraft(table)),
      );

  Widget _scanRow(int index, int length) => _row(
        index: index,
        length: length,
        icon: LucideIcons.scanLine,
        label: R.current.scanTableTitle,
        onTap: widget.onScan,
        primary: true,
      );

  /// 一列。整份 App 的清單都是「每列自己一塊 Material，靠圓角與 2px 間隔分開」，
  /// 不是一張卡片裡塞分隔線。
  Widget _row({
    required int index,
    required int length,
    required IconData icon,
    required String label,
    String? supporting,
    Widget? trailing,
    VoidCallback? onTap,
    bool primary = false,
  }) {
    final scheme = context.scheme;
    return Material(
      color: context.tokens.card,
      borderRadius: UIUtils.getBorderRadius(index, length),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: TatTokens.heightRow),
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            children: [
              SizedBox(
                width: TatTokens.iconColumn,
                child: Icon(icon,
                    size: 20,
                    color: primary ? scheme.primary : scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: AppTypography.tabular(context.text.bodyLarge!)
                          .copyWith(
                              height: 1.4,
                              color:
                                  primary ? scheme.primary : scheme.onSurface),
                    ),
                    if (supporting != null)
                      Text(
                        supporting,
                        style: AppTypography.tabular(context.text.bodySmall!)
                            .copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
              if (trailing == null) const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _deleteButton(String label, Future<void> Function() onConfirmed) =>
      IconButton(
        tooltip: R.current.delete,
        icon: const Icon(LucideIcons.trash2),
        color: context.scheme.error,
        onPressed: () async {
          if (!await widget.confirmDelete(label)) return;
          await onConfirmed();
        },
      );

  Future<void> _deleteMine(CourseTableJson table) async {
    await widget.onDeleteMine(table);
    if (!mounted) return;
    setState(() => _mine = _mine
        .where((e) => !(e.studentId == table.studentId &&
            e.courseSemester == table.courseSemester))
        .toList());
  }

  Future<void> _deleteDraft(ExtraTable table) async {
    await ExtraTableStore.instance.removeDraft(table.id);
    if (!mounted) return;
    setState(() => _drafts = ExtraTableStore.instance.drafts);
  }

  Future<void> _deleteShared(ExtraTable table) async {
    await ExtraTableStore.instance.removeShared(table.id);
    if (!mounted) return;
    setState(() => _shared = ExtraTableStore.instance.shared);
  }
}

/// 「目前」。用 primaryContainer 的小方塊而不是描邊。
class _CurrentBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(TatTokens.radiusButton),
        ),
        child: Text(
          R.current.manageTablesCurrent,
          style: context.text.labelMedium?.copyWith(color: scheme.primary),
        ),
      ),
    );
  }
}
