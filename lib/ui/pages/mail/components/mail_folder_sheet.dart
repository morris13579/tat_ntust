import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/enum/mail_folder_role.dart';
import 'package:flutter_app/src/model/mail/mail_folder_json.dart';
import 'package:flutter_app/ui/components/sheet/tat_bottom_sheet.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:flutter_app/ui/pages/mail/components/mail_groups.dart';
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

/// 資料夾角色對應的顯示名稱。認不出角色的才用伺服器回的原始名稱——那多半是
/// 使用者自己建的資料夾，本來就沒有翻譯可言。
String mailFolderLabel(MailFolderJson folder) => switch (folder.role) {
      MailFolderRole.inbox => R.current.mailFolderInbox,
      MailFolderRole.sent => R.current.mailFolderSent,
      MailFolderRole.drafts => R.current.mailFolderDrafts,
      MailFolderRole.trash => R.current.mailFolderTrash,
      MailFolderRole.junk => R.current.mailFolderJunk,
      MailFolderRole.archive => R.current.mailFolderArchive,
      MailFolderRole.other => folder.name,
    };

/// 同一個角色只留一個。
///
/// 伺服器上中文（Mail2000 原生）與英文（其他郵件軟體建的）兩套資料夾並存，
/// 兩套都對映到同一個角色，不去重的話畫面上會出現兩個一模一樣的「寄件備份」。
/// 保留先出現的那一個——`fetchFolders` 已經照角色排過，而 Mail2000 原生那套
/// 是 webmail 實際在用的。
List<MailFolderJson> uniqueMailFoldersByRole(List<MailFolderJson> folders) {
  final seen = <MailFolderRole>{};
  return [
    for (final folder in folders)
      if (folder.role == MailFolderRole.other || seen.add(folder.role)) folder,
  ];
}

/// 「4,367 封 · 2,919 未讀」。問不到數量就回 null——顯示 0 會讓人以為資料夾
/// 是空的，而「問不到」和「真的沒有」是兩件事。
String? mailFolderCount(MailFolderJson folder) {
  if (!folder.hasCount) return null;
  final total =
      '${MailGroups.formatCount(folder.messageCount)} ${R.current.mailMessageCount}';
  if (folder.unreadCount <= 0) return total;
  return '$total · ${MailGroups.formatCount(folder.unreadCount)} ${R.current.mailUnread}';
}

/// 空的資料夾。**問不到數量的不算空**：那是 `STATUS` 失敗，不是真的沒信，
/// 收起來會讓使用者再也找不到它。
bool _isEmpty(MailFolderJson folder) =>
    folder.hasCount && folder.messageCount == 0;

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
        if (!_isEmpty(folder) || folder.path == widget.selected) folder,
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
              if (_isEmpty(folder) && folder.path != widget.selected)
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
