import 'package:flutter_app/src/controller/mail/mail_watch_controller.dart';
import 'package:flutter_app/src/model/mail/mail_message_json.dart';
import 'package:flutter_app/src/repository/mail_repository.dart';
import 'package:flutter_app/src/store/credentials_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/reset_statics.dart';

class _FakeRepo extends MailRepository {
  int? latest = 100;
  List<MailMessageJson>? fresh = const [];
  int latestCalls = 0;
  int fetchCalls = 0;
  int? lastAfterUid;

  @override
  Future<int?> latestUid({String folderPath = MailRepository.inboxPath}) async {
    latestCalls++;
    return latest;
  }

  @override
  Future<List<MailMessageJson>?> fetchNewerThan(int afterUid,
      {String folderPath = MailRepository.inboxPath}) async {
    fetchCalls++;
    lastAfterUid = afterUid;
    return fresh;
  }
}

MailMessageJson mail(int uid) => MailMessageJson(uid: uid, subject: '主旨 $uid');

/// App 前景時盯新信。**是輪詢，不是推播**——這台伺服器的 IDLE 收指令但從不
/// 主動吐更新（見 MailWatchController 的註解）。
void main() {
  late _FakeRepo repo;
  late MailWatchController watcher;

  /// 跑一輪，並且把 microtask 排空——broadcast stream 的事件是非同步送的，
  /// 不排空就會在事件送到訂閱者之前斷言。
  Future<void> tick() async {
    await watcher.tickForTest();
    await Future<void>.delayed(Duration.zero);
  }

  /// start() 之後第一輪（對基準）同樣要排空才看得到結果。
  Future<void> startAndSettle() async {
    watcher.start();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    resetAppStatics();
    repo = _FakeRepo();
    MailRepository.instance = repo;
    CredentialsStore.instance.setAccount('B11000000');
    CredentialsStore.instance.setMailPassword('mail-pw');
    watcher = MailWatchController();
  });

  tearDown(() {
    watcher.stop();
    MailRepository.instance = MailRepository();
  });

  test('沒設定信箱密碼就不啟動，一次連線都不發', () async {
    CredentialsStore.instance.setMailPassword('');

    watcher.start();

    expect(watcher.isRunning, isFalse);
    expect(repo.latestCalls, 0);
  });

  test('第一輪只對基準，不通知', () async {
    // 一開 App 就把信箱裡本來就有的四千封全彈出來會是災難。
    repo.latest = 4370;
    final seen = <List<MailMessageJson>>[];
    watcher.arrivals.listen(seen.add);

    await startAndSettle();

    expect(watcher.seenUid, 4370);
    expect(repo.fetchCalls, 0, reason: '第一輪不該去抓信');
    expect(seen, isEmpty);
  });

  test('第二輪拿基準去問，有新信就送出去', () async {
    repo.latest = 100;
    final seen = <List<MailMessageJson>>[];
    watcher.arrivals.listen(seen.add);
    await startAndSettle();

    repo.fresh = [mail(102), mail(101)];
    await tick();

    expect(repo.lastAfterUid, 100);
    expect(seen.single.map((m) => m.uid), [102, 101]);
    expect(watcher.seenUid, 102, reason: '基準要推到最大的那一個');
  });

  test('沒有新信就不送事件', () async {
    await startAndSettle();
    final seen = <List<MailMessageJson>>[];
    watcher.arrivals.listen(seen.add);

    repo.fresh = const [];
    await tick();

    expect(seen, isEmpty);
    expect(watcher.seenUid, 100, reason: '沒有新信基準不該動');
  });

  test('這一輪失敗時基準不能往前推', () async {
    // null 是失敗（斷網、伺服器忙）。把基準推上去等於把這段期間的信永久跳過。
    await startAndSettle();
    final seen = <List<MailMessageJson>>[];
    watcher.arrivals.listen(seen.add);

    repo.fresh = null;
    await tick();

    expect(watcher.seenUid, 100);
    expect(seen, isEmpty);
  });

  test('同一封信不會通知兩次', () async {
    await startAndSettle();
    final seen = <List<MailMessageJson>>[];
    watcher.arrivals.listen(seen.add);

    repo.fresh = [mail(101)];
    await tick();
    // 伺服器對 `UID n:*` 一定至少回一封，所以第二輪很可能又拿到同一封；
    // connector 會濾掉，這裡模擬它濾完之後的空清單。
    repo.fresh = const [];
    await tick();

    expect(seen.length, 1);
  });

  test('stop 之後不再輪詢，start 可以重複呼叫', () async {
    watcher.start();
    expect(watcher.isRunning, isTrue);
    watcher.start(); // App 每次回前景都會叫一次
    expect(watcher.isRunning, isTrue);

    watcher.stop();

    expect(watcher.isRunning, isFalse);
  });

  test('reset 把基準清掉——換帳號後不能拿舊基準去比', () async {
    await startAndSettle();
    expect(watcher.seenUid, 100);

    watcher.reset();

    expect(watcher.seenUid, isNull);
    expect(watcher.isRunning, isFalse);
  });
}
