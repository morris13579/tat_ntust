import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_app/src/model/mail/mail_draft.dart';
import 'package:flutter_app/src/model/mail/mail_outbox_item.dart';
import 'package:flutter_app/src/repository/mail_repository.dart';
import 'package:get/get.dart';

/// 寄件匣。按下寄出之後那封信先排進這裡，[holdWindow] 過了才真的交給 SMTP。
///
/// **為什麼要有那幾秒的等待**：那是「收回」唯一能成立的窗口。信一旦進了 SMTP
/// 就收不回來——它可能已經在對方伺服器上了，任何號稱能收回的做法都是騙人的。
/// 所以這裡誠實地把可收回的範圍限定在還沒送出去的那段時間。
///
/// **為什麼不是按下寄出就送**：一趟 SMTP 在手機網路上可能十幾秒，先前那段時間
/// 畫面是一個關不掉的遮罩，按錯了也追不回來。排進佇列之後寫信頁可以立刻關掉，
/// 「在寄什麼」變成清單上看得到的一列。
///
/// process 級單例，樣式照 [MailWatchController]：它的生命週期跨頁面，
/// 而且登出時必須歸零。
class MailOutboxController {
  MailOutboxController();

  static MailOutboxController instance = MailOutboxController();

  /// 可以收回的窗口。
  ///
  /// 五秒是折衷：太短來不及按，太長會讓使用者以為信卡住了。Gmail 的預設也是
  /// 五秒。測試用 [holdOf] 改掉它，不要 `pump` 五秒真實時間。
  static const Duration holdWindow = Duration(seconds: 5);

  @visibleForTesting
  static Duration Function() holdOf = () => holdWindow;

  /// 倒數要每秒重畫一次，所以心跳就是一秒。佇列空了就把 timer 收掉——沒有信
  /// 在等的時候不該有任何東西在跑。
  static const Duration tick = Duration(seconds: 1);

  /// 寄件匣裡的信，排進來的順序。
  final items = <MailOutboxItem>[].obs;

  final _results = StreamController<MailOutboxResult>.broadcast();

  /// 每一封的結果。畫面拿它來 toast，順便把收件匣重抓一次。
  Stream<MailOutboxResult> get results => _results.stream;

  Timer? _timer;

  /// 同時只送一封。並行送會讓同一組帳密開好幾條 SMTP 連線，而這台伺服器
  /// 對同時連線數沒有任何承諾。
  bool _busy = false;

  bool get isRunning => _timer != null;

  /// 讀回上次沒寄完的那些。App 冷啟動時要叫一次——不叫的話前一次被殺掉的
  /// App 留下的信會留在資料庫裡沒有人管。
  Future<void> restore() async {
    final stored = await MailRepository.instance.readOutbox();
    // 上一次被殺掉時停在「寄送中」的那些狀態不可信：我們不知道 SMTP 有沒有
    // 收下。標成失敗讓使用者自己決定要不要重試，比自動重寄安全——自動重寄
    // 會讓對方收到兩封。
    for (final item in stored) {
      if (item.state == MailOutboxState.sending) {
        await MailRepository.instance
            .updateOutbox(item.id, MailOutboxState.failed);
      }
    }
    items.assignAll(await MailRepository.instance.readOutbox());
    _ensureTimer();
  }

  /// 排一封進去，回它的 id。
  ///
  /// 回 null 代表連寫進資料庫都失敗了，呼叫端要讓使用者知道這封信沒有被收下。
  /// 回 id 是為了讓呼叫端能立刻給一顆「收回」——見 [TatToast.action]。
  Future<int?> enqueue(MailDraft draft) async {
    final id = await MailRepository.instance.enqueueOutbox(draft);
    if (id < 0) return null;
    items.assignAll(await MailRepository.instance.readOutbox());
    _ensureTimer();
    return id;
  }

  /// 收回。**只有還在等的那些收得回來**；已經交給 SMTP 的收不回來，所以這裡
  /// 回 false，畫面不該給那一列一顆收回鈕。
  Future<bool> recall(int id) async {
    final item = items.firstWhereOrNull((e) => e.id == id);
    if (item == null || item.state == MailOutboxState.sending) return false;
    await MailRepository.instance.deleteOutbox(id);
    items.assignAll(await MailRepository.instance.readOutbox());
    _stopIfIdle();
    return true;
  }

  /// 重試失敗的那一封：時間重算，所以重試之後同樣有幾秒可以再收回。
  Future<void> retry(int id) async {
    await MailRepository.instance.updateOutbox(id, MailOutboxState.waiting);
    items.assignAll(await MailRepository.instance.readOutbox());
    _ensureTimer();
  }

  /// 還要等幾秒才送出去。已經在送或已經失敗的回 0。
  int remainingSeconds(MailOutboxItem item) {
    if (item.state != MailOutboxState.waiting) return 0;
    final due = item.createdMillis + holdOf().inMilliseconds;
    final left = due - DateTime.now().millisecondsSinceEpoch;
    return left <= 0 ? 0 : (left / 1000).ceil();
  }

  void _ensureTimer() {
    if (items.isEmpty || _timer != null) return;
    _timer = Timer.periodic(tick, (_) => unawaited(_pump()));
    unawaited(_pump());
  }

  void _stopIfIdle() {
    if (items.isNotEmpty) return;
    _timer?.cancel();
    _timer = null;
  }

  /// 測試用。真實的心跳是 [tick]。
  @visibleForTesting
  Future<void> pumpForTest() => _pump();

  Future<void> _pump() async {
    // 倒數的秒數是算出來的，所以每一跳都要讓畫面重畫一次。
    items.refresh();
    if (_busy) return;
    final due = items.firstWhereOrNull(
        (e) => e.state == MailOutboxState.waiting && remainingSeconds(e) == 0);
    if (due == null) {
      _stopIfIdle();
      return;
    }

    _busy = true;
    // 先落地成「寄送中」再送：這一刻之後收回鈕就不該出現了。
    await MailRepository.instance.updateOutbox(due.id, MailOutboxState.sending);
    items.assignAll(await MailRepository.instance.readOutbox());
    final ok = await MailRepository.instance.sendQueued(due.draft);
    _busy = false;

    if (ok) {
      await MailRepository.instance.deleteOutbox(due.id);
    } else {
      await MailRepository.instance.updateOutbox(due.id, MailOutboxState.failed,
          attempts: due.attempts + 1);
    }
    items.assignAll(await MailRepository.instance.readOutbox());
    _results.add(MailOutboxResult(draft: due.draft, sent: ok));
    _stopIfIdle();
  }

  /// 登出時歸零。佇列本身由 `MailStore.clear()` 清掉。
  void reset() {
    _timer?.cancel();
    _timer = null;
    _busy = false;
    items.clear();
  }
}

/// 一封信寄完了的結果。
class MailOutboxResult {
  const MailOutboxResult({required this.draft, required this.sent});

  final MailDraft draft;
  final bool sent;
}
