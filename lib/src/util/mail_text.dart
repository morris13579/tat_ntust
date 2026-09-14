import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/mail/mail_content.dart';
import 'package:flutter_app/src/model/mail/mail_message_json.dart';
import 'package:sprintf/sprintf.dart';

/// 信件內頁、新信橫幅與回信共用的字與判斷。沒有 UI、沒有網路。
class MailText {
  MailText._();

  static String subjectOf(String subject) {
    final trimmed = subject.trim();
    return trimmed.isEmpty ? R.current.mailNoSubject : trimmed;
  }

  /// 新信橫幅的標題。一次來好幾封只畫一條，標題改成數量。[fresh] 新到舊。
  static String arrivalTitle(List<MailMessageJson> fresh) => fresh.length == 1
      ? fresh.first.displayFrom
      : sprintf(R.current.mailNewMessages, [fresh.length]);

  /// 已經有前綴就不再加一次，免得變成 `Re: Re: Re:`。
  static String prefixed(String prefix, String subject) =>
      subject.toLowerCase().startsWith(prefix.toLowerCase())
          ? subject
          : '$prefix$subject';

  /// 回覆的收件者。全部回覆才把原信的收件者與副本帶上，而且要把自己剔掉——
  /// 不然每回一次就多寄一封給自己。
  static List<String> replyRecipients(MailMessageJson message,
      {required bool all, required String ownAddress}) {
    final own = ownAddress.toLowerCase();
    final unique = <String>[];
    for (final address in [
      if (message.fromEmail.isNotEmpty) message.fromEmail,
      if (all) ...[...message.to, ...message.cc],
    ]) {
      final normalized = address.trim();
      if (normalized.isEmpty || normalized.toLowerCase() == own) continue;
      if (unique.any((e) => e.toLowerCase() == normalized.toLowerCase())) {
        continue;
      }
      unique.add(normalized);
    }
    return unique;
  }

  /// 逐行加上「> 」的引言。
  static String quote(String plainText) =>
      plainText.split('\n').map((line) => '> ${line.trimRight()}').join('\n');

  /// 信件裡有沒有指向外部的 `<img>`。
  ///
  /// 只看 http(s)：`cid:` 是信件自己夾帶的 part（connector 已經換成 `data:`），
  /// 顯示它不會對外發任何請求。
  static bool hasRemoteImages(String html) =>
      RegExp("""<img[^>]+src=[\\"']?https?://""", caseSensitive: false)
          .hasMatch(html);

  /// 「PNG · 1.2 MB」。兩個都問不到就回 null。
  static String? attachmentMeta(MailAttachment attachment) {
    final size = attachment.readableSize;
    final type = attachment.mediaType.split('/').last.toUpperCase();
    final parts = [
      if (type.isNotEmpty) type,
      if (size != null) size,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
