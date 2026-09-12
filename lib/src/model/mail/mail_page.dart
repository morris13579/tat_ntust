import 'package:flutter_app/src/model/mail/mail_message_json.dart';

/// 一頁信，加上「後面還有沒有」與伺服器當下的 `UIDVALIDITY`。
///
/// **`hasMore` 一定要由伺服器那一端算。** 讓 UI 用「這一頁不足 limit」去猜，
/// 在剛好整除時會少一次載入——使用者捲到底看到的是「沒有更舊的了」，但其實
/// 還有。
class MailPage {
  const MailPage({
    required this.messages,
    required this.hasMore,
    required this.uidValidity,
  });

  final List<MailMessageJson> messages;
  final bool hasMore;

  /// 伺服器回的 `UIDVALIDITY`。變了就代表 UID 全部作廢，本機那個資料夾的快取
  /// 要整個丟掉——這是唯一能防「顯示到別封信」的機制，見
  /// docs/WEBMAIL_IMAP.md §5。問不到回 0。
  final int uidValidity;
}
