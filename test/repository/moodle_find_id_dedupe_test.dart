import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 課號 → Moodle 內部 id 的解析要去重。
///
/// 課程頁面現在一次發三個請求（檔案、公告、成績），三個都要先解析同一個
/// 課號。快取擋不住這件事：三個同時開始，第一個把結果寫進快取之前，另外
/// 兩個早就已經出發了。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => loadTestL10n());
  setUp(resetAppStatics);

  test('同一個課號同時解析三次，只會真的跑一次', () async {
    final repo = _CountingFindIdRepository();

    final results = await Future.wait([
      repo.findIdForTesting('AT1001'),
      repo.findIdForTesting('AT1001'),
      repo.findIdForTesting('AT1001'),
    ]);

    expect(results, ['moodle-42', 'moodle-42', 'moodle-42']);
    expect(repo.resolveCalls, 1,
        reason: '沒有去重的話三個分頁會把 core_course_get_courses_by_field 打三次');
  });

  test('解析完就把自己從表上移掉', () async {
    final repo = _CountingFindIdRepository();

    await repo.findIdForTesting('AT1001');

    expect(MoodleRepository.findIdInFlight, isEmpty,
        reason: '留在表上的話這個課號會永遠回同一個 Future');

    // 第二次不會再問 Moodle——但那是 CacheStore 的功勞，不是去重表的。
    // 這兩件事要分得開：去重管「同時」，快取管「之後」。
    await repo.findIdForTesting('AT1001');
    expect(repo.resolveCalls, 1);
  });

  test('失敗也要從表上移掉，不然一次失敗會把這個課號永久釘成那個例外', () async {
    final repo = _CountingFindIdRepository(fail: true);

    await expectLater(
        repo.findIdForTesting('AT1001'), throwsA(isA<TaskFailure>()));

    expect(MoodleRepository.findIdInFlight, isEmpty);
  });

  test('不同課號互不影響', () async {
    final repo = _CountingFindIdRepository();

    await Future.wait([
      repo.findIdForTesting('AT1001'),
      repo.findIdForTesting('AT1002'),
    ]);

    expect(repo.resolveCalls, 2);
  });
}

/// 只替換「真的去問 Moodle」那一步，去重與快取都走正式程式碼。
class _CountingFindIdRepository extends MoodleRepository {
  _CountingFindIdRepository({this.fail = false});

  final bool fail;
  int resolveCalls = 0;

  @override
  Future<String?> fetchCourseUrl(String courseId) async {
    resolveCalls++;
    await Future<void>.delayed(Duration.zero);
    // null 會讓 _resolveFindId 丟 TaskFailure(UnsupportedCourse())。
    return fail ? null : 'moodle-42';
  }
}
