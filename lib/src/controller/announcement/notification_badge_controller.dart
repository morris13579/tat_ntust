import 'package:flutter/foundation.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:get/get.dart';

/// 課表頁那顆大聲公上的未讀數。process 級單例，樣式照 `MoodleRepository.instance`
/// ——它的生命週期跨頁面，而且登出時必須歸零。
class NotificationBadgeController {
  NotificationBadgeController();

  static NotificationBadgeController instance = NotificationBadgeController();

  final RxInt unread = 0.obs;

  /// 回到課表頁時的輪詢間隔。開頁與標記已讀都會直接寫入正確的數字，
  /// 這個輪詢只是為了讓 App 停在背景很久之後回來時不會停在舊數字。
  static const Duration minPollInterval = Duration(minutes: 1);

  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  DateTime? _lastPoll;

  bool _disabled = false;

  void setCount(int value) => unread.value = value < 0 ? 0 : value;

  /// 使用者在 Moodle 關掉了站內通知：清單永遠是空的，但伺服器的未讀數照算。
  /// 這種數字在 App 內沒有非破壞性的辦法清掉，所以歸零並停掉輪詢，否則紅點
  /// 會一直亮著而點進去什麼都沒有。公告與通知頁再看到正常清單就會解除。
  void setDisabled(bool value) {
    _disabled = value;
    if (value) setCount(0);
  }

  /// 背景刷新。**失敗時保留上一個值**：歸零等於謊稱「沒有新通知」。
  /// [force] 之外都受 [minPollInterval] 節流。
  Future<void> refresh({bool force = false}) async {
    if (_disabled) return;
    final last = _lastPoll;
    if (!force && last != null && clock().difference(last) < minPollInterval) {
      return;
    }
    _lastPoll = clock();
    final result = await MoodleRepository.instance.getUnreadNotificationCount();
    if (result case Ok(:final data)) setCount(data);
  }

  /// 登出時歸零；不清掉會讓換帳號後的 B 看到 A 的紅點。
  void reset() {
    _lastPoll = null;
    _disabled = false;
    setCount(0);
  }
}
