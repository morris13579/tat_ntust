import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/ui/components/card/section_card.dart';
import 'package:flutter_app/ui/components/page/destructive_row.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';

/// 自己的貼文可以做的兩件事。
enum ForumPostAction { edit, delete }

/// 一則貼文的動作選單。回 null 代表使用者取消（點外面、按返回、按取消都算）。
///
/// 形狀照 `avatar_action_sheet.dart`——那已經是這個 App 的既有語彙。破壞性
/// 動作放在需要多一次點擊的地方，比擺在回覆鈕旁邊兩顆按鈕的距離安全。
///
/// **「在網頁編輯」不在這張 sheet 裡**：它不是平時的選項，只在編輯被
/// round-trip 守門擋下時，由那個說明對話框給——那時它才是答案。
Future<ForumPostAction?> showForumPostActionSheet(
  BuildContext context, {
  required bool canEdit,
  required bool canDelete,
  required bool deleteBlockedByReplies,
}) {
  return showModalBottomSheet<ForumPostAction>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _ForumPostActionSheet(
      canEdit: canEdit,
      canDelete: canDelete,
      deleteBlockedByReplies: deleteBlockedByReplies,
    ),
  );
}

class _ForumPostActionSheet extends StatelessWidget {
  const _ForumPostActionSheet({
    required this.canEdit,
    required this.canDelete,
    required this.deleteBlockedByReplies,
  });

  final bool canEdit;
  final bool canDelete;

  /// 本機由 `parentid` 推出來的提示（**會少算**私訊回覆），只用來把那一項改成
  /// 停用並附一句理由；伺服器的 `couldnotdeletereplies` 才是最後的答案。
  final bool deleteBlockedByReplies;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // 可捲：modal sheet 的高度上限是螢幕的 9/16，字級放大就會超出去。
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SectionSubLabel(R.current.forumPostActions),
            ),
            if (canEdit)
              ListTile(
                leading: const Icon(LucideIcons.pencil),
                title: Text(R.current.forumEditPost),
                onTap: () => Navigator.pop(context, ForumPostAction.edit),
              ),
            if (canDelete)
              DestructiveRow(
                enabled: !deleteBlockedByReplies,
                icon: LucideIcons.trash2,
                label: R.current.forumDeletePost,
                subtitle: deleteBlockedByReplies
                    ? R.current.forumCannotDeleteHasReplies
                    : null,
                onTap: () => Navigator.pop(context, ForumPostAction.delete),
              ),
            const SectionDivider(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(R.current.cancel),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
