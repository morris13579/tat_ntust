import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/enum/mail_folder_role.dart';
import 'package:flutter_app/src/model/mail/mail_folder_json.dart';
import 'package:flutter_app/src/util/mail_groups.dart';

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
bool mailFolderIsEmpty(MailFolderJson folder) =>
    folder.hasCount && folder.messageCount == 0;
