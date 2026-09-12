import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/src/model/mail/mail_contact.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/pages/mail/components/mail_recipient_field.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_l10n.dart';

/// 這一頁的狀態由呼叫端持有，所以測試也照著那個形狀包一層。
class _Host extends StatefulWidget {
  const _Host({this.suggest, this.initial = const []});

  final Future<List<MailContact>> Function(String)? suggest;
  final List<String> initial;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final controller = TextEditingController();
  late List<String> addresses = [...widget.initial];

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: MailRecipientField(
            label: '收件者',
            controller: controller,
            addresses: addresses,
            onChanged: (next) => setState(() => addresses = next),
            isValid: looksLikeMailAddress,
            suggest: widget.suggest,
          ),
        ),
      );
}

/// 呼叫端持有的那份狀態。測試要讀它才看得出籤有沒有真的變。
class RecipientProbe {
  RecipientProbe._(this._state);

  final _HostState _state;

  List<String> get addresses => _state.addresses;
  TextEditingController get controller => _state.controller;
}

Future<RecipientProbe> pumpField(
  WidgetTester tester, {
  Future<List<MailContact>> Function(String)? suggest,
  List<String> initial = const [],
}) async {
  await tester.pumpWidget(_Host(suggest: suggest, initial: initial));
  return RecipientProbe._(tester.state<_HostState>(find.byType(_Host)));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestL10n();
  });

  group('收成籤', () {
    testWidgets('打到逗號就收一顆，逗號本身不留在下一顆開頭', (tester) async {
      final host = await pumpField(tester);

      await tester.enterText(find.byType(TextField), 'a@x.com,');
      await tester.pump();

      expect(host.addresses, ['a@x.com']);
      expect(host.controller.text, isEmpty);
      expect(find.text('a@x.com'), findsOneWidget);
    });

    testWidgets('分號一樣算分隔', (tester) async {
      final host = await pumpField(tester);

      await tester.enterText(find.byType(TextField), 'a@x.com;');
      await tester.pump();

      expect(host.addresses, ['a@x.com']);
    });

    testWidgets('空白不算——手機鍵盤很愛在字尾補一個空白', (tester) async {
      // 這一條是刻意的：空白當分隔的話「a@x.com 」會在使用者還在打的時候
      // 就被切掉，而網域打到一半補空白是很常見的。
      final host = await pumpField(tester);

      await tester.enterText(find.byType(TextField), 'a@x.com ');
      await tester.pump();

      expect(host.addresses, isEmpty);
      expect(host.controller.text, 'a@x.com ');
    });

    testWidgets('送出鍵也收一顆', (tester) async {
      final host = await pumpField(tester);

      await tester.enterText(find.byType(TextField), 'a@x.com');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();

      expect(host.addresses, ['a@x.com']);
    });

    testWidgets('同一個位址不會收成兩顆，大小寫不同也算同一個', (tester) async {
      // 重複收件者的結果是伺服器退信，在這裡擋掉比讓使用者自己發現好。
      final host = await pumpField(tester, initial: ['a@x.com']);

      await tester.enterText(find.byType(TextField), 'A@X.com,');
      await tester.pump();

      expect(host.addresses, ['a@x.com']);
    });

    testWidgets('還沒打完的那一截留在框裡，不會自己變成籤', (tester) async {
      final host = await pumpField(tester);

      await tester.enterText(find.byType(TextField), 'a@x');
      await tester.pump();

      expect(host.addresses, isEmpty);
      expect(host.controller.text, 'a@x');
    });
  });

  group('拿掉', () {
    testWidgets('按叉就少一顆', (tester) async {
      final host = await pumpField(tester, initial: ['a@x.com', 'b@y.com']);

      await tester.tap(find.byIcon(LucideIcons.x).first);
      await tester.pump();

      expect(host.addresses, ['b@y.com']);
    });

    testWidgets('空框按退格拿掉最後一顆', (tester) async {
      // 沒有這一條的話，刪掉打錯的那一顆要先瞄準一個 14 寬的小叉。
      final host = await pumpField(tester, initial: ['a@x.com', 'b@y.com']);

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(host.addresses, ['a@x.com']);
    });

    testWidgets('框裡還有字時退格不動籤', (tester) async {
      final host = await pumpField(tester, initial: ['a@x.com']);

      await tester.enterText(find.byType(TextField), 'b');
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(host.addresses, ['a@x.com']);
    });
  });

  testWidgets('格式不對的那一顆當場變紅，不用等按了寄出才知道', (tester) async {
    await pumpField(tester, initial: ['好的@x.com', '沒有小老鼠']);
    final scheme = ThemeData().colorScheme;

    Color colorOf(String label) => tester
        .widgetList<Material>(find.ancestor(
            of: find.text(label), matching: find.byType(Material)))
        .first
        .color!;

    expect(colorOf('沒有小老鼠'), scheme.errorContainer);
    expect(colorOf('好的@x.com'), isNot(scheme.errorContainer));
  });

  group('自動完成', () {
    Future<List<MailContact>> source(String query) async => [
          const MailContact(email: 'ta@mail.ntust.edu.tw', name: '助教'),
        ];

    testWidgets('打了字才去查，按一下建議就收成籤', (tester) async {
      final host = await pumpField(tester, suggest: source);

      await tester.enterText(find.byType(TextField), 'ta');
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('助教 <ta@mail.ntust.edu.tw>'), findsOneWidget);

      await tester.tap(find.text('助教 <ta@mail.ntust.edu.tw>'));
      await tester.pump();

      expect(host.addresses, ['ta@mail.ntust.edu.tw']);
      expect(host.controller.text, isEmpty);
    });

    testWidgets('空的關鍵字不查——一進來就掉出一串人名是噪音', (tester) async {
      var calls = 0;
      await pumpField(tester, suggest: (q) async {
        calls++;
        return const [];
      });

      await tester.enterText(find.byType(TextField), '');
      await tester.pump(const Duration(milliseconds: 250));

      expect(calls, 0);
    });

    testWidgets('已經收成籤的人不再建議一次', (tester) async {
      await pumpField(tester,
          suggest: source, initial: ['ta@mail.ntust.edu.tw']);

      await tester.enterText(find.byType(TextField), 'ta');
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('助教 <ta@mail.ntust.edu.tw>'), findsNothing);
    });
  });
}
