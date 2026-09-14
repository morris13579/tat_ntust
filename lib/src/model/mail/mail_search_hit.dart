import 'package:flutter_app/src/model/mail/mail_message_json.dart';

/// 搜尋結果的一封信與它所在的資料夾。跨資料夾之後 UID 不再唯一，開信、標已讀、
/// 搬信都要回到這個資料夾，不能用正在看的那一個。
class MailSearchHit {
  const MailSearchHit(this.folderPath, this.message);

  final String folderPath;
  final MailMessageJson message;
}
