import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/model/mail/mail_message_json.dart';
import 'package:flutter_app/ui/pages/mail/components/mail_tile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../helpers/test_l10n.dart';

MailMessageJson message({
  required String subject,
  bool seen = false,
  String from = '學務處生輔組大宗郵件',
}) =>
    MailMessageJson(
      uid: 1,
      subject: subject,
      fromName: from,
      dateMillis: DateTime(2026, 9, 10, 9, 43).millisecondsSinceEpoch,
    );

Future<void> pumpTile(WidgetTester tester, MailMessageJson m,
    {String highlight = ''}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: MailTile(
        message: m,
        now: DateTime(2026, 9, 10, 14, 0),
        index: 0,
        length: 1,
        highlight: highlight,
        onTap: () {},
      ),
    ),
  ));
}

/// 信件清單的一列。
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestL10n();
    await initializeDateFormatting();
    Intl.defaultLocale = 'zh_TW';
  });

  testWidgets('主旨一個字都不動，含 [TaiwanTech] 前綴', (tester) async {
    // 這一列先前會把 [TaiwanTech] 剝掉。那是在竄改寄件者寫的主旨——畫面上
    // 顯示的必須就是他寄出來的那一行。
    const subject = '[TaiwanTech] 【生活輔導組】-115年第21屆校園傑出青年選拔開始了';

    await pumpTile(tester, message(subject: subject));

    expect(find.textContaining('[TaiwanTech]', findRichText: true),
        findsOneWidget);
  });

  testWidgets('連續兩個前綴也照樣留著', (tester) async {
    const subject = '[TaiwanTech] [TaiwanTech] 資安通知';

    await pumpTile(tester, message(subject: subject));

    final text = tester.widget<Text>(find.byType(Text).last);
    expect(text.textSpan!.toPlainText(), contains('[TaiwanTech] [TaiwanTech]'));
  });

  testWidgets('未讀畫圓點，已讀不畫', (tester) async {
    await pumpTile(tester, message(subject: '未讀', seen: false));
    expect(find.byKey(const ValueKey('mail-unread-1')), findsOneWidget);

    await pumpTile(
        tester,
        MailMessageJson(
          uid: 1,
          subject: '已讀',
          seen: true,
          dateMillis: DateTime(2026, 9, 10, 9, 43).millisecondsSinceEpoch,
        ));
    expect(find.byKey(const ValueKey('mail-unread-1')), findsNothing);
  });

  testWidgets('搜尋命中的那一段標底色，其餘不動', (tester) async {
    await pumpTile(tester, message(subject: '【圖書館活動】開放報名！'), highlight: '報名');

    final span = tester.widget<Text>(find.byType(Text).last).textSpan!;
    // 標色是分段做的，所以整串文字必須還原得回去——切錯段會漏字。
    expect(span.toPlainText(), contains('【圖書館活動】開放報名！'));
  });

  testWidgets('沒有主旨時給那句預設，不是一片空白', (tester) async {
    await pumpTile(tester, message(subject: '   '));

    expect(find.textContaining('無主旨', findRichText: true), findsOneWidget);
  });

  group('滑開時的圓角', () {
    // 清單中間那一列靜止時是 4 的圓角（同一群的節奏），頭尾是 14。
    const middle = BorderRadius.all(Radius.circular(4));
    const first = BorderRadius.vertical(
        top: Radius.circular(14), bottom: Radius.circular(4));
    // 兩排按鈕露出的寬度：右滑一顆 0.3，左滑兩顆 0.56。
    const startExtent = 0.3;
    const endExtent = 0.56;

    test('沒滑開就是清單的節奏，一個像素都不動', () {
      expect(mailSwipeCardRadius(middle, 0, startExtent), middle);
    });

    test('完全拉開時，朝著按鈕那一側和按鈕一樣圓', () {
      // **這一條先前是紅的。** `SlidableController.ratio` 被夾在 extentRatio
      // 以內，完全拉開只有 0.3／0.56；先前直接把它當 0..1 的進度用，圓角只走
      // 到 6.4／8.5，整段拖曳看起來像沒動。
      final left = mailSwipeCardRadius(middle, startExtent, startExtent);
      expect(left.topLeft.x, TatTokens.radiusCard);
      expect(left.bottomLeft.x, TatTokens.radiusCard);

      final right = mailSwipeCardRadius(middle, -endExtent, endExtent);
      expect(right.topRight.x, TatTokens.radiusCard);
    });

    test('另一側維持節奏值——兩側一起變圓會讓整群散掉', () {
      final left = mailSwipeCardRadius(middle, startExtent, startExtent);
      expect(left.topRight.x, 4);

      final right = mailSwipeCardRadius(middle, -endExtent, endExtent);
      expect(right.topLeft.x, 4);
    });

    test('拖到一半就是一半：整段跟著手指走，不是到點才跳', () {
      final half = mailSwipeCardRadius(middle, startExtent / 2, startExtent);
      expect(half.topLeft.x, (4 + 12) / 2);

      // 四分之一、四分之三都在線上。
      expect(
          mailSwipeCardRadius(middle, startExtent / 4, startExtent).topLeft.x,
          4 + (12 - 4) * 0.25);
      expect(
          mailSwipeCardRadius(middle, startExtent * 3 / 4, startExtent)
              .topLeft
              .x,
          4 + (12 - 4) * 0.75);
    });

    test('兩邊各除以自己的 extent，露出的寬度不同不影響手感', () {
      // 左滑露出兩顆（0.56）、右滑一顆（0.3）；拉到各自的一半，圓角要一樣。
      expect(
          mailSwipeCardRadius(middle, startExtent / 2, startExtent).topLeft.x,
          mailSwipeCardRadius(middle, -endExtent / 2, endExtent).topRight.x);
    });

    test('ratio 的正負決定哪一側：正是右滑（露出左邊那一排）', () {
      final left = mailSwipeCardRadius(middle, 0.15, startExtent);
      expect(left.topLeft.x, greaterThan(left.topRight.x));
      final right = mailSwipeCardRadius(middle, -0.28, endExtent);
      expect(right.topRight.x, greaterThan(right.topLeft.x));
    });

    test('超過 extent（可以拖過頭的情況）就停在 12，不會繼續長', () {
      expect(mailSwipeCardRadius(middle, 0.9, startExtent).topLeft.x,
          TatTokens.radiusCard);
    });

    test('沒在動的那一側，四個角一個都不准動', () {
      // **這一條先前是紅的。** 用 `BorderRadius.horizontal(left:, right:)` 會把
      // 上面那個角的值複製到下面：第一列靜止是「上 14、下 4」，手指一碰下面
      // 那兩個角就跳成 14，連沒在動的右側也一起變。
      final left = mailSwipeCardRadius(first, startExtent / 2, startExtent);

      expect(left.topRight, first.topRight);
      expect(left.bottomRight, first.bottomRight);
    });

    test('動的那一側，上下兩角各自從自己的起點長', () {
      // 第一列是上 14、下 4：拉到一半時上面走 14→13、下面走 4→8。
      final left = mailSwipeCardRadius(first, startExtent / 2, startExtent);

      expect(left.topLeft.x, (14 + 12) / 2);
      expect(left.bottomLeft.x, (4 + 12) / 2);
    });

    test('本來就比按鈕圓的（頭尾那兩列）會被拉回 12，不是繼續變大', () {
      // 14 → 12 是變小。那正是要的：拉開之後兩邊該長得一樣。
      expect(mailSwipeCardRadius(first, startExtent, startExtent).topLeft.x,
          TatTokens.radiusCard);
    });

    test('extentRatio 是 0 的話原樣回傳，不要除以零', () {
      expect(mailSwipeCardRadius(middle, 0.2, 0), middle);
    });
  });
}
