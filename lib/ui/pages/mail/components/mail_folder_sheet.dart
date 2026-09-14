import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/enum/mail_folder_role.dart';
import 'package:flutter_app/src/model/mail/mail_folder_json.dart';
import 'package:flutter_app/src/util/mail_folders.dart';
import 'package:flutter_app/ui/components/sheet/tat_bottom_sheet.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:sprintf/sprintf.dart';

/// 切換資料夾。回傳選中的路徑，沒選就 null。
///
/// **空資料夾預設收起來。** 實測七個資料夾裡六個是 0 封，全部攤開的話整張
/// 選單有四分之三在說「這裡沒有東西」。和課程檔案頁的空週次同一個做法，連
/// 展開列的樣子都一樣。
Future<String?> showMailFolderSheet({
  required BuildContext context,
  required List<MailFolderJson> folders,
  required String selected,
  String? title,
}) =>
    showTatContentSheet<String>(
      context: context,
      title: title ?? R.current.mailFolders,
      builder: (context) => _FolderList(folders: folders, selected: selected),
    );

class _FolderList extends StatefulWidget {
  const _FolderList({required this.folders, required this.selected});

  final List<MailFolderJson> folders;
  final String selected;

  @override
  State<_FolderList> createState() => _FolderListState();
}

class _FolderListState extends State<_FolderList> {
  bool _showEmpty = false;

  @override
  Widget build(BuildContext context) {
    final folders = uniqueMailFoldersByRole(widget.folders);
    // 目前所在的資料夾一定留著，就算它是空的——不然切進空資料夾之後，那一列
    // 會從選單裡消失，而它正是打勾的那一個。
    final visible = [
      for (final folder in folders)
        if (!mailFolderIsEmpty(folder) || folder.path == widget.selected) folder,
    ];
    final hidden = folders.length - visible.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final folder in visible) _row(folder),
        if (hidden > 0) ...[
          if (_showEmpty)
            for (final folder in folders)
              if (mailFolderIsEmpty(folder) && folder.path != widget.selected)
                _row(folder),
          _DisclosureRow(
            label: _showEmpty
                ? R.current.hideEmptyFolders
                : sprintf(R.current.showEmptyFolders, [hidden]),
            expanded: _showEmpty,
            onTap: () => setState(() => _showEmpty = !_showEmpty),
          ),
        ],
      ],
    );
  }

  Widget _row(MailFolderJson folder) => TatSheetOptionRow<String>(
        option: TatSheetOption(
          label: mailFolderLabel(folder),
          supporting: mailFolderCount(folder),
          value: folder.path,
          icon: folder.role == MailFolderRole.inbox
              ? LucideIcons.inbox
              : LucideIcons.folder,
        ),
        isSelected: folder.path == widget.selected,
        onTap: () => Navigator.pop(context, folder.path),
      );
}

/// 「顯示 N 個空資料夾」。和 `CourseDisclosureRow` 同一個角色：它不是選項，
/// 所以不長得像選項——沒有圖示欄、文字用 primary、右邊是展開箭頭。
class _DisclosureRow extends StatelessWidget {
  const _DisclosureRow({
    required this.label,
    required this.expanded,
    required this.onTap,
  });

  final String label;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(TatTokens.radiusButton),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: context.text.bodyLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Icon(
                  expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 20,
                  color: scheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
