import 'dart:io';

/// 一封要寄出去的信。
///
/// **刻意沒有 `from`**：寄件者一律由 `MailConnector` 填成登入帳號。實測伺服器
/// 的信封寄件者沒有限制（`MAIL FROM` 填別人的位址也回 250），代寄不會被擋，
/// 所以**不能靠伺服器幫忙擋錯**——`From:` 不讓上層決定，也不讓使用者輸入。
class MailDraft {
  const MailDraft({
    required this.to,
    this.cc = const [],
    this.bcc = const [],
    this.subject = "",
    this.body = "",
    this.attachments = const [],
    this.inReplyToUid,
  });

  final List<String> to;
  final List<String> cc;

  /// 密件副本。**只進 `RCPT TO`，不寫進標頭**——寫進去的話收件者互相看得到，
  /// 那正好是密件副本要避免的事。
  ///
  /// 注意 `MessageBuilder.bcc` **不是**這個語意：它會真的寫出一行 `Bcc:`
  /// 標頭。所以 `MailConnector.buildMimeMessage` 刻意不設它，改在
  /// `smtp.sendMessage(recipients:)` 明給收件者清單。
  final List<String> bcc;

  final String subject;

  /// 純文字內容。Phase 2 不做所見即所得，寄出去的是 `text/plain`。
  final String body;

  final List<File> attachments;

  /// 回覆的來源 UID。目前只用來標記原信已回覆，不組 `In-Reply-To`——
  /// envelope 沒抓 `Message-ID`，硬組會產生指向不存在訊息的標頭。
  final int? inReplyToUid;

  bool get hasRecipients => to.isNotEmpty;
}
