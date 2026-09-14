import 'dart:io';

import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/mail_config.dart';
import 'package:flutter_app/src/controller/mail/mail_outbox_controller.dart';
import 'package:flutter_app/src/model/mail/mail_contact.dart';
import 'package:flutter_app/src/model/mail/mail_content.dart';
import 'package:flutter_app/src/model/mail/mail_message_json.dart';
import 'package:flutter_app/src/native/mail_compose_bridge.dart';
import 'package:flutter_app/src/native/mail_memo.dart';
import 'package:flutter_app/src/store/credentials_store.dart';
import 'package:flutter_app/src/store/mail_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

void main() {
  late MailMemo memo;
  late MailComposeBridge bridge;
  late String ref;

  setUpAll(loadTestL10n);

  setUp(() {
    resetAppStatics();
    MailStore.instance = InMemoryMailStore();
    MailOutboxController.instance = MailOutboxController();
    MailOutboxController.holdOf = () => const Duration(seconds: 30);
    CredentialsStore.instance.setAccount('B11000000');
    memo = MailMemo();
    bridge = MailComposeBridge(memo);
    ref = memo.put(
      'INBOX/4',
      'INBOX',
      const MailMessageJson(
        uid: 4,
        subject: 'Re: 期中考',
        fromEmail: 'Prof@x.edu',
        to: ['b11000000@mail.ntust.edu.tw', 'prof@x.edu', 'ta@x.edu'],
        cc: ['TA@x.edu', 'c@x.edu'],
      ),
    );
    memo.rememberContent(
        ref, const MailContent(html: '<p>第一行</p><p>第二行</p>'));
  });

  tearDown(() {
    MailOutboxController.instance.reset();
    MailOutboxController.holdOf = () => MailOutboxController.holdWindow;
  });

  group('開始寫', () {
    test('回覆只寄給寄件者，主旨不重複加前綴，引言與提示字進編輯器', () {
      final reply = bridge.start(MailComposeKind.reply, ref);
      expect(reply.to.map((r) => r.address), ['Prof@x.edu']);
      expect(reply.subject, 'Re: 期中考');
      expect(reply.editorScript, contains('gt; 第一行'));
      expect(reply.editorScript, contains('dataset.placeholder'));
      expect(reply.editorScript, contains(R.current.mailBodyHint));
      expect(reply.pickLimit, 5);
    });

    test('全部回覆帶上收件者與副本，剔掉自己與大小寫不同的重複', () {
      final all = bridge.start(MailComposeKind.replyAll, ref);
      expect(all.to.map((r) => r.address), ['Prof@x.edu', 'ta@x.edu', 'c@x.edu']);
    });

    test('轉寄沒有收件者；寫新信什麼都不帶', () {
      final forward = bridge.start(MailComposeKind.forward, ref);
      expect(forward.to, isEmpty);
      expect(forward.subject, 'Fwd: Re: 期中考');

      final blank = bridge.start(MailComposeKind.blank, '');
      expect(blank.to, isEmpty);
      expect(blank.subject, isEmpty);
      expect(blank.editorScript, contains('setContent("")'));
    });
  });

  test('收成籤：切開、去重、格式不對的標出來', () {
    final next = bridge.addRecipients(['a@x.com'], 'A@x.com, b@y.com; 不是位址');
    expect(next.map((r) => r.address), ['a@x.com', 'b@y.com', '不是位址']);
    expect(next.map((r) => r.valid), [true, true, false]);
  });

  test('自動完成不建議已經收成籤的人', () async {
    await MailStore.instance.rememberContacts(const [
      MailContact(email: 'wang@x.edu', name: '王小明', sentCount: 2),
      MailContact(email: 'wu@x.edu'),
    ]);
    final hits = await bridge.suggest('w', ['WU@x.edu']);
    expect(hits.map((h) => h.label), ['王小明 <wang@x.edu>']);
  });

  test('附件總大小超過上限整批不收，讀不到檔案也不收', () async {
    final dir = await Directory.systemTemp.createTemp('mail-compose');
    addTearDown(() => dir.delete(recursive: true));
    final small = File('${dir.path}/small.txt')..writeAsStringSync('hi');
    final big = File('${dir.path}/big.bin');
    final handle = big.openSync(mode: FileMode.write);
    handle.setPositionSync(MailConfig.maxAttachmentBytes);
    handle.writeByteSync(0);
    handle.closeSync();

    expect((await bridge.checkAttachments([], [small.path])).accepted,
        [small.path]);
    final tooBig = await bridge.checkAttachments([small.path], [big.path]);
    expect(tooBig.accepted, isEmpty);
    expect(tooBig.error, R.current.mailAttachTooLarge);
    final missing = await bridge.checkAttachments([], ['${dir.path}/nope']);
    expect(missing.error, R.current.mailActionFailed);
  });

  group('寄出', () {
    MailSendRequest request({String pendingTo = '', List<String> cc = const []}) =>
        MailSendRequest(
          to: const [],
          cc: cc,
          bcc: const [],
          pendingTo: pendingTo,
          pendingCc: '',
          pendingBcc: '',
          subject: '請假',
          attachments: const [],
        );

    test('沒有收件者或位址不對就不收，錯在哪裡講清楚', () async {
      expect((await bridge.send(request())).error,
          R.current.mailRecipientRequired);
      expect((await bridge.send(request(pendingTo: 'a@x.com', cc: ['壞掉']))).error,
          R.current.mailInvalidRecipient);
      expect(MailOutboxController.instance.items, isEmpty);
    });

    test('還在打的那一截也算收件者；編輯器拿不到內容時退回帶進來的引言', () async {
      bridge.start(MailComposeKind.reply, ref);
      final result = await bridge.send(request(pendingTo: 'a@x.com'));

      expect(result.queuedId, isNotNull);
      expect(result.holdSeconds, MailOutboxController.holdWindow.inSeconds);
      final draft = MailOutboxController.instance.items.single.draft;
      expect(draft.to, ['a@x.com']);
      expect(draft.body, startsWith('<p></p>'));
    });
  });
}
