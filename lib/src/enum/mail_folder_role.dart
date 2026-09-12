/// 信箱資料夾的角色。
///
/// 伺服器**沒有 `SPECIAL-USE`**，實測每個資料夾的 flags 都是空的，所以角色
/// 只能靠名字判斷。見 docs/WEBMAIL_IMAP.md §2.5。
///
/// **住在 `enum/` 而不是 `config/`**：`MailFolderJson` 要用到它，而 model
/// 在分層上比 config 低，放 config 會是 `model -> config` 的上行邊。
enum MailFolderRole { inbox, sent, drafts, trash, junk, archive, other }

/// 資料夾名稱到角色的對照。
///
/// **同一個角色有兩套名字並存**：中文那套是 Mail2000 的原生資料夾，英文那套
/// 是使用者接過其他郵件軟體（Apple Mail 之類）之後被建出來的。兩套都要認，
/// 但**不能假設英文那套存在**——沒接過其他軟體的帳號只有中文那五個。
const Map<String, MailFolderRole> _folderRoles = {
  "INBOX": MailFolderRole.inbox,
  // Mail2000 原生
  "寄件備份匣": MailFolderRole.sent,
  "草稿匣": MailFolderRole.drafts,
  "回收筒": MailFolderRole.trash,
  "廣告信匣": MailFolderRole.junk,
  // 其他郵件軟體建的
  "Sent Messages": MailFolderRole.sent,
  "Drafts": MailFolderRole.drafts,
  "Deleted Messages": MailFolderRole.trash,
  "Junk": MailFolderRole.junk,
  "Archive": MailFolderRole.archive,
};

/// 認不出來一律回 [MailFolderRole.other]，**不要用猜的**（例如比對
/// 「含有『草稿』兩個字」）：猜錯的後果是把信刪到別的地方去。
MailFolderRole mailFolderRole(String name) {
  if (name.toUpperCase() == "INBOX") return MailFolderRole.inbox;
  return _folderRoles[name] ?? MailFolderRole.other;
}
