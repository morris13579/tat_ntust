import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_discussion_posts.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/util/moodle_forum_edit_utils.dart';
import 'package:flutter_app/ui/components/card/section_card.dart';
import 'package:flutter_app/ui/components/editor/moodle_rich_editor.dart';
import 'package:flutter_app/ui/components/editor/moodle_rich_editor_toolbar.dart';
import 'package:flutter_app/ui/components/tile/moodle_file_tile.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_forum_rich_edit_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_l10n.dart';

/// 編輯面與附件怎麼分高度，以及**鍵盤升起時編輯面實際拿到多少**。
///
/// WebView 在 flutter_test 底下畫不出來（平台實作沒註冊），所以這一頁的量測
/// 只能在**第一格畫面**做：`onLoadFailed` 是 post-frame 才送出來的，再 pump
/// 一次整頁就換成 InlineErrorView 了。一個 testWidgets 只 pump 一次。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadTestL10n();
  });

  group('attachSlot', () {
    const gap = 8.0;
    const editorMin = 220.0;

    test('空間排得下清單時，編輯面至少 220', () {
      for (var room = 0.0; room <= 1400; room += 1) {
        final slot = CourseForumRichEditPage.attachSlot(room);
        if (slot.dense) continue;
        expect(room - gap - slot.cap, greaterThanOrEqualTo(editorMin),
            reason: 'room=$room');
      }
    });

    test('任何高度下編輯面都拿得到一半以上——沒有反過來蓋掉保留的地板', () {
      for (var room = 0.0; room <= 1400; room += 1) {
        final slot = CourseForumRichEditPage.attachSlot(room);
        expect(slot.cap, lessThanOrEqualTo((room - gap) / 2),
            reason: 'room=$room');
      }
    });

    test('連「標題＋一列」都排不下就收成一列標題', () {
      expect(CourseForumRichEditPage.attachSlot(300).dense, isTrue);
      expect(CourseForumRichEditPage.attachSlot(600).dense, isFalse);
    });

    test('高度不夠時上限會掉到卡片自己的 padding 以下——那時整張卡不畫', () {
      expect(CourseForumRichEditPage.attachSlot(40).cap, lessThan(24));
    });
  });

  group('frame', () {
    ({double pad, double gap, double dock, bool dense}) frame(double room,
            {bool keyboard = true}) =>
        CourseForumRichEditPage.frame(room: room, keyboard: keyboard);

    test('排得出 220 就一點都不收', () {
      // 402×874 打字時 body 這一層量到的就是 421。
      final f = frame(421);
      expect(f.dense, isFalse);
      expect(f.pad, 12);
      expect(f.gap, 8);
      expect(f.dock, 64);
      expect(421 - f.pad * 2 - f.gap - f.dock, greaterThanOrEqualTo(220));
    });

    test('排不出 220 就把外框收掉——橫著拿的手機都在這一格', () {
      // 874×402、鍵盤 210：body 這一層只剩 134。
      final f = frame(134);
      expect(f.dense, isTrue);
      expect(f.pad, 0);
      expect(f.gap, 4);
      expect(f.dock, 48);
      expect(134 - f.pad * 2 - f.gap - f.dock, 82);
    });

    test('鍵盤沒升起就不收：那一半歸 attachSlot 管', () {
      final f = frame(134, keyboard: false);
      expect(f.dense, isFalse);
      expect(f.pad, 12);
      expect(f.gap, 8);
    });

    test('工具列最多佔一半——再擠也要看得到自己打的字', () {
      for (var room = 0.0; room <= 600; room += 1) {
        for (final keyboard in [true, false]) {
          final f = frame(room, keyboard: keyboard);
          final inner = (room - f.pad * 2).clamp(0.0, double.infinity);
          expect(f.dock, lessThanOrEqualTo(inner / 2 + 0.001),
              reason: 'room=$room keyboard=$keyboard');
          expect(inner - f.gap - f.dock, greaterThanOrEqualTo(-0.001),
              reason: 'room=$room keyboard=$keyboard');
        }
      }
    });
  });

  group('keyboardSlots', () {
    ({bool keyboard, bool subject, bool attachments}) slots({
      required double inset,
      required double height,
      bool active = false,
    }) =>
        CourseForumRichEditPage.keyboardSlots(
          viewInsetBottom: inset,
          screenHeight: height,
          subjectActive: active,
        );

    test('鍵盤沒升起：兩張卡都留著', () {
      final s = slots(inset: 0, height: 874);
      expect(s.keyboard, isFalse);
      expect(s.subject, isTrue);
      expect(s.attachments, isTrue);
    });

    test('鍵盤升起：兩張卡都讓開', () {
      final s = slots(inset: 336, height: 874);
      expect(s.keyboard, isTrue);
      expect(s.subject, isFalse);
      expect(s.attachments, isFalse);
    });

    test('使用者正在用標題欄時它不讓開——不然點下去就會連焦點一起消失', () {
      final s = slots(inset: 336, height: 874, active: true);
      expect(s.keyboard, isTrue);
      expect(s.subject, isTrue);
      expect(s.attachments, isFalse);
    });

    test('iPad 外接鍵盤只回一條捷徑列，那不算在打字', () {
      expect(slots(inset: 55, height: 1024).keyboard, isFalse);
    });

    test('螢幕高度是 0 時不除以 0', () {
      expect(slots(inset: 336, height: 0).keyboard, isFalse);
    });
  });

  MoodleForumFile file(int i) => MoodleForumFile(
      filename: '附件$i.pdf', filepath: '/', url: 'https://example.invalid/$i');

  /// 只 pump 一格：`onLoadFailed` 是 post-frame 才送出來的，再 pump 一次
  /// 整頁就換成 InlineErrorView，什麼都量不到了。
  Future<void> pumpPage(
    WidgetTester tester, {
    required Size size,
    double textScale = 1,
    int attachments = 9,
    double bottomInset = 0,
    double topPad = 0,
    String subject = '期中考公告',
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            viewInsets: EdgeInsets.only(bottom: bottomInset),
            padding: EdgeInsets.only(top: topPad),
            viewPadding: EdgeInsets.only(top: topPad),
          ),
          child: CourseForumRichEditPage(
            postId: 951,
            isTopicPost: true,
            initialSubject: subject,
            initialHtml: '<p>內容</p>',
            existingAttachments: [
              for (var i = 0; i < attachments; i++) file(i)
            ],
            attachPolicy: const ForumAttachPolicy(
                enabled: true, maxFiles: 9, maxBytes: 10485760),
            onSend: (subject, html, keep, added, {required onProgress}) async =>
                const Ok(ForumEditOutcome()),
            onPickFiles: (_) async => <File>[],
            onCancelUpload: () {},
            onOpenAttachment: (_) async {},
          ),
        ),
      ),
    ));
  }

  double editorHeight(WidgetTester tester) =>
      tester.getSize(find.byType(MoodleRichEditor)).height;

  /// 附件卡有自己的 key：工具列現在釘在最下面，`SectionCard.last` 會是它。
  double attachHeight(WidgetTester tester) => tester
      .getSize(find.byKey(const ValueKey('rich-edit-attach-card')))
      .height;

  group('版面', () {
    testWidgets('402×874、九個附件：清單列得出來，編輯面拿得到 220', (tester) async {
      await pumpPage(tester, size: const Size(402, 874));

      expect(find.byType(MoodleFileTile), findsWidgets);
      expect(editorHeight(tester), greaterThanOrEqualTo(220));
      expect(tester.takeException(), isNull);
    });

    testWidgets('375×667、九個附件：清單列得出來，編輯面一樣拿得到 220', (tester) async {
      await pumpPage(tester, size: const Size(375, 667));

      expect(find.byType(MoodleFileTile), findsWidgets);
      expect(editorHeight(tester), greaterThanOrEqualTo(220));
      expect(tester.takeException(), isNull);
    });

    testWidgets('320×568、九個附件：附件收成一列，編輯面仍比它高', (tester) async {
      await pumpPage(tester, size: const Size(320, 568));

      // 排不下清單就只留「附件 9/9」那一列，把高度還給編輯面。
      expect(find.byType(MoodleFileTile), findsNothing);
      expect(find.textContaining('9/9'), findsOneWidget);
      expect(editorHeight(tester), greaterThan(attachHeight(tester)));
      expect(tester.takeException(), isNull);
    });

    testWidgets('320×568、字級 3.0：編輯面沒有被壓成 0，版面也沒被撐破', (tester) async {
      await pumpPage(tester, size: const Size(320, 568), textScale: 3.0);

      expect(editorHeight(tester), greaterThan(0));
      expect(tester.takeException(), isNull);
    });
  });

  /// 這一組是這次改動的成績單。數字是實測的，所以用 closeTo 釘死：任何一次
  /// 改版把編輯面又還回去，這裡就會紅。
  ///
  /// 改動前同樣的量法是 402×874/inset 405 拿到 136、375×667/inset 304 拿到
  /// 69、320×568/inset 260 拿到 31——三行字都不到。
  group('打字時', () {
    testWidgets('402×874：編輯面 325，字級 1.0', (tester) async {
      await pumpPage(tester,
          size: const Size(402, 874), bottomInset: 336, topPad: 59);

      expect(editorHeight(tester), closeTo(325, 0.5));
      // 兩張卡都讓開了，剩下的那一張 SectionCard 是釘在鍵盤上的工具列。
      expect(find.byType(MoodleFileTile), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(SectionCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('402×874、字級 2.0：一樣是 325——字級不吃編輯面', (tester) async {
      await pumpPage(tester,
          size: const Size(402, 874),
          bottomInset: 336,
          topPad: 59,
          textScale: 2.0);

      expect(editorHeight(tester), closeTo(325, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('402×874、輸入附件列還在（退回方案）：編輯面 256', (tester) async {
      await pumpPage(tester,
          size: const Size(402, 874), bottomInset: 405, topPad: 59);

      expect(editorHeight(tester), closeTo(256, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('375×667：編輯面 233，打字時也守得住 220', (tester) async {
      await pumpPage(tester,
          size: const Size(375, 667), bottomInset: 260, topPad: 20);

      expect(editorHeight(tester), closeTo(233, 0.5));
      expect(editorHeight(tester), greaterThanOrEqualTo(220));
      expect(tester.takeException(), isNull);
    });

    testWidgets('375×667、字級 2.0：一樣是 233', (tester) async {
      await pumpPage(tester,
          size: const Size(375, 667),
          bottomInset: 260,
          topPad: 20,
          textScale: 2.0);

      expect(editorHeight(tester), closeTo(233, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('320×568：外框收掉，編輯面 222——這台最小的也守得住 220', (tester) async {
      await pumpPage(tester,
          size: const Size(320, 568), bottomInset: 216, topPad: 20);

      expect(editorHeight(tester), closeTo(222, 0.5));
      expect(editorHeight(tester), greaterThanOrEqualTo(220));
      expect(tester.takeException(), isNull);
    });

    testWidgets('320×568、字級 2.0：一樣是 222', (tester) async {
      await pumpPage(tester,
          size: const Size(320, 568),
          bottomInset: 216,
          topPad: 20,
          textScale: 2.0);

      expect(editorHeight(tester), closeTo(222, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('320×568、字級 3.0：還是 222，版面沒被撐破', (tester) async {
      await pumpPage(tester,
          size: const Size(320, 568),
          bottomInset: 216,
          topPad: 20,
          textScale: 3.0);

      expect(editorHeight(tester), closeTo(222, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('工具列的下緣就釘在鍵盤上緣', (tester) async {
      await pumpPage(tester,
          size: const Size(402, 874), bottomInset: 336, topPad: 59);

      // 874 - 鍵盤 336 - body 自己的 12 padding。
      expect(tester.getRect(find.byType(MoodleRichEditorToolbar)).bottom,
          closeTo(874 - 336 - 12, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('主旨改由標題列顯示，附件數改掛在工具列上', (tester) async {
      await pumpPage(tester,
          size: const Size(402, 874), bottomInset: 336, topPad: 59);

      expect(
          find.descendant(
              of: find.byType(AppBar), matching: find.text('期中考公告')),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(AppBar),
              matching: find.byIcon(LucideIcons.pencil)),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(MoodleRichEditorToolbar),
              matching: find.byIcon(LucideIcons.paperclip)),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(MoodleRichEditorToolbar),
              matching: find.byIcon(LucideIcons.chevronDown)),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('主旨是空的時候標題列講的是「請先填標題」', (tester) async {
      await pumpPage(tester,
          size: const Size(402, 874),
          bottomInset: 336,
          topPad: 59,
          subject: '');

      // 底列的擋下原因也是同一句話，所以要指名是標題列上的那一個。
      expect(
          find.descendant(
              of: find.byType(AppBar),
              matching: find.text(R.current.forumSubjectRequired)),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  /// 橫著拿的時候整個機身只剩 402 高，鍵盤還要拿走 210。**這一組是直立那一組
  /// 的另一半**：外框收不收就是編輯面看得到幾行的差別。收到底仍然守不住
  /// [_editorMinHeight] 是螢幕本身的天花板——192 的可用高度扣掉標題列 56 與
  /// 工具列 48 就是這樣。
  group('橫著拿', () {
    testWidgets('874×402、鍵盤 210：編輯面 82（外框沒收是 38）', (tester) async {
      await pumpPage(tester, size: const Size(874, 402), bottomInset: 210);

      expect(editorHeight(tester), closeTo(82, 0.5));
      // 工具列整條都還在，只是卡片的留白讓開了。
      expect(tester.getSize(find.byType(MoodleRichEditorToolbar)).height,
          MoodleRichEditorToolbar.denseHeight);
      expect(tester.takeException(), isNull);
    });

    testWidgets('874×402、字級 2.0：一樣是 82——字級不吃編輯面', (tester) async {
      await pumpPage(tester,
          size: const Size(874, 402), bottomInset: 210, textScale: 2.0);

      expect(editorHeight(tester), closeTo(82, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('667×375、鍵盤 210：編輯面 55（外框沒收是 11）', (tester) async {
      await pumpPage(tester, size: const Size(667, 375), bottomInset: 210);

      expect(editorHeight(tester), closeTo(55, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('568×320、鍵盤 162：編輯面 48（外框沒收是 4）', (tester) async {
      await pumpPage(tester, size: const Size(568, 320), bottomInset: 162);

      expect(editorHeight(tester), closeTo(48, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('鍵盤吃掉三分之二：工具列自己切一半，版面沒被撐破', (tester) async {
      // 橫向再配一條候選字列的第三方輸入法。改動前這一格是「overflowed by
      // 50 pixels」，編輯面 0。
      await pumpPage(tester, size: const Size(568, 320), bottomInset: 216);

      expect(editorHeight(tester), greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('橫向沒有鍵盤時外框不收——那一半歸 attachSlot 管', (tester) async {
      await pumpPage(tester, size: const Size(874, 402));

      expect(tester.getSize(find.byType(MoodleRichEditorToolbar)).height,
          MoodleRichEditorToolbar.height);
      expect(tester.takeException(), isNull);
    });

    testWidgets('568×320、沒有鍵盤：標題卡自己捲，版面沒被撐破', (tester) async {
      // 改動前這一格是「overflowed by 1.00 pixels」。
      await pumpPage(tester, size: const Size(568, 320));

      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('874×402、字級 3.0、沒有鍵盤：一樣沒被撐破', (tester) async {
      // 改動前這一格是「overflowed by 43 pixels」：標題卡在最大字級下自己就
      // 比整個版面高。
      await pumpPage(tester, size: const Size(874, 402), textScale: 3.0);

      expect(tester.takeException(), isNull);
    });
  });

  /// 打字時「把這一則存下來」還按不按得到。底列整條在鍵盤後面（Scaffold 的
  /// bottomNavigationBar 貼的是螢幕底緣），所以存檔不可以只長在「先收鍵盤」
  /// 後面——收鍵盤那條路上只有一個 blur，真機上收不掉的話，剩下的就只有會丟掉
  /// 草稿的返回鍵。
  group('打字時的出口', () {
    Finder appBarSend() => find.descendant(
        of: find.byType(AppBar),
        matching: find.widgetWithIcon(IconButton, LucideIcons.send));

    testWidgets('底列的儲存鈕確實在鍵盤後面', (tester) async {
      await pumpPage(tester,
          size: const Size(402, 874), bottomInset: 336, topPad: 59);

      // 鍵盤上緣：874 - 336。
      expect(tester.getRect(find.text(R.current.forumSaveEdit)).top,
          greaterThan(874 - 336));
      expect(tester.takeException(), isNull);
    });

    testWidgets('標題列上補一顆送出，而且壓不到它', (tester) async {
      await pumpPage(tester,
          size: const Size(402, 874), bottomInset: 336, topPad: 59);

      expect(appBarSend(), findsOneWidget);
      expect(tester.getRect(appBarSend()).bottom, lessThan(874 - 336));
      expect(tester.takeException(), isNull);
    });

    testWidgets('橫著拿也一樣按得到', (tester) async {
      await pumpPage(tester, size: const Size(874, 402), bottomInset: 210);

      expect(appBarSend(), findsOneWidget);
      expect(tester.getRect(appBarSend()).bottom, lessThan(402 - 210));
      expect(tester.takeException(), isNull);
    });

    testWidgets('編輯器還沒準備好時它跟底列那顆一起停用', (tester) async {
      await pumpPage(tester,
          size: const Size(402, 874), bottomInset: 336, topPad: 59);

      expect(tester.widget<IconButton>(appBarSend()).onPressed, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('鍵盤沒升起時標題列上不多這一顆——底列本來就在', (tester) async {
      await pumpPage(tester, size: const Size(402, 874), topPad: 59);

      expect(appBarSend(), findsNothing);
      expect(find.text(R.current.forumSaveEdit), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  /// 標題卡讓開時，抓著 WebView 的那個 [Expanded] 不可以換位置：換了位置
  /// Column 就會拿型別不同的舊 element 來比對，WebView 整個重建，使用者打的字
  /// 無聲退回 initialHtml。
  ///
  /// 真頁面沒辦法 pump 兩次（第二格就變成 InlineErrorView），所以這裡用同樣
  /// 形狀的替身。它證明的是 **element 活下來**，不是平台視圖活下來——後者只有
  /// 真機測得到。
  group('收起卡片不會重建編輯面', () {
    testWidgets('第一格有標題卡、第二格沒有，中間那一格的 State 是同一個', (tester) async {
      Widget frame({required bool subject}) => MaterialApp(
            home: Scaffold(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  subject
                      ? const SizedBox(height: 60)
                      : const SizedBox.shrink(),
                  const Expanded(
                    key: ValueKey('rich-edit-editor-slot'),
                    child: _Sentinel(),
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(height: 64),
                ],
              ),
            ),
          );

      await tester.pumpWidget(frame(subject: true));
      final first = tester.state<_SentinelState>(find.byType(_Sentinel));

      await tester.pumpWidget(frame(subject: false));
      final second = tester.state<_SentinelState>(find.byType(_Sentinel));

      expect(identical(first, second), isTrue);
      expect(_SentinelState.built, 1);
    });
  });
}

class _Sentinel extends StatefulWidget {
  const _Sentinel();

  @override
  State<_Sentinel> createState() => _SentinelState();
}

class _SentinelState extends State<_Sentinel> {
  static int built = 0;

  @override
  void initState() {
    super.initState();
    built++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
