import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_app/src/model/mail/mail_message_json.dart';
import 'package:flutter_app/src/repository/mail_repository.dart';

/// App 開著的時候盯有沒有新信，有就從 [arrivals] 送出去。
///
/// **是輪詢，不是推播。** 這台 Mail2000 的 `IDLE` 收得下指令、也回 `+ idling`，
/// 但實測掛 90 秒之後從另一條連線 `APPEND` 一封進去，這一頭一個位元組都沒收到；
/// 一送 `NOOP` 立刻回 `* 2 EXISTS`——更新是排著的，只是它從來不主動吐。所以
/// 「掛一條連線等伺服器通知」在這台機器上不成立，只能自己問。
/// 見 docs/WEBMAIL_IMAP.md §5。
///
/// 一輪檢查實測 0.3 秒（連線 + LOGIN + SELECT + 收工），[pollInterval] 一分鐘
/// 一次的成本可以接受。**只在前景跑**：背景通知這一版刻意不做，所以
/// [stop] 一定要在 App 進背景時被呼叫，否則就變成沒有人要求的背景輪詢。
class MailWatchController {
  MailWatchController();

  /// process 級單例，樣式照 `NotificationBadgeController`——它的生命週期跨
  /// 頁面，而且登出時必須歸零。
  static MailWatchController instance = MailWatchController();

  static const Duration pollInterval = Duration(minutes: 1);

  @visibleForTesting
  static Duration Function() intervalOf = () => pollInterval;

  final _arrivals = StreamController<List<MailMessageJson>>.broadcast();

  /// 新到的信，新到舊。只在 App 前景時會有事件。
  Stream<List<MailMessageJson>> get arrivals => _arrivals.stream;

  /// 已經看過的最大 UID。null 代表還沒對過基準。
  int? _seenUid;

  Timer? _timer;

  /// 上一輪還沒回來就跳過這一輪。行動網路上一次檢查可能要好幾秒，重疊只會
  /// 讓同一封信被通知兩次。
  bool _busy = false;

  bool get isRunning => _timer != null;

  @visibleForTesting
  int? get seenUid => _seenUid;

  /// 開始盯。沒設定信箱密碼就什麼都不做。
  ///
  /// 重複呼叫是安全的（App 每次回到前景都會叫一次）。
  void start() {
    if (isRunning) return;
    if (!MailRepository.instance.hasMailPassword) return;
    _timer = Timer.periodic(intervalOf(), (_) => unawaited(_tick()));
    unawaited(_tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// 登出或換帳號時歸零。不清的話換帳號後第一輪會拿舊基準去比，把 B 信箱裡
  /// 本來就有的信整批當成新信彈出來。
  void reset() {
    stop();
    _seenUid = null;
  }

  /// 測試用：直接跑一輪，不必等計時器。
  @visibleForTesting
  Future<void> tickForTest() => _tick();

  Future<void> _tick() async {
    if (_busy) return;
    _busy = true;
    try {
      // 第一輪只對基準，不通知——不然一開 App 就會被信箱裡本來就有的信洗版。
      if (_seenUid == null) {
        _seenUid = await MailRepository.instance.latestUid();
        return;
      }
      final fresh = await MailRepository.instance.fetchNewerThan(_seenUid!);
      // null 是這一輪失敗（斷網、伺服器忙）。**不要動基準**：把它往前推等於
      // 把這段期間的信永久跳過。
      if (fresh == null || fresh.isEmpty) return;

      var maxUid = _seenUid!;
      for (final m in fresh) {
        if (m.uid > maxUid) maxUid = m.uid;
      }
      _seenUid = maxUid;
      if (!_arrivals.isClosed) _arrivals.add(fresh);
    } finally {
      _busy = false;
    }
  }
}
