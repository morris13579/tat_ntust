import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/mail/mail_content.dart';
import 'package:flutter_app/src/model/mail/mail_folder_json.dart';
import 'package:flutter_app/src/model/mail/mail_message_json.dart';
import 'package:flutter_app/src/model/mail/mail_search_hit.dart';
import 'package:flutter_app/src/repository/mail_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/store/credentials_store.dart';
import 'package:flutter_app/ui/pages/mail/mail_detail_page.dart';
import 'package:flutter_app/ui/pages/mail/mail_list_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

class _FakeRepo extends MailRepository {
  final seenFolders = <String>[];
  String? contentFolder;

  /// 收件匣是空的：有信的話清單會自己去載下一頁，那條路會真的開 socket。
  @override
  Future<Result<List<MailMessageJson>>> getMessages(
          [String folderPath = MailRepository.inboxPath]) async =>
      const Ok([]);

  @override
  Future<List<MailMessageJson>> cachedMessages(
          [String folderPath = MailRepository.inboxPath]) async =>
      const [];

  @override
  Future<List<MailFolderJson>> cachedFolders() async => const [];

  @override
  Future<Result<List<MailFolderJson>>> getFolders() async => const Ok([]);

  @override
  Future<int?> unreadCount(
          [String folderPath = MailRepository.inboxPath]) async =>
      0;

  /// 兩個資料夾各有一封 UID 7。
  @override
  Future<Result<List<MailSearchHit>>> search(String keyword,
          {String folderPath = MailRepository.inboxPath,
          List<String>? allFolderPaths}) async =>
      const Ok([
        MailSearchHit(
            MailRepository.inboxPath, MailMessageJson(uid: 7, subject: '期末報告')),
        MailSearchHit('寄件備份匣', MailMessageJson(uid: 7, subject: 'Re: 期末報告')),
      ]);

  @override
  Future<bool> setSeen(int uid,
      {required bool seen,
      String folderPath = MailRepository.inboxPath}) async {
    seenFolders.add(folderPath);
    return true;
  }

  /// 內文不回來：這一條只看內頁拿哪個資料夾去抓。
  @override
  Future<Result<MailContent>> getContent(int uid,
      {String folderPath = MailRepository.inboxPath}) {
    contentFolder = folderPath;
    return Completer<Result<MailContent>>().future;
  }
}

void main() {
  late _FakeRepo repo;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestL10n();
    await initializeDateFormatting();
  });

  setUp(() {
    resetAppStatics();
    repo = _FakeRepo();
    MailRepository.instance = repo;
    CredentialsStore.instance.setAccount('B11000000');
    CredentialsStore.instance.setMailPassword('mail-pw');
  });

  tearDown(() {
    MailRepository.instance = MailRepository();
    Get.reset();
  });

  /// 載入中畫的是無限轉圈，不能用 `pumpAndSettle`。
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('跨資料夾的搜尋結果點進去，內文與已讀都用那一封自己的資料夾', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: MailListPage()));
    await settle(tester);

    await tester.tap(find.byTooltip(R.current.search));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '報告');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);

    expect(tester.takeException(), isNull);
    await tester.tap(find.textContaining('Re: 期末報告').first);
    await settle(tester);

    final detail = tester.widget<MailDetailPage>(find.byType(MailDetailPage));
    expect(detail.folderPath, '寄件備份匣');
    expect(repo.contentFolder, '寄件備份匣');
    expect(repo.seenFolders, ['寄件備份匣']);
  });
}
