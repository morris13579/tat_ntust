import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/mail/mail_message_json.dart';
import 'package:intl/intl.dart';

/// 信件清單的時間分組。順序就是畫面順序。
enum MailBucket { today, thisWeek, earlier }

class MailGroup {
  const MailGroup(this.bucket, this.items);

  final MailBucket bucket;
  final List<MailMessageJson> items;
}

/// 信件清單的純函式：分組、時間欄、主旨的顯示形式。沒有 UI、沒有網路。
///
/// 分組與 `NotificationGroups.groupByAge` 同一條週界線（這個星期一 00:00），
/// 兩頁的「本週」才是同一個意思。
class MailGroups {
  MailGroups._();

  /// 依信件日期相對於 [now] 分組。[sorted] 必須已經是新到舊。
  static List<MailGroup> groupByAge(
      List<MailMessageJson> sorted, DateTime now) {
    final startOfToday = DateTime(now.year, now.month, now.day);
    // weekday：Mon=1 .. Sun=7。
    final startOfWeek =
        DateTime(now.year, now.month, now.day - (now.weekday - 1));

    final buckets = {
      for (final bucket in MailBucket.values) bucket: <MailMessageJson>[],
    };
    for (final message in sorted) {
      // 日期是 0 的信（伺服器沒給 `Date:`）不該混進「今天」——那個 epoch 是
      // 1970，落在最舊的那一組才對。
      final date = message.date;
      final bucket = message.dateMillis == 0
          ? MailBucket.earlier
          : !date.isBefore(startOfToday)
              ? MailBucket.today
              : !date.isBefore(startOfWeek)
                  ? MailBucket.thisWeek
                  : MailBucket.earlier;
      buckets[bucket]!.add(message);
    }
    return [
      for (final bucket in MailBucket.values)
        if (buckets[bucket]!.isNotEmpty) MailGroup(bucket, buckets[bucket]!),
    ];
  }

  /// 分組標題。沿用通知頁那三句，兩頁的分法一樣，字也該一樣。
  static String labelOf(MailBucket bucket) => switch (bucket) {
        MailBucket.today => R.current.deadlineToday,
        MailBucket.thisWeek => R.current.deadlineThisWeek,
        MailBucket.earlier => R.current.notificationGroupEarlier,
      };

  /// 今天的信給時間、其餘給日期。清單已經照日期分組，所以「今天」那一組裡
  /// 的時間不會和別組的日期混在一起比較。
  static String formatDate(DateTime date, DateTime now) {
    if (date.millisecondsSinceEpoch == 0) return '';
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return DateFormat('HH:mm').format(date);
    }
    return date.year == now.year
        ? DateFormat('MM/dd').format(date)
        : DateFormat('yyyy/MM/dd').format(date);
  }

  /// 「4,367」。四位數以上的信件數不加千分位會看成 43 萬。
  static String formatCount(int value) =>
      NumberFormat.decimalPattern().format(value);
}
