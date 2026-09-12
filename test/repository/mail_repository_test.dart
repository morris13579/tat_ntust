import 'package:flutter_app/src/auth/app_auth_session.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/enum/mail_folder_role.dart';
import 'package:flutter_app/src/model/mail/mail_draft.dart';
import 'package:flutter_app/src/model/mail/mail_folder_json.dart';
import 'package:flutter_app/src/model/mail/mail_message_json.dart';
import 'package:flutter_app/src/repository/mail_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/store/mail_store.dart';
import 'package:flutter_app/src/store/credentials_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

class _FakeRepo extends MailRepository {
  List<MailMessageJson>? next;
  int calls = 0;
  String? lastPath;
  bool sendSucceeds = true;
  MailDraft? sentDraft;

  @override
  Future<List<MailMessageJson>?> fetchFolder(String path) async {
    calls++;
    lastPath = path;
    return next;
  }

  @override
  Future<bool> sendDraft(MailDraft draft) async {
    sentDraft = draft;
    return sendSucceeds;
  }
}

MailMessageJson message(int uid) => MailMessageJson(
      uid: uid,
      subject: '選課通知 $uid',
      fromName: '教務處',
      fromEmail: 'academic@mail.ntust.edu.tw',
      dateMillis: 1690177490000,
    );

/// 信箱 repository。`requires` 是空集合，所以這一組測試刻意都不登入。
void main() {
  late _FakeRepo repo;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestL10n();
  });

  setUp(() {
    resetAppStatics();
    repo = _FakeRepo();
    MailRepository.instance = repo;
    AuthSession.instance = AppAuthSession();
    TaskUiDelegate.instance = RecordingUi();
    ConnectivityProbe.instance = FakeConnectivityProbe();
    MailStore.instance = InMemoryMailStore();
    CredentialsStore.instance.setAccount('B11000000');
    CredentialsStore.instance.setMailPassword('mail-pw');
  });

  tearDown(() {
    MailRepository.instance = MailRepository();
    AuthSession.instance = const UninstalledAuthSession();
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
  });

  Future<List<MailMessageJson>> cached(
          [String path = MailRepository.inboxPath]) =>
      MailStore.instance.readMessages(path);

  test('沒登入也拿得到：信箱不依賴 SSO，它有自己的一組密碼', () async {
    repo.next = [message(1)];

    final result = await MailRepository.instance.getMessages();

    expect(AuthSession.instance.isSignedIn, isFalse);
    expect(result, isA<Ok<List<MailMessageJson>>>());
    expect(result.dataOrNull!.single.uid, 1);
  });

  test('信箱密碼沒設定 → NotSignedIn，而且不可重試', () async {
    // 不可重試很重要：再試一次還是沒有密碼，該做的是開密碼對話框。
    CredentialsStore.instance.setMailPassword('');

    final result = await MailRepository.instance.getMessages();

    expect(result, isA<Failed<List<MailMessageJson>>>());
    final reason = (result as Failed<List<MailMessageJson>>).reason;
    expect(reason, isA<NotSignedIn>());
    expect(reason.retryable, isFalse);
    expect(repo.calls, 0, reason: '密碼是空的就不該白跑一次連線');
  });

  test('空信箱是成功，不是失敗', () async {
    repo.next = [];

    expect(await MailRepository.instance.getMessages(),
        isA<Ok<List<MailMessageJson>>>());
  });

  test('抓到就寫進快取', () async {
    repo.next = [message(1), message(2)];

    await MailRepository.instance.getMessages();

    expect((await cached()).map((m) => m.uid), [1, 2]);
  });

  test('抓不到但快取有 → Stale；快取沒有 → Failed', () async {
    repo.next = [message(1)];
    await MailRepository.instance.getMessages();

    repo.next = null;
    expect(await MailRepository.instance.getMessages(),
        isA<Stale<List<MailMessageJson>>>());

    await MailStore.instance.clear();
    expect(await MailRepository.instance.getMessages(),
        isA<Failed<List<MailMessageJson>>>());
  });

  test('離線時直接讀快取，連問都不問', () async {
    repo.next = [message(1)];
    await MailRepository.instance.getMessages();
    final before = repo.calls;

    ConnectivityProbe.instance = FakeConnectivityProbe(online: false);

    expect(await MailRepository.instance.getMessages(),
        isA<Stale<List<MailMessageJson>>>());
    expect(repo.calls, before);
  });

  test('沒指定資料夾時預設收件匣', () async {
    repo.next = [message(1)];
    await MailRepository.instance.getMessages();

    expect(repo.lastPath, MailRepository.inboxPath);
  });

  test('不同資料夾各有各的快取，不會互相蓋掉', () async {
    // 同一個 CacheKey name 底下用 folderPath 當 id。共用一格的話換資料夾就會
    // 讀到別人的信。
    repo.next = [message(1)];
    await MailRepository.instance.getMessages(MailRepository.inboxPath);
    repo.next = [message(2), message(3)];
    await MailRepository.instance.getMessages('寄件備份匣');

    expect((await cached()).map((m) => m.uid), [1]);
    expect((await cached('寄件備份匣')).map((m) => m.uid), [2, 3]);
  });

  group('寄信', () {
    test('成功回 Ok，草稿原樣傳到 connector', () async {
      final result = await MailRepository.instance.send(const MailDraft(
        to: ['a@example.com'],
        subject: '主旨',
        body: '內容',
      ));

      expect(result, isA<Ok<bool>>());
      expect(repo.sentDraft!.to, ['a@example.com']);
      expect(repo.sentDraft!.subject, '主旨');
    });

    test('失敗回 Failed，不是靜靜當成成功', () async {
      // connector 回 false 代表信沒寄出去。這裡若判成成功，使用者會以為寄了。
      repo.sendSucceeds = false;

      final result = await MailRepository.instance
          .send(const MailDraft(to: ['a@example.com']));

      expect(result, isA<Failed<bool>>());
    });

    test('信箱密碼沒設定時 connector 自己會擋，repository 不重複判斷', () async {
      // send 沒有 hasMailPassword 的守衛：那個判斷在 connector 裡，因為它同時
      // 要拿密碼去 SMTP 認證。這條測試釘住「不要在兩個地方各判一次」。
      CredentialsStore.instance.setMailPassword('');

      await MailRepository.instance
          .send(const MailDraft(to: ['a@example.com']));

      expect(repo.sentDraft, isNotNull);
    });
  });

  group('通訊紀錄', () {
    InMemoryMailStore store() => MailStore.instance as InMemoryMailStore;

    Future<List<String>> suggest(String q) async =>
        (await MailRepository.instance.suggestContacts(q))
            .map((c) => c.email)
            .toList();

    test('收到的信把寄件者記下來，之後打兩個字就查得到', () async {
      repo.next = [message(1)];

      await MailRepository.instance.getMessages();

      expect(await suggest('academic'), ['academic@mail.ntust.edu.tw']);
    });

    test('廣告信匣與回收筒的寄件者不記——那正是使用者不想再看到的位址', () async {
      store().folders = [
        const MailFolderJson(
            path: '&XXX-', name: '廣告信匣', role: MailFolderRole.junk),
      ];
      repo.next = [message(1)];

      await MailRepository.instance.getMessages('&XXX-');

      expect(await suggest('academic'), isEmpty);
    });

    test('寄件備份匣也不記：那裡的寄件者是自己', () async {
      store().folders = [
        const MailFolderJson(
            path: 'sent', name: '寄件備份匣', role: MailFolderRole.sent),
      ];
      repo.next = [message(1)];

      await MailRepository.instance.getMessages('sent');

      expect(await suggest('academic'), isEmpty);
    });

    test('寄出去之後收件者進通訊紀錄，而且排在只寄信來過的人前面', () async {
      repo.next = [message(1)];
      await MailRepository.instance.getMessages();

      await MailRepository.instance.send(const MailDraft(
        to: ['ta@mail.ntust.edu.tw'],
      ));

      // academic 只寄信來過（sentCount 0），ta 是使用者主動寄過的。
      expect(await suggest('mail.ntust.edu.tw'),
          ['ta@mail.ntust.edu.tw', 'academic@mail.ntust.edu.tw']);
    });

    test('密件副本也記：那是使用者自己打進去的人，本機記著不會洩漏給別人', () async {
      await MailRepository.instance.send(const MailDraft(
        to: ['a@x.com'],
        bcc: ['secret@x.com'],
      ));

      expect(await suggest('secret'), ['secret@x.com']);
    });

    test('寄失敗就不記——沒寄出去的人不該進通訊紀錄', () async {
      repo.sendSucceeds = false;

      await MailRepository.instance.send(const MailDraft(to: ['a@x.com']));

      expect(await suggest('a@x'), isEmpty);
    });

    test('關鍵字是空的不給建議：一進寫信頁就掉出一串人名是噪音', () async {
      repo.next = [message(1)];
      await MailRepository.instance.getMessages();

      expect(await suggest('   '), isEmpty);
    });
  });

  test('登出會把信件庫清空', () async {
    // 信件不在 cache_ 前綴那批裡，它有自己的 SQLite 檔；漏清等於換帳號後
    // B 看得到 A 的信。SessionCleaner 有對應的一步。
    repo.next = [message(1)];
    await MailRepository.instance.getMessages();
    expect(await cached(), isNotEmpty);

    await MailStore.instance.clear();

    expect(await cached(), isEmpty);
  });
}
