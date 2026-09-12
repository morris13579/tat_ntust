/// 一封信的附件。
///
/// **不進快取**：附件的位元組留在伺服器上，這裡只有描述。使用者按下下載時
/// 才用 [fetchId] 去抓那一個 part。
class MailAttachment {
  const MailAttachment({
    required this.fetchId,
    required this.name,
    this.mediaType = '',
    this.sizeBytes = 0,
  });

  /// IMAP 的 part 編號（`1.2` 這種）。抓單一附件時用它，不必整封重抓。
  final String fetchId;

  final String name;
  final String mediaType;

  /// 伺服器回報的大小。0 代表沒回報，畫面上就不顯示。
  final int sizeBytes;

  /// 「1.2 MB」。伺服器沒回報大小就回 null，不要顯示 0 B。
  String? get readableSize {
    if (sizeBytes <= 0) return null;
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// 一封信的可顯示內容。
///
/// 內文與附件清單一起回：兩者都來自同一次 `BODY[]`，拆成兩個方法會變成抓兩次
/// 整封信。
class MailContent {
  const MailContent({required this.html, this.attachments = const []});

  final String html;
  final List<MailAttachment> attachments;
}
