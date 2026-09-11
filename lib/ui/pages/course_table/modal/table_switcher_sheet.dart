import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/store/extra_table_store.dart';
import 'package:flutter_app/ui/components/sheet/tat_bottom_sheet.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 使用者在切換器上選了什麼。
sealed class TableChoice {
  const TableChoice();
}

/// 切到自己已下載的某一份課表。
class MyTableChoice extends TableChoice {
  const MyTableChoice(this.table);

  final CourseTableJson table;
}

/// 開一份模擬課表（草稿）。
class DraftChoice extends TableChoice {
  const DraftChoice(this.draft);

  final ExtraTable draft;
}

/// 開一份掃描匯入的他人課表。
class SharedChoice extends TableChoice {
  const SharedChoice(this.shared);

  final ExtraTable shared;
}

/// 新增一份模擬課表。
class NewDraftChoice extends TableChoice {
  const NewDraftChoice();
}

/// 去管理課表。
class ManageTablesChoice extends TableChoice {
  const ManageTablesChoice();
}

/// 課表切換器。回傳 null 代表沒選。
///
/// 三個來源各一區：自己下載過的學期、掃進來的他人課表、模擬排課的草稿。
/// 這一份取代原本的「載入常用課表」——那一頁只看得到第一種。
Future<TableChoice?> showTableSwitcherSheet({
  required BuildContext context,
  required List<CourseTableJson> myTables,
  required List<ExtraTable> shared,
  required List<ExtraTable> drafts,
  required String Function(CourseTableJson table) labelOf,
  required String Function(CourseTableJson table) summaryOf,
  required String Function(ExtraTable table) importedAtOf,
  required String Function(ExtraTable draft) draftSummaryOf,
  String? currentLabel,
}) =>
    showTatContentSheet<TableChoice>(
      context: context,
      title: R.current.tableSwitcherTitle,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (myTables.isNotEmpty) ...[
            _Section(title: R.current.tableSwitcherMine),
            for (final table in myTables)
              TatSheetOptionRow<String>(
                option: TatSheetOption(
                  label: labelOf(table),
                  supporting: summaryOf(table),
                  value: '',
                ),
                isSelected: labelOf(table) == currentLabel,
                tabularFigures: true,
                onTap: () => Navigator.pop(context, MyTableChoice(table)),
              ),
          ],
          if (shared.isNotEmpty) ...[
            _Section(title: R.current.tableSwitcherShared),
            for (final table in shared)
              TatSheetOptionRow<String>(
                option: TatSheetOption(
                  label: table.label,
                  supporting: importedAtOf(table),
                  value: '',
                ),
                isSelected: false,
                tabularFigures: true,
                onTap: () => Navigator.pop(context, SharedChoice(table)),
              ),
          ],
          _Section(title: R.current.tableSwitcherDrafts),
          for (final draft in drafts)
            TatSheetOptionRow<String>(
              option: TatSheetOption(
                label: draft.label,
                supporting: draftSummaryOf(draft),
                value: '',
              ),
              isSelected: false,
              onTap: () => Navigator.pop(context, DraftChoice(draft)),
            ),
          _ActionRow(
            icon: LucideIcons.plus,
            label: R.current.simulationNew,
            onTap: () => Navigator.pop(context, const NewDraftChoice()),
          ),
          const Divider(height: 17),
          _ActionRow(
            icon: LucideIcons.settings2,
            label: R.current.manageTablesTitle,
            onTap: () => Navigator.pop(context, const ManageTablesChoice()),
          ),
        ],
      ),
    );

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
        child: Text(
          title,
          style: context.text.labelMedium
              ?.copyWith(color: context.scheme.onSurfaceVariant),
        ),
      );
}

/// 不是「選一份課表」而是「做一件事」的那幾列，所以有圖示、沒有打勾。
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: TatTokens.heightRow),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: TatTokens.iconColumn,
              child: Icon(icon, size: 20, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style:
                      context.text.bodyLarge?.copyWith(color: scheme.primary)),
            ),
          ],
        ),
      ),
    );
  }
}
