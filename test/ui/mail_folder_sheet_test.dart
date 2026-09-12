import 'package:flutter/material.dart';
import 'package:flutter_app/src/enum/mail_folder_role.dart';
import 'package:flutter_app/src/model/mail/mail_folder_json.dart';
import 'package:flutter_app/ui/components/sheet/tat_bottom_sheet.dart';
import 'package:flutter_app/ui/pages/mail/components/mail_folder_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../helpers/test_l10n.dart';

MailFolderJson folder(
  String path,
  MailFolderRole role, {
  int messages = 0,
  int unread = 0,
  String? name,
}) =>
    MailFolderJson(
      path: path,
      name: name ?? path,
      role: role,
      messageCount: messages,
      unreadCount: unread,
    );

/// 資料夾選單：去重、計數與「空的收起來」。
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestL10n();
    Intl.defaultLocale = 'zh_TW';
  });

  group('同一個角色只留一個', () {
    test('中英兩套並存時只留先出現的那一個', () {
      // 伺服器上「寄件備份匣」（Mail2000 原生）與 Sent（其他郵件軟體建的）
      // 並存，不去重畫面上會出現兩個一模一樣的「寄件備份」。
      final unique = uniqueMailFoldersByRole([
        folder('寄件備份匣', MailFolderRole.sent),
        folder('Sent', MailFolderRole.sent),
      ]);

      expect(unique.map((f) => f.path).toList(), ['寄件備份匣']);
    });

    test('認不出角色的一個都不去重', () {
      // other 是「使用者自己建的」，兩個不同的自建資料夾當然要各留一個。
      final unique = uniqueMailFoldersByRole([
        folder('專題', MailFolderRole.other),
        folder('社團', MailFolderRole.other),
      ]);

      expect(unique.length, 2);
    });
  });

  group('計數', () {
    test('四位數加千分位，未讀接在後面', () {
      expect(
        mailFolderCount(folder('INBOX', MailFolderRole.inbox,
            messages: 4367, unread: 2919)),
        '4,367 封 · 2,919 未讀',
      );
    });

    test('沒有未讀就只寫總數', () {
      expect(
        mailFolderCount(folder('INBOX', MailFolderRole.inbox, messages: 12)),
        '12 封',
      );
    });

    test('問不到數量就不畫這一行', () {
      // STATUS 失敗時是 -1。顯示 0 會讓人以為資料夾是空的，而「問不到」與
      // 「真的沒有」是兩件事。
      expect(
        mailFolderCount(const MailFolderJson(path: 'X', name: 'X')),
        isNull,
      );
    });
  });

  group('空資料夾收起來', () {
    final folders = [
      folder('INBOX', MailFolderRole.inbox, messages: 4367, unread: 2919),
      folder('寄件備份匣', MailFolderRole.sent),
      folder('草稿匣', MailFolderRole.drafts),
      folder('垃圾桶', MailFolderRole.trash),
    ];

    Future<void> pumpSheet(WidgetTester tester,
        {String selected = 'INBOX'}) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showMailFolderSheet(
                context: context,
                folders: folders,
                selected: selected,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('一開始只看得到有信的那一個', (tester) async {
      await pumpSheet(tester);

      expect(find.text('收件匣'), findsOneWidget);
      expect(find.text('寄件備份'), findsNothing);
      expect(find.text('顯示 3 個空資料夾'), findsOneWidget);
    });

    testWidgets('展開之後三個都在，而且順序不變', (tester) async {
      await pumpSheet(tester);

      await tester.tap(find.text('顯示 3 個空資料夾'));
      await tester.pumpAndSettle();

      expect(find.text('寄件備份'), findsOneWidget);
      expect(find.text('草稿'), findsOneWidget);
      expect(find.text('回收筒'), findsOneWidget);
      expect(find.text('收合空資料夾'), findsOneWidget);
    });

    testWidgets('目前所在的資料夾就算是空的也留著', (tester) async {
      // 不然切進空資料夾之後，那一列會從選單裡消失——而它正是打勾的那一個。
      await pumpSheet(tester, selected: '草稿匣');

      expect(find.text('草稿'), findsOneWidget);
      expect(find.text('顯示 2 個空資料夾'), findsOneWidget);
    });

    testWidgets('點一列就回傳那個路徑', (tester) async {
      await pumpSheet(tester);

      await tester.tap(find.text('收件匣'));
      await tester.pumpAndSettle();

      expect(find.byType(TatSheetOptionRow<String>), findsNothing);
    });
  });
}
