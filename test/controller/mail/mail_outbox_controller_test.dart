import 'dart:async';

import 'package:flutter_app/src/controller/mail/mail_outbox_controller.dart';
import 'package:flutter_app/src/model/mail/mail_draft.dart';
import 'package:flutter_app/src/model/mail/mail_outbox_item.dart';
import 'package:flutter_app/src/repository/mail_repository.dart';
import 'package:flutter_app/src/store/mail_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/reset_statics.dart';

class _FakeRepo extends MailRepository {
  bool sendSucceeds = true;
  int sendCalls = 0;
  final sent = <MailDraft>[];

  /// 給「送到一半」那條測試用：設了就卡在這裡，直到測試自己 complete。
  Completer<void>? block;

  @override
  Future<bool> sendQueued(MailDraft draft) async {
    sendCalls++;
    sent.add(draft);
    if (block != null) await block!.future;
    return sendSucceeds;
  }
}

const draft = MailDraft(to: ['a@x.com'], subject: '請假單');

/// 長到不會在測試中自己到期。要送出去時用 `fire()` 把窗口縮成 0。
const _longHold = Duration(seconds: 30);

/// 寄件匣。收回只在信還沒交給 SMTP 之前成立——這一組測試釘的就是那條界線。
void main() {
  late _FakeRepo repo;
  late MailOutboxController outbox;

  setUp(() {
    resetAppStatics();
    repo = _FakeRepo();
    MailRepository.instance = repo;
    MailStore.instance = InMemoryMailStore();
    outbox = MailOutboxController();
    MailOutboxController.instance = outbox;
    // 預設一個長窗口，`enqueue` 內部那一跳就什麼都不做——不然「排進去」和
    // 「送出去」會在同一個 await 裡打架，測到的是競態而不是行為。
    MailOutboxController.holdOf = () => _longHold;
  });

  tearDown(() {
    outbox.reset();
    MailOutboxController.instance = MailOutboxController();
    MailOutboxController.holdOf = () => MailOutboxController.holdWindow;
    MailRepository.instance = MailRepository();
  });

  /// 讓窗口立刻到期並跑一跳。真實情況是等五秒，測試不該真的等。
  Future<void> fire() async {
    MailOutboxController.holdOf = () => Duration.zero;
    await outbox.pumpForTest();
    MailOutboxController.holdOf = () => _longHold;
  }

  test('排進去就看得到，而且是等待中', () async {
    await outbox.enqueue(draft);

    expect(outbox.items.single.draft.subject, '請假單');
    expect(outbox.items.single.state, MailOutboxState.waiting);
  });

  test('窗口過了才真的送出去', () async {
    await outbox.enqueue(draft);

    await outbox.pumpForTest();

    expect(repo.sendCalls, 0, reason: '還在收回窗口內就不該交給 SMTP');
    expect(outbox.items.single.state, MailOutboxState.waiting);
  });

  test('窗口到了就送，成功之後那一列不見了', () async {
    await outbox.enqueue(draft);

    await fire();

    expect(repo.sendCalls, 1);
    expect(repo.sent.single.to, ['a@x.com']);
    expect(outbox.items, isEmpty);
  });

  test('失敗留著並標成失敗，重試次數加一', () async {
    repo.sendSucceeds = false;
    await outbox.enqueue(draft);

    await fire();

    expect(outbox.items.single.state, MailOutboxState.failed);
    expect(outbox.items.single.attempts, 1);
  });

  test('失敗的不會自己重送——自動重寄會讓對方收到兩封', () async {
    repo.sendSucceeds = false;
    await outbox.enqueue(draft);
    await fire();

    await fire();
    await fire();

    expect(repo.sendCalls, 1);
  });

  test('重試把它放回等待，時間重算所以又有得收回', () async {
    repo.sendSucceeds = false;
    await outbox.enqueue(draft);
    await fire();

    repo.sendSucceeds = true;
    await outbox.retry(outbox.items.single.id);

    expect(outbox.items.single.state, MailOutboxState.waiting);
    await fire();
    expect(outbox.items, isEmpty);
    expect(repo.sendCalls, 2);
  });

  group('收回', () {
    test('還在等的收得回來，而且 SMTP 一次都沒被打', () async {
      await outbox.enqueue(draft);

      expect(await outbox.recall(outbox.items.single.id), isTrue);
      expect(outbox.items, isEmpty);
      expect(repo.sendCalls, 0);
    });

    test('已經交給 SMTP 的收不回來——信可能已經在對方伺服器上了', () async {
      // 讓它真的卡在送信那一步，而不是手動把狀態塞成 sending。
      repo.block = Completer<void>();
      await outbox.enqueue(draft);
      final id = outbox.items.single.id;
      MailOutboxController.holdOf = () => Duration.zero;
      final pump = outbox.pumpForTest();
      MailOutboxController.holdOf = () => _longHold;
      await Future<void>.delayed(Duration.zero);
      expect(outbox.items.single.state, MailOutboxState.sending);

      expect(await outbox.recall(id), isFalse);
      expect(outbox.items, isNotEmpty);

      repo.block!.complete();
      await pump;
    });

    test('收回不存在的那一封不會炸', () async {
      expect(await outbox.recall(999), isFalse);
    });
  });

  group('回報', () {
    test('成功與失敗都送得出去，畫面才知道要 toast 哪一句', () async {
      final seen = <bool>[];
      final sub = outbox.results.listen((r) => seen.add(r.sent));

      await outbox.enqueue(draft);
      await fire();
      repo.sendSucceeds = false;
      await outbox.enqueue(draft);
      await fire();
      await Future<void>.delayed(Duration.zero);

      expect(seen, [true, false]);
      await sub.cancel();
    });
  });

  group('restore', () {
    test('上一次被殺掉時停在寄送中的，標成失敗讓使用者自己決定', () async {
      // 我們不知道 SMTP 有沒有收下。自動重寄會讓對方收到兩封。
      await outbox.enqueue(draft);
      final id = outbox.items.single.id;
      await MailRepository.instance.updateOutbox(id, MailOutboxState.sending);

      await outbox.restore();

      expect(outbox.items.single.state, MailOutboxState.failed);
      expect(repo.sendCalls, 0);
    });

    test('等待中的那些照樣讀回來', () async {
      await outbox.enqueue(draft);
      outbox.reset();

      await outbox.restore();

      expect(outbox.items.single.state, MailOutboxState.waiting);
    });
  });

  test('倒數只對等待中的那些有意義', () async {
    await outbox.enqueue(draft);
    final waiting = outbox.items.single;

    expect(outbox.remainingSeconds(waiting), greaterThan(0));
    expect(
        outbox
            .remainingSeconds(waiting.copyWith(state: MailOutboxState.sending)),
        0);
    expect(
        outbox
            .remainingSeconds(waiting.copyWith(state: MailOutboxState.failed)),
        0);
  });

  test('reset 把佇列與 timer 都收掉', () async {
    await outbox.enqueue(draft);

    outbox.reset();

    expect(outbox.items, isEmpty);
    expect(outbox.isRunning, isFalse);
  });
}
