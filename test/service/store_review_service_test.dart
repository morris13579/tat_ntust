import 'package:flutter_app/src/service/store_review_service.dart';
import 'package:flutter_app/src/store/key_value_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_review/in_app_review.dart';

/// 評分詢問的三道門檻。真的要不要跳視窗由系統決定，這裡只測「我們有沒有問」。
class _MemoryStore implements KeyValueStore {
  final map = <String, Object?>{};

  @override
  Future<int?> readInt(String key) async => map[key] as int?;
  @override
  Future<void> writeInt(String key, int value) async => map[key] = value;
  @override
  Future<String?> readString(String key) async => map[key] as String?;
  @override
  Future<void> writeString(String key, String value) async => map[key] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeReview implements InAppReview {
  int asked = 0;

  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<void> requestReview() async => asked++;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  late _MemoryStore store;
  late _FakeReview review;
  var now = DateTime(2026, 1, 1);

  StoreReviewService build() =>
      StoreReviewService(store, review: review, now: () => now);

  setUp(() {
    store = _MemoryStore();
    review = _FakeReview();
    now = DateTime(2026, 1, 1);
  });

  Future<void> succeed(int times, {String version = '1.0.0'}) async {
    for (var i = 0; i < times; i++) {
      await build().recordSuccess(version);
    }
  }

  test('用得還不夠多就不問——開一次 App 就跳評分是最惹人厭的做法', () async {
    await succeed(7);
    expect(review.asked, 0);
  });

  test('累積夠了才問，而且只問一次', () async {
    await succeed(12);
    expect(review.asked, 1);
  });

  test('同一版問過就不再問，換版本也要等冷卻期', () async {
    await succeed(8);
    expect(review.asked, 1);

    await succeed(8, version: '1.1.0');
    expect(review.asked, 1, reason: '距離上次詢問還不到冷卻期');

    now = now.add(const Duration(days: 91));
    await succeed(1, version: '1.1.0');
    expect(review.asked, 2);
  });
}
