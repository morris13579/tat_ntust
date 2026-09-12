/// 寫過信或收過信的一個人。收件者欄的自動完成就是查這張表。
///
/// **不是通訊錄。** 沒有編輯、沒有分組、也不跟系統聯絡人同步——它只是「以前
/// 出現過的位址」，存在的理由是讓使用者不用把同一個助教的信箱打第二十次。
class MailContact {
  const MailContact({
    required this.email,
    this.name = '',
    this.lastSeenMillis = 0,
    this.sentCount = 0,
  });

  /// 小寫過的位址，當主鍵。同一個人用 `Prof@` 和 `prof@` 寄信不該變成兩筆。
  final String email;

  /// 顯示名稱，可能是空的（很多系統信只有位址）。
  final String name;

  /// 最後一次出現的時間。排序的第二順位。
  final int lastSeenMillis;

  /// 使用者主動寄給他幾次。排序的第一順位——寄過的人比只寄信來過的人更可能
  /// 是這次要找的對象。
  final int sentCount;

  /// 清單裡顯示的那一行。沒有名字就只有位址，不要印出一個空的括號。
  String get label => name.isEmpty ? email : '$name <$email>';
}
