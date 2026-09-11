import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_message_popup_notifications.dart';
import 'package:intl/intl.dart';

/// 通知清單的時間分組。順序就是畫面順序。
enum NotificationBucket { today, thisWeek, earlier }

class NotificationGroup {
  const NotificationGroup(this.bucket, this.items);

  final NotificationBucket bucket;
  final List<MoodleNotification> items;
}

/// 通知清單的純函式：分組與時間欄的格式。沒有 UI、沒有網路。
///
/// 分組刻意放在這裡而不是 `MoodleNotificationUtils`：那一份是解析與排序，
/// 這一份只服務這一頁的版面。
class NotificationGroups {
  NotificationGroups._();

  /// 依建立時間相對於 [now] 分組。本週從這個星期一 00:00 起算，與
  /// `UpcomingEventUtils.groupByDeadline` 同一條週界線。
  ///
  /// [sorted] 必須已經是新到舊（`MoodleNotificationUtils.sortNewestFirst`）：
  /// 這裡只分桶，不重排。
  static List<NotificationGroup> groupByAge(
      List<MoodleNotification> sorted, DateTime now) {
    final startOfToday = DateTime(now.year, now.month, now.day);
    // weekday：Mon=1 .. Sun=7。
    final startOfWeek =
        DateTime(now.year, now.month, now.day - (now.weekday - 1));

    final buckets = {
      for (final bucket in NotificationBucket.values)
        bucket: <MoodleNotification>[],
    };
    for (final n in sorted) {
      final created = n.createdTime;
      final bucket = !created.isBefore(startOfToday)
          ? NotificationBucket.today
          : !created.isBefore(startOfWeek)
              ? NotificationBucket.thisWeek
              : NotificationBucket.earlier;
      buckets[bucket]!.add(n);
    }
    return [
      for (final bucket in NotificationBucket.values)
        if (buckets[bucket]!.isNotEmpty)
          NotificationGroup(bucket, buckets[bucket]!),
    ];
  }

  static String labelOf(NotificationBucket bucket) => switch (bucket) {
        NotificationBucket.today => R.current.deadlineToday,
        NotificationBucket.thisWeek => R.current.deadlineThisWeek,
        NotificationBucket.earlier => R.current.notificationGroupEarlier,
      };

  /// 「同一天只給時間、其餘給日期」——設計稿上今天那一組是 `14:20`，更舊的是
  /// `9月4日`。日期跟著語系走（`DateFormat` 會讀 `Intl.defaultLocale`），
  /// 因為它已經不是與標題爭寬度的固定數字欄了。
  ///
  /// **不用伺服器的 `timecreatedpretty`**：那串「N 分鐘前」是伺服器端依 Moodle
  /// 帳號語言算好的，跟 App 的語言切換打架，而且快取拿出來時早就過時。
  static String formatCreatedTime(DateTime created, DateTime now) {
    if (created.year == now.year &&
        created.month == now.month &&
        created.day == now.day) {
      return DateFormat.Hm().format(created);
    }
    return created.year == now.year
        ? DateFormat.MMMd().format(created)
        : DateFormat.yMMMd().format(created);
  }
}
