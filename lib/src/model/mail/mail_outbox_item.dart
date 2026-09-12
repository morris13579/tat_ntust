import 'package:flutter_app/src/model/mail/mail_draft.dart';

/// 寄件匣裡一封信的狀態。
enum MailOutboxState {
  /// 還在等。這段時間內**收得回來**——這就是「收回」能成立的唯一窗口。
  waiting,

  /// 已經交給 SMTP 了。收不回來：信有可能已經在對方伺服器上。
  sending,

  /// 這一趟失敗了，留著讓使用者重試或刪掉。
  failed,
}

/// 寄件匣裡的一封信。
///
/// **為什麼要有寄件匣**：先前按下寄出之後畫面就關了，一趟 SMTP 在手機網路上
/// 可能要十幾秒，這段時間使用者看不到任何東西，按錯了也追不回來。排進佇列之後
/// 「在寄什麼」變成畫面上看得到的一列，而且在真正交給 SMTP 之前那幾秒可以收回。
class MailOutboxItem {
  const MailOutboxItem({
    required this.id,
    required this.draft,
    required this.state,
    required this.createdMillis,
    this.attempts = 0,
    this.lastError = '',
  });

  /// SQLite 的 rowid。收回與重試都靠它指定是哪一封。
  final int id;

  final MailDraft draft;
  final MailOutboxState state;

  /// 排進佇列的時間。倒數與「等多久該送出去」都從這裡算。
  final int createdMillis;

  final int attempts;

  /// 最後一次失敗的原因，給那一列顯示用。
  final String lastError;

  MailOutboxItem copyWith({
    MailOutboxState? state,
    int? attempts,
    String? lastError,
  }) =>
      MailOutboxItem(
        id: id,
        draft: draft,
        state: state ?? this.state,
        createdMillis: createdMillis,
        attempts: attempts ?? this.attempts,
        lastError: lastError ?? this.lastError,
      );

  /// 收件者摘要。清單那一列只有一行的寬度，所以第一位之後用「等 N 人」收尾。
  String get recipientSummary {
    final all = [...draft.to, ...draft.cc, ...draft.bcc];
    if (all.isEmpty) return '';
    if (all.length == 1) return all.first;
    return '${all.first} +${all.length - 1}';
  }
}
