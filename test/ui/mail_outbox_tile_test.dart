import 'package:flutter/material.dart';
import 'package:flutter_app/src/model/mail/mail_draft.dart';
import 'package:flutter_app/src/model/mail/mail_outbox_item.dart';
import 'package:flutter_app/ui/pages/mail/components/mail_outbox_tile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_l10n.dart';

MailOutboxItem item(MailOutboxState state,
        {String subject = '請假單', List<String> to = const ['a@x.com']}) =>
    MailOutboxItem(
      id: 1,
      draft: MailDraft(to: to, subject: subject),
      state: state,
      createdMillis: 0,
    );

Future<void> pumpTile(
  WidgetTester tester,
  MailOutboxItem value, {
  int remaining = 3,
  VoidCallback? onRecall,
  VoidCallback? onRetry,
}) =>
    tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MailOutboxTile(
          item: value,
          remainingSeconds: remaining,
          index: 0,
          length: 1,
          onRecall: onRecall,
          onRetry: onRetry,
        ),
      ),
    ));

/// 寄件匣的一列。三種狀態各自只給一個動作，這一組測試釘的就是那個對應。
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestL10n();
  });

  testWidgets('等待中：看得到倒數，而且有收回鈕', (tester) async {
    var recalled = false;
    await pumpTile(tester, item(MailOutboxState.waiting),
        remaining: 3, onRecall: () => recalled = true);

    expect(find.text('3 秒後寄出'), findsOneWidget);

    await tester.tap(find.text('收回'));
    expect(recalled, isTrue);
  });

  testWidgets('到期了但還沒輪到：講「寄送中」比留在「0 秒後寄出」誠實', (tester) async {
    await pumpTile(tester, item(MailOutboxState.waiting), remaining: 0);

    expect(find.text('寄送中'), findsOneWidget);
    expect(find.text('0 秒後寄出'), findsNothing);
  });

  testWidgets('寄送中沒有收回鈕——按不到效果的鈕比不給更糟', (tester) async {
    await pumpTile(tester, item(MailOutboxState.sending));

    expect(find.text('收回'), findsNothing);
    expect(find.text('重試'), findsNothing);
  });

  testWidgets('失敗：說出失敗了，並且只給重試', (tester) async {
    var retried = false;
    await pumpTile(tester, item(MailOutboxState.failed),
        onRetry: () => retried = true);

    expect(find.text('寄送失敗'), findsOneWidget);
    expect(find.text('收回'), findsNothing);

    await tester.tap(find.text('重試'));
    expect(retried, isTrue);
  });

  testWidgets('沒有主旨時顯示（無主旨），不要留一片空白', (tester) async {
    await pumpTile(tester, item(MailOutboxState.waiting, subject: '  '));

    expect(find.text('（無主旨）'), findsOneWidget);
  });

  testWidgets('多位收件者只寫第一位加人數——那一列只有一行的寬度', (tester) async {
    await pumpTile(tester,
        item(MailOutboxState.waiting, to: ['a@x.com', 'b@y.com', 'c@z.com']));

    expect(find.text('a@x.com +2'), findsOneWidget);
  });
}
