import 'package:flutter_app/src/auth/app_auth_session.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/model/announcement/announcement_json.dart';
import 'package:flutter_app/src/repository/app_notice_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/store/cache_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// Remote Config 的 `_remoteConfig` 是 `late static`，測試不能碰真的那一支。
class _FakeRepo extends AppNoticeRepository {
  List<AnnouncementInfoJson>? next;
  int calls = 0;

  @override
  Future<List<AnnouncementInfoJson>> fetchNotices() async {
    calls++;
    final value = next;
    if (value == null) throw Exception('remote config 掛了');
    return value;
  }
}

AnnouncementInfoJson notice(String title) => AnnouncementInfoJson(
      title: title,
      content: '內文',
      // startTime 是裝著台北牆上時間的 UTC 欄位，快取來回不可以把它變成本地時間。
      startTime: DateTime.utc(2026, 9, 6, 1),
      endTime: DateTime.utc(2026, 10, 6, 1),
      test: false,
    );

/// App 公告 repository：它是唯一一個 `requires` 是空集合的呼叫。
void main() {
  late _FakeRepo repo;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestL10n();
  });

  setUp(() {
    resetAppStatics();
    repo = _FakeRepo();
    AppNoticeRepository.instance = repo;
    // 真的那一顆 AuthSession，而且沒有憑證：沒登入也要看得到 App 公告。
    AuthSession.instance = AppAuthSession();
    TaskUiDelegate.instance = RecordingUi();
    ConnectivityProbe.instance = FakeConnectivityProbe();
  });

  tearDown(() {
    AppNoticeRepository.instance = AppNoticeRepository();
    AuthSession.instance = const UninstalledAuthSession();
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
  });

  Future<List<AnnouncementInfoJson>?> cached() =>
      CacheStore.instance.read(AppNoticeRepository.noticesKey());

  test('沒登入也拿得到（requires 是空集合，不會被擋在登入那一關）', () async {
    repo.next = [notice('維護公告')];

    final result = await AppNoticeRepository.instance.getNotices();

    expect(AuthSession.instance.isSignedIn, isFalse);
    expect(result, isA<Ok<List<AnnouncementInfoJson>>>());
    expect(result.dataOrNull!.single.title, '維護公告');
  });

  test('空清單是成功，不是失敗', () async {
    repo.next = [];

    final result = await AppNoticeRepository.instance.getNotices();

    expect(result, isA<Ok<List<AnnouncementInfoJson>>>());
    expect(result.dataOrNull, isEmpty);
  });

  test('抓到就寫進快取，而且 UTC 的發布時間沒有被位移', () async {
    repo.next = [notice('維護公告')];

    await AppNoticeRepository.instance.getNotices();

    final saved = await cached();
    expect(saved!.single.startTime, DateTime.utc(2026, 9, 6, 1));
  });

  test('抓不到但快取有 → Stale；快取沒有 → Failed', () async {
    repo.next = [notice('維護公告')];
    await AppNoticeRepository.instance.getNotices();

    repo.next = null;
    expect(await AppNoticeRepository.instance.getNotices(),
        isA<Stale<List<AnnouncementInfoJson>>>());

    await CacheStore.instance.removeEntry(AppNoticeRepository.noticesKey());
    expect(await AppNoticeRepository.instance.getNotices(),
        isA<Failed<List<AnnouncementInfoJson>>>());
  });

  test('離線時直接讀快取，連問都不問', () async {
    repo.next = [notice('維護公告')];
    await AppNoticeRepository.instance.getNotices();
    final before = repo.calls;

    ConnectivityProbe.instance = FakeConnectivityProbe(online: false);
    final result = await AppNoticeRepository.instance.getNotices();

    expect(result, isA<Stale<List<AnnouncementInfoJson>>>());
    expect(repo.calls, before);
  });
}
