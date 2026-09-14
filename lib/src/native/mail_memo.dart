import 'package:flutter_app/src/model/mail/mail_content.dart';
import 'package:flutter_app/src/model/mail/mail_message_json.dart';

/// 信箱清單、內頁與寫信頁共用：畫面上那一列是哪一封、內頁剛讀到的內文。
///
/// 列用 ref 指名而不是 UID：跨資料夾搜尋的結果 UID 不唯一。
class MailMemo {
  final Map<String, MailRef> _refs = {};
  String? _contentRef;
  MailContent? _content;

  String put(String ref, String folderPath, MailMessageJson message) {
    _refs[ref] = MailRef(folderPath, message);
    return ref;
  }

  MailRef? operator [](String ref) => _refs[ref];

  /// 回信要引用的內文。只留最後讀的那一封：內文可能夾著好幾 MB 的內嵌圖片。
  void rememberContent(String ref, MailContent content) {
    _contentRef = ref;
    _content = content;
  }

  MailContent? contentOf(String ref) => _contentRef == ref ? _content : null;
}

class MailRef {
  const MailRef(this.folderPath, this.message);

  /// 抓內文、標已讀與搬信用的資料夾。跨資料夾搜尋的結果是那一封自己的資料夾。
  final String folderPath;
  final MailMessageJson message;
}
