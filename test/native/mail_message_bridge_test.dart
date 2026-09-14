import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/mail/mail_content.dart';
import 'package:flutter_app/src/model/mail/mail_message_json.dart';
import 'package:flutter_app/src/native/mail_memo.dart';
import 'package:flutter_app/src/native/mail_message_bridge.dart';
import 'package:flutter_app/src/repository/mail_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/store/credentials_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sprintf/sprintf.dart';

import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

class _FakeRepo extends MailRepository {
  Result<MailContent> content = const Ok(MailContent(html: ''));
  (int, String)? contentOf;
  Uint8List? bytes;
  final seen = <(int, String)>[];
  final moves = <String>[];

  @override
  Future<Result<MailContent>> getContent(int uid,
      {String folderPath = MailRepository.inboxPath}) async {
    contentOf = (uid, folderPath);
    return content;
  }

  @override
  Future<Uint8List?> fetchAttachment(int uid, String fetchId,
          {String folderPath = MailRepository.inboxPath}) async =>
      bytes;

  @override
  Future<bool> setSeen(int uid,
      {required bool seen, String folderPath = MailRepository.inboxPath}) async {
    this.seen.add((uid, folderPath));
    return true;
  }

  @override
  Future<bool> moveToArchive(int uid,
      {String folderPath = MailRepository.inboxPath}) async {
    moves.add('archive $uid $folderPath');
    return true;
  }

  @override
  Future<bool> moveToTrash(int uid,
      {String folderPath = MailRepository.inboxPath}) async {
    moves.add('trash $uid $folderPath');
    return true;
  }
}

void main() {
  late _FakeRepo repo;
  late MailMemo memo;
  late MailMessageBridge bridge;

  final message = MailMessageJson(
    uid: 9,
    subject: '  ',
    fromName: '教務處',
    fromEmail: 'aa@mail.ntust.edu.tw',
    dateMillis: DateTime(2026, 9, 13, 14, 5).millisecondsSinceEpoch,
    to: const ['B11000000@mail.ntust.edu.tw', 'x@y.com'],
    cc: const ['c@d.com'],
  );

  setUpAll(() async {
    await loadTestL10n();
    await initializeDateFormatting();
  });

  setUp(() {
    resetAppStatics();
    repo = _FakeRepo();
    MailRepository.instance = repo;
    CredentialsStore.instance.setAccount('b11000000');
    memo = MailMemo();
    bridge = MailMessageBridge(memo);
  });

  tearDown(() => MailRepository.instance = MailRepository());

  test('標頭：寄件者與位址不重複、收件者分開列並標出自己', () {
    final ref = memo.put('INBOX/9', 'INBOX', message);
    final header = bridge.header(ref)!;

    expect(header.subject, R.current.mailNoSubject);
    expect(header.from, '教務處');
    expect(header.fromEmail, 'aa@mail.ntust.edu.tw');
    expect(header.date, '2026/09/13 14:05');
    expect(header.recipientCount, sprintf(R.current.mailRecipientCount, [3]));
    expect(header.to.map((line) => line.mine), [true, false]);
    expect(header.cc.single.mine, isFalse);

    final bare = memo.put(
        'INBOX/1', 'INBOX', const MailMessageJson(uid: 1, fromEmail: 'a@b.c'));
    expect(bridge.header(bare)!.fromEmail, isNull);
    expect(bridge.header(bare)!.recipientCount, isNull);
    expect(bridge.header('nope'), isNull);
  });

  test('內文：附件說明、遠端圖片、深色模式要中和的元素', () async {
    final ref = memo.put('search/0/9', 'INBOX', message);
    repo.content = const Ok(MailContent(
      html: '<p style="color:#000">黑字</p><img src="https://t.example/p.gif">',
      attachments: [
        MailAttachment(
            fetchId: '2',
            name: 'a.png',
            mediaType: 'image/png',
            sizeBytes: 1258291),
      ],
    ));

    final body = await bridge.body(ref);
    expect(body.error, isNull);
    expect(body.remoteImages, isTrue);
    expect(body.html, contains('data-tat-neutral'));
    expect(body.attachments.single.meta, 'PNG · 1.2 MB');
    expect(repo.contentOf, (9, 'INBOX'));
    expect(memo.contentOf(ref), isNotNull, reason: '回信要引用它');

    repo.content = const Failed(FetchFailed());
    final failed = await bridge.body(ref);
    expect(failed.html, isNull);
    expect(failed.error, isNotNull);
  });

  test('附件寫到指定的位置，抓不到回 false', () async {
    final ref = memo.put('INBOX/9', 'INBOX', message);
    final dir = await Directory.systemTemp.createTemp('mail-attachment');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/a.bin';

    repo.bytes = Uint8List.fromList([1, 2, 3]);
    expect(await bridge.saveAttachment(ref, '2', path), isTrue);
    expect(await File(path).readAsBytes(), [1, 2, 3]);

    repo.bytes = null;
    expect(await bridge.saveAttachment(ref, '2', path), isFalse);
  });

  test('標已讀與搬信用那一列記下的資料夾', () async {
    final ref = memo.put('Archive/9', 'Archive', message);

    await bridge.markSeen(ref);
    expect(repo.seen.single, (9, 'Archive'));

    expect(await bridge.move(ref, true), isTrue);
    expect(await bridge.move(ref, false), isTrue);
    expect(repo.moves, ['archive 9 Archive', 'trash 9 Archive']);
  });
}
