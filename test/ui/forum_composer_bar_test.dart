import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/util/moodle_forum_edit_utils.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/forum_composer_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:sprintf/sprintf.dart';

import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 常駐回覆列的規格。這一條列不碰 repository：送出、挑檔、取消都由呼叫端
/// 注入，所以整組測試都不需要網路、快取或登入。
///
/// 舊撰寫頁那五個「回覆」行為在這裡逐條接手——草稿的邊界從一頁搬到一條列，
/// 保證等級必須一樣。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordingUi ui;
  late Directory temp;

  setUpAll(() async {
    await loadTestL10n();
  });

  setUp(() {
    resetAppStatics();
    ui = RecordingUi();
    TaskUiDelegate.instance = ui;
    temp = Directory.systemTemp.createTempSync('tat_forum_bar');
  });

  tearDown(() {
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// 同步 I/O：widget 測試跑在假時鐘裡，測試主體上的 `await` 真 I/O 不會完成。
  File pickable(String name, {int bytes = 8}) {
    final f = File('${temp.path}/$name');
    f.writeAsBytesSync(List<int>.filled(bytes, 65));
    return f;
  }

  /// 挑完檔案要 `File.length()`，那是真的 I/O，得先把真的事件迴圈讓出去。
  Future<void> tapAndFlush(WidgetTester tester, Finder finder,
      {Finder? until}) async {
    // **整個點擊要跑在真的時鐘裡。** 挑完檔案頁面會 `await File.length()`，
    // 那是真的 I/O；在假時鐘下點下去，那個 future 沒有機會 resolve，接著的
    // pump 就畫出一個還沒有檔案的畫面。先前用「讓出幾輪 Duration.zero」去賭
    // 它會回來，整套測試平行跑、機器忙的時候就會賭輸——那正是這幾支偶發紅的
    // 原因。改成把 tap 本身放進 runAsync，處理鏈整條都在真時鐘上跑完再 pump。
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    if (until == null) return;
    // 機器很忙的時候那 50ms 還是可能不夠。有 [until] 就等到東西真的出現為止
    // ——這才是唯一不必猜時間的做法。逾時不自己丟，讓後面的斷言去報錯，訊息
    // 才看得出是什麼沒出現。
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (until.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pumpAndSettle();
    }
  }

  /// `IconButton` 自己 build 出 `Tooltip`，所以 tooltip 是它的**子孫**，
  /// 要往上找才拿得到那顆按鈕。
  Finder iconButtonWithTooltip(String tooltip) => find.ancestor(
      of: find.byTooltip(tooltip), matching: find.byType(IconButton));

  Finder sendButton() => iconButtonWithTooltip(R.current.forumSend);

  bool sendEnabled(WidgetTester tester) =>
      tester.widget<IconButton>(sendButton()).onPressed != null;

  Future<void> pump(
    WidgetTester tester, {
    required Future<bool> Function(String text, List<File> files) onSend,
    String? targetLabel,
    String topicLabel = '期中考公告',
    bool canAttach = false,
    int maxAttachments = 0,
    int maxBytes = 0,
    List<File> picked = const [],
    List<bool>? drafts,
    List<bool>? busies,
    VoidCallback? onAimAtRoot,
    VoidCallback? onCancelUpload,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        // 正式的位置就在 body 的最下面（不是 bottomNavigationBar，那裡會被
        // 鍵盤蓋住），測試的骨架照著擺。
        body: Column(children: [
          const Expanded(child: SizedBox.shrink()),
          ForumComposerBar(
            hintText: R.current.forumReplyHint,
            targetLabel: targetLabel,
            topicLabel: topicLabel,
            canAttach: canAttach,
            maxAttachments: maxAttachments,
            maxBytes: maxBytes,
            onPickFiles: (remaining) async => picked,
            onSend: (text, files, {required onProgress}) => onSend(text, files),
            onCancelUpload: onCancelUpload ?? () {},
            onAimAtRoot: onAimAtRoot ?? () {},
            onScrollToTarget: () {},
            onDraftChanged: (has) => drafts?.add(has),
            onBusyChanged: (busy) => busies?.add(busy),
          ),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('靜止時：一行高、送出停用，而且畫面上沒有任何 helper text', (tester) async {
    await pump(tester, onSend: (t, f) async => true);

    expect(sendEnabled(tester), isFalse);
    // 空欄位不必被告知自己是空的。
    expect(find.text(R.current.forumSubjectRequired), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('欄位與送出鈕照設計稿：高 48 的填色欄、44 見方的送出鈕，欄位填的是頁面色', (tester) async {
    await pump(tester, onSend: (t, f) async => true);

    // 高度來自主題的 InputDecorationTheme（heightField），不是自己畫的盒子。
    final field = tester.getSize(find.byType(TextField));
    expect(field.height, TatTokens.heightField);

    final decoration =
        tester.widget<TextField>(find.byType(TextField)).decoration!;
    // 這條列是卡片色，欄位取相反的那一階：頁面色。
    final context = tester.element(find.byType(TextField));
    expect(decoration.fillColor, context.tokens.page);
    expect(decoration.border, isNull, reason: '形狀一律交給主題，不自己畫圓角盒子');

    // 停用態也是 44 見方，四態之間不會左右抖。
    expect(tester.getSize(sendButton()).width, TatTokens.heightButton);

    await tester.enterText(find.byType(TextField), '謝謝老師');
    await tester.pumpAndSettle();
    expect(tester.getSize(sendButton()).width, TatTokens.heightButton);
    expect(tester.getSize(sendButton()).height, TatTokens.heightButton);
  });

  testWidgets('只有空白不算內容；有字才給送', (tester) async {
    var calls = 0;
    await pump(tester, onSend: (t, f) async {
      calls++;
      return true;
    });

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(sendEnabled(tester), isFalse);

    await tester.enterText(find.byType(TextField), '謝謝老師');
    await tester.pump();
    expect(sendEnabled(tester), isTrue);
    expect(calls, 0);
  });

  testWidgets('只有附件、沒有文字也送得出去——一張照片本身就是內容', (tester) async {
    final sentFiles = <List<File>>[];
    await pump(
      tester,
      onSend: (t, f) async {
        sentFiles.add(f);
        return true;
      },
      canAttach: true,
      maxAttachments: 2,
      maxBytes: 512000,
      picked: [pickable('a.pdf')],
    );

    await tapAndFlush(
        tester, iconButtonWithTooltip(R.current.forumAddAttachment),
        until: find.text('a.pdf'));

    expect(find.text('a.pdf'), findsOneWidget);
    expect(sendEnabled(tester), isTrue);

    await tester.tap(sendButton());
    await tester.pumpAndSettle();

    expect(sentFiles.single.map((f) => f.path.split('/').last), ['a.pdf']);
  });

  testWidgets('連點兩下送出只會送出一次——這一支沒有冪等鍵', (tester) async {
    var calls = 0;
    await pump(tester, onSend: (t, f) async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return true;
    });

    await tester.enterText(find.byType(TextField), '謝謝老師');
    await tester.pump();
    await tester.tap(sendButton());
    await tester.pump();

    // 送出中：鈕變轉圈，沒有第二顆可以按的送出。
    expect(sendButton(), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(calls, 1);
  });

  testWidgets('送出成功：清空文字與附件，並回報草稿沒了', (tester) async {
    final drafts = <bool>[];
    await pump(
      tester,
      onSend: (t, f) async => true,
      canAttach: true,
      maxAttachments: 2,
      maxBytes: 512000,
      picked: [pickable('a.pdf')],
      drafts: drafts,
    );

    await tester.enterText(find.byType(TextField), '謝謝老師');
    await tester.pump();
    await tapAndFlush(
        tester, iconButtonWithTooltip(R.current.forumAddAttachment),
        until: find.text('a.pdf'));
    await tester.tap(sendButton());
    await tester.pumpAndSettle();

    expect(find.text('謝謝老師'), findsNothing);
    expect(find.text('a.pdf'), findsNothing);
    expect(drafts.last, isFalse);
  });

  testWidgets('送出失敗：留在原地，文字與附件都還在', (tester) async {
    await pump(
      tester,
      onSend: (t, f) async => false,
      canAttach: true,
      maxAttachments: 2,
      maxBytes: 512000,
      picked: [pickable('a.pdf')],
    );

    await tester.enterText(find.byType(TextField), '謝謝老師');
    await tester.pump();
    await tapAndFlush(
        tester, iconButtonWithTooltip(R.current.forumAddAttachment),
        until: find.text('a.pdf'));
    await tester.tap(sendButton());
    await tester.pumpAndSettle();

    expect(find.text('謝謝老師'), findsOneWidget);
    expect(find.text('a.pdf'), findsOneWidget);
    // 再送一次要送得出去：失敗不可以把列鎖死。
    expect(sendEnabled(tester), isTrue);
  });

  testWidgets('轉螢幕之後打的字還在（草稿活在 State 裡）', (tester) async {
    await pump(tester, onSend: (t, f) async => true);

    await tester.enterText(find.byType(TextField), '轉個螢幕試試');
    await tester.pump();

    tester.view.physicalSize = const Size(1600, 800);
    await tester.pumpAndSettle();

    expect(find.text('轉個螢幕試試'), findsOneWidget);
  });

  testWidgets('打字與清空都會回報草稿狀態，頁面才擋得住返回鍵', (tester) async {
    final drafts = <bool>[];
    await pump(tester, onSend: (t, f) async => true, drafts: drafts);

    await tester.enterText(find.byType(TextField), '還沒送出的字');
    await tester.pump();
    expect(drafts.last, isTrue);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(drafts.last, isFalse);
  });

  testWidgets('送出的整段都回報忙碌，頁面才擋得住「飛在路上的回覆」', (tester) async {
    final busies = <bool>[];
    final gate = Completer<bool>();
    await pump(tester, onSend: (t, f) => gate.future, busies: busies);

    await tester.enterText(find.byType(TextField), '謝謝老師');
    await tester.pump();
    await tester.tap(sendButton());
    await tester.pump();

    expect(busies.first, isTrue);

    gate.complete(true);
    await tester.pumpAndSettle();

    expect(busies.last, isFalse);
  });

  group('回覆目標', () {
    testWidgets('沒有指定目標時目標列照畫，說的是「回覆主題」——兩種狀態不可以長得一樣', (tester) async {
      await pump(tester, onSend: (t, f) async => true, topicLabel: '期中考公告');

      expect(find.text(sprintf(R.current.forumReplyingToTopic, ['期中考公告'])),
          findsOneWidget);
      // 已經在回第一篇了就沒有東西可以取消。
      expect(iconButtonWithTooltip(R.current.forumCancelReplyTarget),
          findsNothing);
    });

    testWidgets('瞄準某一篇時目標列出現，按 x 退回第一篇', (tester) async {
      var backToRoot = 0;
      await pump(
        tester,
        onSend: (t, f) async => true,
        targetLabel: '王老師',
        onAimAtRoot: () => backToRoot++,
      );

      expect(find.text(sprintf(R.current.forumReplyingTo, ['王老師'])),
          findsOneWidget);

      await tester.tap(iconButtonWithTooltip(R.current.forumCancelReplyTarget));
      await tester.pumpAndSettle();

      expect(backToRoot, 1);
    });
  });

  group('附件', () {
    testWidgets('canAttach 為 false 時紙夾整顆不畫，也不解釋', (tester) async {
      await pump(tester, onSend: (t, f) async => true);

      expect(iconButtonWithTooltip(R.current.forumAddAttachment), findsNothing);
      expect(find.text(R.current.forumAttachmentDisabled), findsNothing);
    });

    testWidgets('附件列印出 n/上限——紙夾變灰的那一刻至少說得出上限是多少', (tester) async {
      await pump(
        tester,
        onSend: (t, f) async => true,
        canAttach: true,
        maxAttachments: 2,
        maxBytes: 512000,
        picked: [pickable('a.pdf')],
      );

      await tapAndFlush(
          tester, iconButtonWithTooltip(R.current.forumAddAttachment),
          until: find.text('a.pdf'));

      expect(find.text('1/2'), findsOneWidget);
    });

    testWidgets('達到上限之後紙夾停用', (tester) async {
      await pump(
        tester,
        onSend: (t, f) async => true,
        canAttach: true,
        maxAttachments: 1,
        maxBytes: 512000,
        picked: [pickable('a.pdf')],
      );

      await tapAndFlush(
          tester, iconButtonWithTooltip(R.current.forumAddAttachment),
          until: find.text('a.pdf'));

      expect(
          tester
              .widget<IconButton>(
                  iconButtonWithTooltip(R.current.forumAddAttachment))
              .onPressed,
          isNull);
    });

    testWidgets('超過單檔上限：吐訊息，那個檔案不會被加進來', (tester) async {
      await pump(
        tester,
        onSend: (t, f) async => true,
        canAttach: true,
        maxAttachments: 2,
        maxBytes: 4,
        picked: [pickable('big.pdf', bytes: 64)],
      );

      await tapAndFlush(
          tester, iconButtonWithTooltip(R.current.forumAddAttachment),
          until: find.text('a.pdf'));

      expect(ui.toasts.single, contains('big.pdf'));
      expect(find.text('big.pdf'), findsNothing);
    });

    testWidgets('重名擋在本地：upload.php 會回 filenameexist', (tester) async {
      await pump(
        tester,
        onSend: (t, f) async => true,
        canAttach: true,
        maxAttachments: 3,
        maxBytes: 512000,
        picked: [pickable('a.pdf')],
      );

      await tapAndFlush(
          tester, iconButtonWithTooltip(R.current.forumAddAttachment),
          until: find.text('a.pdf'));
      await tapAndFlush(
          tester, iconButtonWithTooltip(R.current.forumAddAttachment),
          until: find.text('a.pdf'));

      expect(ui.toasts, contains(R.current.forumAttachmentDuplicateName));
      expect(find.text('a.pdf'), findsOneWidget);
    });

    testWidgets('挑好的附件可以移除', (tester) async {
      await pump(
        tester,
        onSend: (t, f) async => true,
        canAttach: true,
        maxAttachments: 2,
        maxBytes: 512000,
        picked: [pickable('a.pdf')],
      );

      await tapAndFlush(
          tester, iconButtonWithTooltip(R.current.forumAddAttachment),
          until: find.text('a.pdf'));
      await tester.tap(iconButtonWithTooltip(R.current.forumRemoveAttachment));
      await tester.pumpAndSettle();

      expect(find.text('a.pdf'), findsNothing);
      expect(sendEnabled(tester), isFalse);
    });

    testWidgets('使用者取消挑檔不是失敗，不吐任何訊息', (tester) async {
      await pump(
        tester,
        onSend: (t, f) async => true,
        canAttach: true,
        maxAttachments: 2,
        maxBytes: 512000,
      );

      await tapAndFlush(
          tester, iconButtonWithTooltip(R.current.forumAddAttachment),
          until: find.text('a.pdf'));

      expect(ui.toasts, isEmpty);
    });
  });

  group('上傳與送出的兩段', () {
    testWidgets('上傳中可以取消（伺服器上什麼都還沒動），送出中不行', (tester) async {
      var cancels = 0;
      final gate = Completer<bool>();
      late void Function(ForumTransferProgress) report;

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: const SizedBox.shrink(),
          bottomNavigationBar: ForumComposerBar(
            hintText: R.current.forumReplyHint,
            targetLabel: null,
            topicLabel: '期中考公告',
            canAttach: false,
            maxAttachments: 0,
            maxBytes: 0,
            onPickFiles: (remaining) async => const [],
            onSend: (text, files, {required onProgress}) {
              report = onProgress;
              return gate.future;
            },
            onCancelUpload: () => cancels++,
            onAimAtRoot: () {},
            onScrollToTarget: () {},
            onDraftChanged: (_) {},
            onBusyChanged: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '謝謝老師');
      await tester.pump();
      await tester.tap(sendButton());
      await tester.pump();

      report(const ForumTransferProgress(
          done: 0, total: 1, ratio: 0.5, phase: ForumTransferPhase.upload));
      await tester.pump();

      final cancelButton = iconButtonWithTooltip(R.current.cancel);
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pump();
      expect(cancels, 1);

      report(const ForumTransferProgress(
          done: 1, total: 1, ratio: 0, phase: ForumTransferPhase.posting));
      await tester.pump();

      // 送出階段沒有取消：請求出去就收不回來。
      expect(iconButtonWithTooltip(R.current.cancel), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete(true);
      await tester.pumpAndSettle();
    });

    testWidgets('靜止時那條 2px 的槽畫的是分隔線，不是進度條——列不會忽然跳高', (tester) async {
      await pump(tester, onSend: (t, f) async => true);

      expect(find.byIcon(LucideIcons.send), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });
}
