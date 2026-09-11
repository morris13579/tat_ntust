import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/store/key_value_store.dart';
import 'package:in_app_review/in_app_review.dart';

/// 商店評分的詢問時機。
///
/// **只在「剛做完一件成功的事」之後問**，而不是開 App 就問：那一刻使用者對
/// App 的印象是它剛幫上忙。系統的評分視窗一年只給幾次配額，浪費在冷啟動那一瞬
/// 間就沒了。
///
/// 三道門檻，全部通過才問：
/// 1. 這支 App 被成功用過至少 [_minSuccesses] 次（不是啟動次數——啟動不代表
///    有用到東西）。
/// 2. 距離上次詢問超過 [_minDaysBetweenAsks] 天。
/// 3. 這個版本沒問過。
///
/// 真正要不要顯示由系統決定（`requestReview` 常常什麼都不做，這是 Apple 與
/// Google 的設計），所以這裡不假設它一定會出現，也不記「已經評分過」——我們
/// 根本收不到那個結果。記的是「問過了」。
class StoreReviewService {
  StoreReviewService(this._store,
      {InAppReview? review, DateTime Function()? now})
      : _review = review ?? InAppReview.instance,
        _now = now ?? DateTime.now;

  static StoreReviewService instance =
      StoreReviewService(SharedPrefsKeyValueStore());

  final KeyValueStore _store;
  final InAppReview _review;
  final DateTime Function() _now;

  static const _successCountKey = 'store_review_success_count';
  static const _lastAskedKey = 'store_review_last_asked';
  static const _askedVersionKey = 'store_review_asked_version';

  static const int _minSuccesses = 8;
  static const int _minDaysBetweenAsks = 90;

  /// 使用者剛順利完成一件事（課表載好、成績查到）。呼叫端不必自己判斷時機。
  ///
  /// 整支流程都是 fire-and-forget：評分視窗出不來、或 plugin 在測試環境不可
  /// 用，都不該讓呼叫端的功能受影響，所以任何例外只記 log。
  Future<void> recordSuccess(String version) async {
    try {
      final count = (await _store.readInt(_successCountKey) ?? 0) + 1;
      await _store.writeInt(_successCountKey, count);
      if (!await _shouldAsk(count, version)) return;
      if (!await _review.isAvailable()) return;

      // 先記「問過了」再問：系統視窗不回報結果，如果先問後記而中途被砍掉，
      // 下一次就會再問一遍。寧可少問一次。
      await _store.writeInt(
          _lastAskedKey, _now().millisecondsSinceEpoch ~/ 1000);
      await _store.writeString(_askedVersionKey, version);
      await _review.requestReview();
    } catch (e, stack) {
      Log.eWithStack('store review: $e', stack);
    }
  }

  Future<bool> _shouldAsk(int successCount, String version) async {
    if (successCount < _minSuccesses) return false;
    if (await _store.readString(_askedVersionKey) == version) return false;
    final lastAsked = await _store.readInt(_lastAskedKey);
    if (lastAsked == null) return true;
    final since = _now()
        .difference(DateTime.fromMillisecondsSinceEpoch(lastAsked * 1000));
    return since.inDays >= _minDaysBetweenAsks;
  }
}
