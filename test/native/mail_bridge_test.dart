import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/mail_connector.dart';
import 'package:flutter_app/src/controller/mail/mail_outbox_controller.dart';
import 'package:flutter_app/src/controller/mail/mail_watch_controller.dart';
import 'package:flutter_app/src/enum/mail_folder_role.dart';
import 'package:flutter_app/src/model/mail/mail_draft.dart';
import 'package:flutter_app/src/model/mail/mail_folder_json.dart';
import 'package:flutter_app/src/model/mail/mail_message_json.dart';
import 'package:flutter_app/src/model/mail/mail_page.dart';
import 'package:flutter_app/src/model/mail/mail_search_hit.dart';
import 'package:flutter_app/src/native/mail_bridge.dart';
import 'package:flutter_app/src/native/mail_memo.dart';
import 'package:flutter_app/src/repository/mail_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/store/credentials_store.dart';
import 'package:flutter_app/src/store/mail_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sprintf/sprintf.dart';

import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

class _Host extends TatMailHost {
  final lists = <MailListState>[];
  final outboxes = <List<MailOutboxRow>>[];
  final arrivals = <MailArrival>[];
  final results = <bool>[];

  MailListState get last => lists.last;

  @override
  Future<void> onList(MailListState state) async => lists.add(state);

  @override
  Future<void> onOutbox(List<MailOutboxRow> rows) async => outboxes.add(rows);

  @override
  Future<void> onArrival(MailArrival arrival) async => arrivals.add(arrival);

  @override
  Future<void> onSent(bool sent) async => results.add(sent);
}

class _FakeRepo extends MailRepository {
  Result<List<MailMessageJson>> messages = const Ok([]);
  List<MailMessageJson> cached = const [];
  Result<List<MailFolderJson>> folders = const Ok([]);
  Result<List<MailSearchHit>> searchResult = const Ok([]);
  final seen = <String>[];
  final trashed = <String>[];
  List<String>? searchedPaths;
  MailPage? page;
  MailAuthOutcome outcome = MailAuthOutcome.ok;
  List<MailMessageJson>? fresh = const [];

  @override
  Future<List<MailMessageJson>> cachedMessages(
          [String folderPath = MailRepository.inboxPath]) async =>
      cached;

  @override
  Future<List<MailFolderJson>> cachedFolders() async => const [];

  @override
  Future<Result<List<MailMessageJson>>> getMessages(
          [String folderPath = MailRepository.inboxPath]) async =>
      messages;

  @override
  Future<Result<List<MailFolderJson>>> getFolders() async => folders;

  @override
  Future<Result<List<MailSearchHit>>> search(String keyword,
      {String folderPath = MailRepository.inboxPath,
      List<String>? allFolderPaths}) async {
    searchedPaths = allFolderPaths;
    return searchResult;
  }

  @override
  Future<int?> unreadCount([String folderPath = MailRepository.inboxPath]) async =>
      null;

  @override
  Future<MailPage?> loadMore(String folderPath, int beforeUid) async => page;

  @override
  Future<MailAuthOutcome> verifyPassword(
          String account, String password) async =>
      outcome;

  @override
  Future<bool> setSeen(int uid,
      {required bool seen,
      String folderPath = MailRepository.inboxPath}) async {
    this.seen.add('$uid@$folderPath');
    return true;
  }

  @override
  Future<bool> moveToTrash(int uid,
      {String folderPath = MailRepository.inboxPath}) async {
    trashed.add('$uid@$folderPath');
    return true;
  }

  @override
  Future<int?> latestUid({String folderPath = MailRepository.inboxPath}) async =>
      10;

  @override
  Future<List<MailMessageJson>?> fetchNewerThan(int afterUid,
          {String folderPath = MailRepository.inboxPath}) async =>
      fresh;

  @override
  Future<bool> sendQueued(MailDraft draft) async => true;
}

final _now = DateTime(2026, 9, 10, 15);

MailMessageJson mail(int uid,
        {String? subject, String from = '', DateTime? date, bool seen = false}) =>
    MailMessageJson(
      uid: uid,
      subject: subject ?? '主旨 $uid',
      fromName: from,
      dateMillis: (date ?? DateTime(2026, 8, 1)).millisecondsSinceEpoch,
      seen: seen,
    );

const _inbox = MailFolderJson(
    path: 'INBOX',
    name: 'INBOX',
    role: MailFolderRole.inbox,
    messageCount: 4367,
    unreadCount: 2919);

/// 所有非同步的推送與 broadcast stream 都送到。
Future<void> settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _FakeRepo repo;
  late _Host host;
  late MailMemo memo;
  late MailBridge bridge;

  setUpAll(() async {
    await loadTestL10n();
    await initializeDateFormatting();
  });

  setUp(() {
    resetAppStatics();
    repo = _FakeRepo();
    MailRepository.instance = repo;
    MailStore.instance = InMemoryMailStore();
    MailWatchController.instance = MailWatchController();
    MailOutboxController.instance = MailOutboxController();
    MailOutboxController.holdOf = () => const Duration(seconds: 30);
    CredentialsStore.instance.setAccount('B11000000');
    CredentialsStore.instance.setMailPassword('mail-pw');
    host = _Host();
    memo = MailMemo();
    bridge = MailBridge(memo, host: host, clock: () => _now);
  });

  tearDown(() {
    MailWatchController.instance.reset();
    MailOutboxController.instance.reset();
    MailOutboxController.holdOf = () => MailOutboxController.holdWindow;
    MailRepository.instance = MailRepository();
  });

  group('設定', () {
    test('沒設定密碼時先畫設定頁，帳號換成完整位址', () {
      CredentialsStore.instance.setMailPassword('');
      final status = bridge.status();
      expect(status.configured, isFalse);
      expect(status.address, 'B11000000@mail.ntust.edu.tw');
    });

    test('密碼錯與連不上分開講，驗過才存', () async {
      CredentialsStore.instance.setMailPassword('');
      repo.outcome = MailAuthOutcome.rejected;
      final rejected = await bridge.setup('wrong');
      expect(rejected.ok, isFalse);
      expect(rejected.error, R.current.mailPasswordRejected);
      expect(bridge.status().configured, isFalse);

      repo.outcome = MailAuthOutcome.unreachable;
      expect((await bridge.setup('pw')).error, R.current.mailPasswordUnreachable);

      repo.outcome = MailAuthOutcome.ok;
      expect((await bridge.setup('right')).ok, isTrue);
      expect(bridge.status().configured, isTrue);
    });
  });

  group('清單', () {
    test('先推轉圈、再推本機那一份、網路回來再換掉，依今天本週更早分組', () async {
      repo.cached = [mail(1, subject: '本機的')];
      repo.messages = Ok([
        mail(3, date: DateTime(2026, 9, 10, 9, 5)),
        mail(2, date: DateTime(2026, 9, 7, 12)),
        mail(1),
      ]);
      await bridge.open();
      await settle();

      expect(host.lists.first.loading, isTrue);
      expect(
          host.lists.any((s) => s.sections
              .expand((section) => section.rows)
              .any((row) => row.subject == '本機的')),
          isTrue);
      final last = host.last;
      expect(last.loading, isFalse);
      expect(last.sections.map((s) => s.title), [
        R.current.deadlineToday,
        R.current.deadlineThisWeek,
        R.current.notificationGroupEarlier,
      ]);
      expect(last.sections.first.rows.single.time, '09:05');
      expect(last.folderTitle, R.current.mailFolderInbox);
      expect(last.more, MailMoreState.more);
    });

    test('密碼不見了就回設定頁', () async {
      repo.messages = const Failed(NotSignedIn());
      await bridge.open();
      await settle();

      expect(host.last.needsSetup, isTrue);
      expect(host.last.error, isNotNull);
    });

    test('資料夾同一個角色只留一個，空的收起來，目前所在的那一個不算', () async {
      repo.folders = const Ok([
        _inbox,
        MailFolderJson(
            path: 'sent-zh',
            name: '寄件備份匣',
            role: MailFolderRole.sent,
            messageCount: 0,
            unreadCount: 0),
        MailFolderJson(
            path: 'sent-en',
            name: 'Sent Messages',
            role: MailFolderRole.sent,
            messageCount: 3),
        MailFolderJson(path: 'mine', name: '自己的'),
      ]);
      await bridge.open();
      await settle();

      final folders = host.last.folders;
      expect(folders.map((f) => f.path), ['INBOX', 'sent-zh', 'mine']);
      expect(folders.first.inbox, isTrue);
      expect(folders.first.count, '4,367 封 · 2,919 未讀');
      expect(folders[1].empty, isTrue);
      expect(folders[2].empty, isFalse, reason: '問不到數量的不算空');
      expect(folders[2].count, isNull);

      await bridge.openFolder('sent-zh');
      await settle();
      expect(host.last.folderTitle, R.current.mailFolderSent);
      expect(host.last.folders[1].empty, isFalse);
    });

    test('捲到底：失敗就閂住，空的一頁當作到底', () async {
      repo.messages = Ok([mail(50), mail(49)]);
      await bridge.open();
      await settle();

      await bridge.loadMore();
      await settle();
      expect(host.last.more, MailMoreState.failed);

      repo.page = const MailPage(messages: [], hasMore: true, uidValidity: 0);
      await bridge.loadMore();
      await settle();
      expect(host.last.more, MailMoreState.end);
    });

    test('點進去標已讀、丟進回收筒就把那一列拿掉', () async {
      repo.messages = Ok([mail(3)]);
      await bridge.open();
      await settle();

      final ref = host.last.sections.single.rows.single.ref;
      await bridge.markSeen(ref);
      await settle();
      expect(host.last.sections.single.rows.single.unread, isFalse);

      expect(await bridge.moveToTrash(ref), isTrue);
      await settle();
      expect(host.last.sections, isEmpty);
      expect(host.last.emptyMessage, R.current.mailEmpty);
    });
  });

  group('搜尋', () {
    setUp(() async {
      repo.messages = Ok([mail(1)]);
      repo.folders = const Ok([
        _inbox,
        MailFolderJson(path: 'sent', name: '寄件備份匣', role: MailFolderRole.sent),
      ]);
      await bridge.open();
      await settle();
    });

    test('結果不分組，換範圍時在全部資料夾再找一次，關掉搜尋回到清單', () async {
      repo.searchResult = Ok([
        MailSearchHit('INBOX', mail(5, subject: '請假')),
        MailSearchHit('INBOX', mail(6, subject: '請假單')),
      ]);
      await bridge.search('  請假 ', false);
      await settle();
      expect(host.last.keyword, '請假');
      expect(host.last.sections, isEmpty);
      expect(host.last.results.map((r) => r.uid), [5, 6]);
      expect(host.last.resultCount,
          sprintf(R.current.mailSearchResultCount, [2]));
      expect(repo.searchedPaths, isNull);

      await bridge.search('請假', true);
      await settle();
      expect(repo.searchedPaths, ['INBOX', 'sent']);
      expect(host.last.searchAll, isTrue);

      repo.searchResult = const Ok([]);
      await bridge.search('沒有這封', true);
      await settle();
      expect(host.last.emptyMessage, R.current.mailSearchEmpty);

      await bridge.endSearch();
      await settle();
      expect(host.last.keyword, isNull);
      expect(host.last.searchAll, isFalse);
      expect(host.last.sections, isNotEmpty);
    });

    test('跨資料夾的 UID 會撞，每一列還是指得到自己那一封與它的資料夾', () async {
      repo.searchResult = Ok([
        MailSearchHit('INBOX', mail(7, subject: 'A')),
        MailSearchHit('sent', mail(7, subject: 'B')),
      ]);
      await bridge.search('x', true);
      await settle();

      final refs = host.last.results.map((r) => r.ref).toList();
      expect(refs.toSet(), hasLength(2));
      expect(memo[refs[0]]!.folderPath, 'INBOX');
      expect(memo[refs[1]]!.message.subject, 'B');
      expect(memo[refs[1]]!.folderPath, 'sent');

      await bridge.markSeen(refs[1]);
      expect(repo.seen, ['7@sent']);

      expect(await bridge.moveToTrash(refs[1]), isTrue);
      await settle();
      expect(repo.trashed, ['7@sent']);
      expect(host.last.results.map((r) => r.subject), ['A']);
    });
  });

  test('新信：好幾封時標題是數量，清單跟著重抓，橫幅點得開最新那一封', () async {
    repo.messages = Ok([mail(1)]);
    await bridge.open();
    await settle();
    bridge.startWatch();
    await settle();

    repo.fresh = [mail(12, subject: ' ', from: '體育室'), mail(11)];
    repo.messages = Ok([mail(12), mail(11), mail(1)]);
    await MailWatchController.instance.tickForTest();
    await settle();

    final arrival = host.arrivals.single;
    expect(arrival.title, sprintf(R.current.mailNewMessages, [2]));
    expect(arrival.message, R.current.mailNoSubject);
    expect(memo[arrival.ref]!.message.uid, 12);
    expect(host.last.sections.expand((s) => s.rows).map((r) => r.uid),
        [12, 11, 1]);
  });

  test('寄件匣：倒數、收回，寄完回報一次', () async {
    await bridge.restoreOutbox();
    await settle();
    expect(host.outboxes.last, isEmpty);

    final id = await MailOutboxController.instance.enqueue(
        const MailDraft(to: ['a@x.com', 'b@y.com'], subject: '請假單'));
    await settle();
    final row = host.outboxes.last.single;
    expect(row.phase, MailOutboxPhase.waiting);
    expect(row.status, sprintf(R.current.mailOutboxWaiting, [30]));
    expect(row.subject, '請假單');
    expect(row.recipients, 'a@x.com +1');

    expect(await bridge.recall(id!), isTrue);
    await settle();
    expect(host.outboxes.last, isEmpty);

    await MailOutboxController.instance
        .enqueue(const MailDraft(to: ['a@x.com']));
    MailOutboxController.holdOf = () => Duration.zero;
    await MailOutboxController.instance.pumpForTest();
    await settle();
    expect(host.results, [true]);
    expect(host.outboxes.last, isEmpty);
  });
}
