import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_discussion_posts.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/util/moodle_forum_edit_utils.dart';
import 'package:flutter_app/src/util/moodle_forum_utils.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_forum_compose_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sprintf/sprintf.dart';

import '../helpers/finders.dart';
import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 撰寫頁的規格：編輯自己的貼文（回覆在討論串頁底部的 `ForumComposerBar`，
/// 開新主題已經整個移除）。這一頁不碰 repository：送出與挑檔都由呼叫端注入，
/// 所以整組測試都不需要網路、快取或登入。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordingUi ui;
  late Directory temp;

  setUpAll(() async {
    await loadTestL10n();
    await initializeDateFormatting();
  });

  setUp(() {
    resetAppStatics();
    ui = RecordingUi();
    TaskUiDelegate.instance = ui;
    temp = Directory.systemTemp.createTempSync('tat_forum_compose');
  });

  tearDown(() {
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// 一律用同步 I/O：widget 測試跑在假時鐘裡，測試主體上的 `await` 真 I/O
  /// 永遠不會完成（同 course_assign_submit_page_test 的 makeFile）。
  File pickable(String name, {int bytes = 8}) {
    final f = File('${temp.path}/$name');
    f.writeAsBytesSync(List<int>.filled(bytes, 65));
    return f;
  }

  Finder sendButton() => buttonWithText(R.current.forumSend);
  Finder saveButton() => buttonWithText(R.current.forumSaveEdit);

  /// 送出中那顆鈕的字會換成「送出中…」，所以判斷停不停用要找型別而不是字；
  /// `FilledButton.icon` 回的是私有子類別，`byType` 抓不到（同 finders.dart）。
  Finder submitButton() => find.byWidgetPredicate((w) => w is FilledButton);

  /// 挑完檔案要 `File.length()`，那是真的 I/O：假時鐘不會讓它完成，
  /// 得先把真的事件迴圈讓出去再 pump（同 course_assign_submit_page_test）。
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

  const offPolicy = ForumAttachPolicy.off();
  const onPolicy =
      ForumAttachPolicy(enabled: true, maxFiles: 2, maxBytes: 512000);

  void sizeUp(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpEdit(
    WidgetTester tester, {
    required Future<Result<ForumEditOutcome>> Function(
      String subject,
      String text,
      List<MoodleForumFile> keep,
      List<File> added,
    ) onSend,
    bool isTopicPost = true,
    String initialSubject = '期中考公告',
    String initialText = '期中考於下週三舉行',
    List<MoodleForumFile> existing = const [],
    ForumAttachPolicy policy = offPolicy,
    List<File> picked = const [],
    List<ForumEditOutcome?>? popped,
    String? formattingNote,
  }) async {
    sizeUp(tester);
    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await Get.to<ForumEditOutcome>(
                () => CourseForumComposePage.edit(
                  postId: 950,
                  isTopicPost: isTopicPost,
                  initialSubject: initialSubject,
                  initialText: initialText,
                  existingAttachments: existing,
                  onSendEdit: (s, t, k, a, {required onProgress}) =>
                      onSend(s, t, k, a),
                  attachPolicy: policy,
                  onPickFiles: (remaining) async => picked,
                  onCancelUpload: () {},
                  onOpenAttachment: (f) async {},
                  openWebView: (title, url) async {},
                  webUrl:
                      'https://moodle2.ntust.edu.tw/mod/forum/discuss.php?d=7701',
                  webTitle: '期中考公告',
                  formattingNote: formattingNote,
                ),
              );
              popped?.add(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// 初值全空的編輯器：所有「還沒填完」的規則都靠它測。
  Future<void> pumpBlank(
    WidgetTester tester, {
    required Future<Result<ForumEditOutcome>> Function(
      String subject,
      String text,
      List<MoodleForumFile> keep,
      List<File> added,
    ) onSend,
    ForumAttachPolicy policy = offPolicy,
    List<File> picked = const [],
  }) =>
      pumpEdit(
        tester,
        onSend: onSend,
        initialSubject: '',
        initialText: '',
        policy: policy,
        picked: picked,
      );

  group('還沒填完', () {
    testWidgets('兩個欄位都空著時：送出停用，而且畫面上一句多餘的說明都沒有', (tester) async {
      await pumpBlank(tester, onSend: (s, t, k, a) async => const Ok(_edited));

      expect(
          tester.widget<ButtonStyleButton>(submitButton()).onPressed, isNull);
      // 空欄位不必被告知自己是空的。
      expect(find.text(R.current.forumSubjectRequired), findsNothing);
    });

    testWidgets('內文有字、標題還空著 → 底列出現唯一那句阻塞原因', (tester) async {
      await pumpBlank(tester, onSend: (s, t, k, a) async => const Ok(_edited));

      await tester.enterText(find.byType(TextField).last, '請問這題怎麼算');
      await tester.pump();

      expect(find.text(R.current.forumSubjectRequired), findsOneWidget);
      expect(
          tester.widget<ButtonStyleButton>(submitButton()).onPressed, isNull);

      await tester.enterText(find.byType(TextField).first, '作業問題');
      await tester.pump();

      expect(find.text(R.current.forumSubjectRequired), findsNothing);
      expect(tester.widget<ButtonStyleButton>(submitButton()).onPressed,
          isNotNull);
    });

    testWidgets('標題填了、內文還空著 → 底列說「請先寫點內容」，不是只把鈕變灰', (tester) async {
      await pumpBlank(tester, onSend: (s, t, k, a) async => const Ok(_edited));

      await tester.enterText(find.byType(TextField).first, '作業問題');
      await tester.pump();

      expect(find.text(R.current.forumMessageRequired), findsOneWidget);
      expect(
          tester.widget<ButtonStyleButton>(submitButton()).onPressed, isNull);
    });

    testWidgets('送出中不給「在網頁開啟」——那一趟會把已經送出去的那則留在螢幕上當草稿', (tester) async {
      final gate = Completer<Result<ForumEditOutcome>>();
      await pumpBlank(tester, onSend: (s, t, k, a) => gate.future);

      await tester.enterText(find.byType(TextField).first, '作業問題');
      await tester.enterText(find.byType(TextField).last, '請問這題怎麼算');
      await tester.pump();
      await tester.tap(submitButton());
      await tester.pump();

      // 這一頁只在自己還在最上面時 pop，而這一支寫入沒有冪等鍵。
      expect(
        tester
            .widget<IconButton>(find.ancestor(
                of: find.byTooltip(R.current.forumOpenInWeb),
                matching: find.byType(IconButton)))
            .onPressed,
        isNull,
      );

      gate.complete(const Ok(_edited));
      await tester.pumpAndSettle();
    });

    testWidgets('連點兩下送出只會送出一次——這一支沒有冪等鍵', (tester) async {
      var calls = 0;
      await pumpBlank(tester, onSend: (s, t, k, a) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return const Ok(_edited);
      });

      await tester.enterText(find.byType(TextField).first, '作業問題');
      await tester.enterText(find.byType(TextField).last, '內容');
      await tester.pump();
      await tester.tap(submitButton());
      await tester.pump();

      expect(
          tester.widget<ButtonStyleButton>(submitButton()).onPressed, isNull);
      await tester.tap(submitButton(), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(calls, 1);
    });

    testWidgets('送出失敗：留在原地、打的字還在，吐對應好的訊息', (tester) async {
      await pumpBlank(tester,
          onSend: (s, t, k, a) async => Failed<ForumEditOutcome>(
              FetchFailed(R.current.forumErrorTooManyPosts)));

      await tester.enterText(find.byType(TextField).first, '作業問題');
      await tester.enterText(find.byType(TextField).last, '請問這題怎麼算');
      await tester.pump();
      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(find.byType(CourseForumComposePage), findsOneWidget);
      expect(find.text('請問這題怎麼算'), findsOneWidget);
      expect(ui.toasts, [R.current.forumErrorTooManyPosts]);
      // 再送一次要送得出去：失敗不可以把頁面鎖死。
      expect(tester.widget<ButtonStyleButton>(submitButton()).onPressed,
          isNotNull);
    });

    testWidgets('標題撞到 255 就停住：超過會是伺服器的 dmlwriteexception', (tester) async {
      await pumpBlank(tester, onSend: (s, t, k, a) async => const Ok(_edited));

      final subject = find.byType(TextField).first;
      await tester.enterText(subject, '題' * 300);
      await tester.pump();

      expect(tester.widget<TextField>(subject).controller?.text.length,
          MoodleForumUtils.subjectMaxLength);
      expect(find.text('255/255'), findsOneWidget, reason: '快撞到上限才出現計數器');
    });

    testWidgets('有草稿時返回會先問；按取消留在原地、文字還在', (tester) async {
      await pumpBlank(tester, onSend: (s, t, k, a) async => const Ok(_edited));

      await tester.enterText(find.byType(TextField).last, '還沒送出的字');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text(R.current.forumDiscardDraft), findsOneWidget);
      await tester.tap(buttonWithText(R.current.cancel));
      await tester.pumpAndSettle();

      expect(find.byType(CourseForumComposePage), findsOneWidget);
      expect(find.text('還沒送出的字'), findsOneWidget);
    });

    testWidgets('轉螢幕之後打的字還在（草稿活在 State 裡）', (tester) async {
      await pumpBlank(tester, onSend: (s, t, k, a) async => const Ok(_edited));

      await tester.enterText(find.byType(TextField).last, '轉個螢幕試試');
      await tester.pump();

      tester.view.physicalSize = const Size(2000, 800);
      await tester.pumpAndSettle();

      expect(find.text('轉個螢幕試試'), findsOneWidget);
    });

    testWidgets('頁尾只剩一句排版說明——沒有鈕，也不再說「附件與編輯請到網頁」', (tester) async {
      await pumpBlank(tester, onSend: (s, t, k, a) async => const Ok(_edited));

      expect(find.text(R.current.forumFormattingInWeb), findsOneWidget);
      // 網頁入口只留 AppBar 右上那一顆 icon，不再有一段道歉文字加一顆鈕。
      expect(buttonWithText(R.current.forumOpenInWeb), findsNothing);
    });
  });

  group('附件', () {
    testWidgets('政策說不給時紙夾整顆不畫，也不解釋', (tester) async {
      await pumpBlank(tester, onSend: (s, t, k, a) async => const Ok(_edited));

      expect(find.byTooltip(R.current.forumAddAttachment), findsNothing);
      expect(find.text(R.current.forumAttachmentDisabled), findsNothing);
    });

    testWidgets('挑了檔案就列出來，並顯示數量與上限', (tester) async {
      await pumpBlank(
        tester,
        onSend: (s, t, k, a) async => const Ok(_edited),
        policy: onPolicy,
        picked: [pickable('a.pdf')],
      );

      await tapAndFlush(tester, find.byTooltip(R.current.forumAddAttachment),
          until: find.text('a.pdf'));

      expect(find.text('a.pdf'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
      expect(find.text(sprintf(R.current.forumAttachmentLimit, ['2'])),
          findsOneWidget);
    });

    testWidgets('超過單檔上限：吐訊息，那個檔案不會被加進來', (tester) async {
      await pumpBlank(
        tester,
        onSend: (s, t, k, a) async => const Ok(_edited),
        policy:
            const ForumAttachPolicy(enabled: true, maxFiles: 2, maxBytes: 4),
        picked: [pickable('big.pdf', bytes: 64)],
      );

      await tapAndFlush(tester, find.byTooltip(R.current.forumAddAttachment));

      expect(ui.toasts.single, contains('big.pdf'));
      expect(find.text('big.pdf'), findsNothing);
    });

    testWidgets('重名擋在本地：Moodle 只會收下第一個', (tester) async {
      await pumpBlank(
        tester,
        onSend: (s, t, k, a) async => const Ok(_edited),
        policy: onPolicy,
        picked: [pickable('a.pdf')],
      );

      await tapAndFlush(tester, find.byTooltip(R.current.forumAddAttachment),
          until: find.text('a.pdf'));
      await tapAndFlush(tester, find.byTooltip(R.current.forumAddAttachment),
          until: find.text('a.pdf'));

      expect(ui.toasts, contains(R.current.forumAttachmentDuplicateName));
      expect(find.text('a.pdf'), findsOneWidget);
    });

    testWidgets('只挑了附件、標題還空著 → 底列照樣說得出為什麼送不出去', (tester) async {
      await pumpBlank(
        tester,
        onSend: (s, t, k, a) async => const Ok(_edited),
        policy: onPolicy,
        picked: [pickable('a.pdf')],
      );

      await tapAndFlush(tester, find.byTooltip(R.current.forumAddAttachment),
          until: find.text('a.pdf'));

      // 已經有內容在畫面上了，這時沉默等於讓人卡在一顆灰掉的鈕前面。
      expect(find.text(R.current.forumSubjectRequired), findsOneWidget);
    });

    testWidgets('只有附件、沒有內文時仍然送得出去（標題有填）', (tester) async {
      await pumpBlank(
        tester,
        onSend: (s, t, k, a) async => const Ok(_edited),
        policy: onPolicy,
        picked: [pickable('a.pdf')],
      );

      await tester.enterText(find.byType(TextField).first, '看這個');
      await tapAndFlush(tester, find.byTooltip(R.current.forumAddAttachment),
          until: find.text('a.pdf'));

      expect(tester.widget<ButtonStyleButton>(submitButton()).onPressed,
          isNotNull);
    });
  });

  group('編輯模式', () {
    testWidgets('原始碼那條路換掉那句話——框裡打得出粗體，不可以叫人去網頁版', (tester) async {
      await pumpEdit(
        tester,
        onSend: (s, t, k, a) async => const Ok(ForumEditOutcome()),
        initialText: '**重點**\n- 一',
        formattingNote: R.current.forumMarkdownSource,
      );

      expect(find.text(R.current.forumMarkdownSource), findsOneWidget);
      expect(find.text(R.current.forumFormattingInWeb), findsNothing);
    });
    testWidgets('帶入標題與內文的初值，送出鈕是「儲存」', (tester) async {
      await pumpEdit(tester, onSend: (s, t, k, a) async => const Ok(_edited));

      expect(find.text('期中考公告'), findsOneWidget);
      expect(find.text('期中考於下週三舉行'), findsOneWidget);
      expect(saveButton(), findsOneWidget);
      expect(sendButton(), findsNothing);
    });

    testWidgets('把內文清空 → 送出停用（伺服器會靜靜不改然後回 status: true）', (tester) async {
      await pumpEdit(tester, onSend: (s, t, k, a) async => const Ok(_edited));

      await tester.enterText(find.byType(TextField).last, '   ');
      await tester.pump();

      expect(
          tester.widget<ButtonStyleButton>(submitButton()).onPressed, isNull);
    });

    testWidgets('不是第一篇時不給改標題——只有第一篇會連帶改討論串標題', (tester) async {
      await pumpEdit(tester,
          onSend: (s, t, k, a) async => const Ok(_edited), isTopicPost: false);

      expect(find.text(R.current.forumSubject), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('既有附件列得出來，移除之後不再送回去', (tester) async {
      final keeps = <List<MoodleForumFile>>[];
      await pumpEdit(
        tester,
        onSend: (s, t, k, a) async {
          keeps.add(k);
          return const Ok(_edited);
        },
        existing: [MoodleForumFile(filename: 'slides.pdf')],
        policy: onPolicy,
      );

      expect(find.text('slides.pdf'), findsOneWidget);
      await tester.tap(find.byTooltip(R.current.forumRemoveAttachment));
      await tester.pumpAndSettle();
      expect(find.text('slides.pdf'), findsNothing);

      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(keeps.single, isEmpty);
    });

    testWidgets('新挑的檔案與既有的同名時擋在本地（draft 區會回 filenameexist）', (tester) async {
      await pumpEdit(
        tester,
        onSend: (s, t, k, a) async => const Ok(_edited),
        existing: [MoodleForumFile(filename: 'a.pdf')],
        policy: onPolicy,
        picked: [pickable('a.pdf')],
      );

      await tapAndFlush(tester, find.byTooltip(R.current.forumAddAttachment),
          until: find.text('a.pdf'));

      expect(ui.toasts, contains(R.current.forumAttachmentDuplicateName));
      expect(find.text('a.pdf'), findsOneWidget, reason: '既有的那一個而已');
    });

    testWidgets('沒有改任何東西就返回：不多問一次', (tester) async {
      await pumpEdit(tester, onSend: (s, t, k, a) async => const Ok(_edited));

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text(R.current.forumDiscardDraft), findsNothing);
      expect(find.byType(CourseForumComposePage), findsNothing);
    });

    testWidgets('送出中按返回：不放棄草稿、不離開，完成之後 pop 掉的還是這一頁', (tester) async {
      final gate = Completer<Result<ForumEditOutcome>>();
      final popped = <ForumEditOutcome?>[];
      await pumpEdit(tester,
          onSend: (s, t, k, a) => gate.future, popped: popped);

      await tester.enterText(find.byType(TextField).last, '改一下');
      await tester.pump();
      await tester.tap(saveButton());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await tester.pageBack();
      await tester.pump();

      expect(find.text(R.current.forumDiscardDraft), findsNothing,
          reason: '飛在路上的更新不是可以放棄的草稿');
      expect(find.byType(CourseForumComposePage), findsOneWidget);
      expect(ui.toasts, [R.current.forumSending]);

      gate.complete(const Ok(_edited));
      await tester.pumpAndSettle();

      expect(find.byType(CourseForumComposePage), findsNothing);
      expect(find.text('open'), findsOneWidget);
      expect(popped.single, isNotNull);
    });
  });
}

const _edited = ForumEditOutcome();
