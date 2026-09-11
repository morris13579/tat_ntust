import 'package:dio/dio.dart' show CancelToken, DioException, RequestOptions;
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_discussion_posts.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/store/cache_store.dart';
import 'package:flutter_app/src/util/moodle_forum_edit_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/moodle_forum_fixtures.dart';
import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 回覆寫入路徑的規格。刻意走真正的 connector，只把傳輸層（`wsPost`）換掉：
/// 要驗的正是「送出去幾次、送了什麼、失敗怎麼講」。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordingUi ui;
  final sent = <Map<String, dynamic>>[];

  setUpAll(() async {
    await loadTestL10n();
  });

  setUp(() {
    resetAppStatics();
    sent.clear();
    MoodleRepository.instance = MoodleRepository();
    AuthSession.instance = FakeAuthSession();
    // 一律回答「重試」：重試政策若是 askUser，這個假 UI 會讓它再送一次。
    ui = RecordingUi(decisions: const [
      RetryDecision.retry,
      RetryDecision.retry,
      RetryDecision.retry,
    ]);
    TaskUiDelegate.instance = ui;
    ConnectivityProbe.instance = FakeConnectivityProbe();
    MoodleWebApiConnector.wsToken = 'tok';
  });

  tearDown(() {
    MoodleRepository.instance = MoodleRepository();
    AuthSession.instance = const UninstalledAuthSession();
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
  });

  /// 記下每一次送出去的參數，並回一份指定的回應。
  void respondWith(dynamic Function() body) {
    MoodleWebApiConnector.wsPost = (ConnectorParameter parameter) async {
      sent.add(Map<String, dynamic>.from(parameter.data as Map));
      return body();
    };
  }

  group('postReply', () {
    test('成功回 Ok，內容是伺服器算好的那一篇；自己不寫快取', () async {
      respondWith(() => loadMoodleForumFixture('add_discussion_post'));

      final result = await MoodleRepository.instance
          .postReply(postId: 900, subject: 'Re: 期中考', text: '謝謝老師');

      expect(result, isA<Ok<ForumReplyOutcome>>());
      expect(result.dataOrNull?.post.id, 950);
      expect(result.dataOrNull?.post.capabilities?.reply, isTrue);
      // 沒有附件就沒有話要說。
      expect(result.dataOrNull?.warning, isNull);
      // 寫入路徑沒有 cache:，併回快取是 saveDiscussionPosts 的事。
      expect(
          await CacheStore.instance
              .read(MoodleRepository.discussionPostsKey(7701)),
          isNull);
    });

    test('capabilities 的 edit / delete 讀得進來（舊快取沒有這兩個 key，預設 false）', () async {
      respondWith(() => loadMoodleForumFixture('add_discussion_post'));

      final result = await MoodleRepository.instance
          .postReply(postId: 900, subject: 's', text: 'm');

      expect(result.dataOrNull!.post.capabilities?.edit, isTrue);
      expect(result.dataOrNull!.post.capabilities?.delete, isTrue);
    });

    test('nopostforum → 對應好的中文句子，伺服器的英文原文不會出現', () async {
      respondWith(
          () => loadMoodleForumFixture('add_discussion_post_nopostforum'));

      final result = await MoodleRepository.instance
          .postReply(postId: 900, subject: 's', text: 'm');

      expect(result, isA<Failed<ForumReplyOutcome>>());
      final reason = (result as Failed<ForumReplyOutcome>).reason;
      expect(reason, isA<FetchFailed>());
      expect(reason.message, R.current.forumErrorNoPermission);
      expect(reason.message, isNot(contains('Sorry')));
    });

    test('認不得的 errorcode → forumSendError', () async {
      respondWith(() => const {
            'exception': 'moodle_exception',
            'errorcode': 'somethingelse',
            'message': 'Whatever went wrong',
          });

      final result = await MoodleRepository.instance
          .postReply(postId: 900, subject: 's', text: 'm');

      expect((result as Failed<ForumReplyOutcome>).reason.message,
          R.current.forumSendError);
    });

    test('離線 → Failed(Offline)，而且一個請求都沒送出去', () async {
      ConnectivityProbe.instance = FakeConnectivityProbe(online: false);
      respondWith(() => loadMoodleForumFixture('add_discussion_post'));

      final result = await MoodleRepository.instance
          .postReply(postId: 900, subject: 's', text: 'm');

      expect((result as Failed<ForumReplyOutcome>).reason, isA<Offline>());
      expect(sent, isEmpty);
    });

    test('使用者一直按「重試」也只會送出一次——這一支沒有冪等鍵', () async {
      respondWith(
          () => loadMoodleForumFixture('add_discussion_post_nopostforum'));

      await MoodleRepository.instance
          .postReply(postId: 900, subject: 's', text: 'm');

      expect(sent, hasLength(1));
      expect(ui.confirmCalls, 0, reason: 'retry: none 連問都不該問');
    });

    test('使用者按取消 → 說「已取消上傳」，不是「送出失敗；請重新整理確認是否已送出」', () async {
      final token = CancelToken();
      MoodleWebApiConnector.wsPost = (parameter) async {
        token.cancel();
        throw DioException.requestCancelled(
            requestOptions: RequestOptions(), reason: null);
      };

      final result = await MoodleRepository.instance
          .postReply(postId: 900, subject: 's', text: 'm', cancelToken: token);

      // 什麼都還沒送出去，叫人去找一則不存在的貼文是錯的。
      expect((result as Failed<ForumReplyOutcome>).reason.message,
          R.current.forumSendCancelled);
    });
  });

  group('saveDiscussionPosts', () {
    test('併回快取之後，離線再讀得到剛送出的那一則（Stale）', () async {
      final posts = fixturePosts();
      final added = MoodleForumPost(
        id: 950,
        message: '<p>謝謝老師</p>',
        hasparent: true,
        parentid: 900,
        discussionid: 7701,
        timecreated: 1756940000,
      );

      await MoodleRepository.instance
          .saveDiscussionPosts(7701, [...posts, added]);

      ConnectivityProbe.instance = FakeConnectivityProbe(online: false);
      final result = await MoodleRepository.instance.getDiscussionPosts(7701);

      expect(result, isA<Stale<List<MoodleForumPost>>>());
      expect(result.dataOrNull!.map((p) => p.id), [900, 901, 902, 903, 950]);
    });
  });
}
