import 'dart:async';

import 'package:flutter_app/src/controller/course_data/course_forum_thread_controller.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_discussion_posts.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/store/cache_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 送出回覆之後的重抓：整串（含剛送出的那一則）不可以在來回途中變成 null，
/// 那在畫面上就是 `ResultView` 的一頁轉圈，等於「自己的回覆消失」。
class _GatedRepo extends MoodleRepository {
  final gate = Completer<void>();
  int calls = 0;

  @override
  Future<Result<List<MoodleForumPost>>> getDiscussionPosts(
      int discussionId) async {
    calls++;
    await gate.future;
    return Ok<List<MoodleForumPost>>(
        [MoodleForumPost(id: 900), MoodleForumPost(id: 950)]);
  }
}

void main() {
  late _GatedRepo repo;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestL10n();
  });

  setUp(() {
    resetAppStatics();
    repo = _GatedRepo();
    MoodleRepository.instance = repo;
  });

  tearDown(() {
    MoodleRepository.instance = MoodleRepository();
  });

  CourseForumThreadController controller() {
    final c = CourseForumThreadController(discussionId: 7701);
    addTearDown(c.dispose);
    return c;
  }

  test('keepVisible：重抓途中畫面上的貼文留著', () async {
    final c = controller();
    await c.appendPost(MoodleForumPost(id: 900));

    final loading = c.loadPosts(keepVisible: true);
    await Future<void>.delayed(Duration.zero);

    expect(repo.calls, 1, reason: '真的在飛');
    expect(c.posts.value, isA<Ok<List<MoodleForumPost>>>());
    expect(c.posts.value?.dataOrNull, hasLength(1));

    repo.gate.complete();
    await loading;
    expect(c.posts.value?.dataOrNull, hasLength(2));
  });

  test('預設會先清成 null：進頁面與使用者按的重試都要看得到轉圈', () async {
    final c = controller();
    await c.appendPost(MoodleForumPost(id: 900));

    final loading = c.loadPosts();
    await Future<void>.delayed(Duration.zero);

    expect(c.posts.value, isNull);

    repo.gate.complete();
    await loading;
    expect(c.posts.value?.dataOrNull, hasLength(2));
  });

  group('樂觀併入之後寫回快取', () {
    /// 少了這一步，離線重開會看到已經刪掉的貼文、或編輯前的內容。
    setUp(() {
      ConnectivityProbe.instance = FakeConnectivityProbe(online: false);
    });

    tearDown(() {
      ConnectivityProbe.instance = const PlatformConnectivityProbe();
    });

    Future<List<MoodleForumPost>?> cached() =>
        CacheStore.instance.read(MoodleRepository.discussionPostsKey(7701));

    test('replacePost：同 id 就地取代，快取跟著換', () async {
      final c = controller();
      await c.appendPost(MoodleForumPost(id: 900, message: '<p>舊的</p>'));

      await c.replacePost(MoodleForumPost(id: 900, message: '<p>改過了</p>'));

      expect(c.posts.value?.dataOrNull, hasLength(1));
      expect(c.posts.value!.dataOrNull!.single.message, '<p>改過了</p>');
      final blob = await cached();
      expect(blob!.single.message, '<p>改過了</p>');
    });

    test('removePost：那一列從畫面與快取一起消失', () async {
      final c = controller();
      await c.appendPost(MoodleForumPost(id: 900));
      await c.appendPost(MoodleForumPost(id: 950));

      await c.removePost(950);

      expect(c.posts.value!.dataOrNull!.map((p) => p.id), [900]);
      expect((await cached())!.map((p) => p.id), [900]);
    });

    test('removePost 在還沒有任何貼文時什麼都不做（不會寫一份空的進快取）', () async {
      final c = controller();

      await c.removePost(950);

      expect(c.posts.value, isNull);
      expect(await cached(), isNull);
    });
  });

  group('fresh', () {
    test('Ok 才算新鮮；null 與 Stale 都不是——編輯與刪除的能力旗標會過期', () async {
      final c = controller();
      expect(c.fresh, isFalse);

      await c.appendPost(MoodleForumPost(id: 900));
      expect(c.fresh, isTrue);

      c.posts.value = Stale<List<MoodleForumPost>>(
          [MoodleForumPost(id: 900)], const Offline());
      expect(c.fresh, isFalse);
    });
  });
}
