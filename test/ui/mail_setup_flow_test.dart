import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/mail_connector.dart';
import 'package:flutter_app/src/model/mail/mail_folder_json.dart';
import 'package:flutter_app/src/model/mail/mail_message_json.dart';
import 'package:flutter_app/src/controller/mail/mail_watch_controller.dart';
import 'package:flutter_app/src/repository/mail_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/store/credentials_store.dart';
import 'package:flutter_app/ui/pages/mail/mail_list_page.dart';
import 'package:flutter_app/ui/pages/mail/mail_page.dart';
import 'package:flutter_app/ui/pages/mail/mail_setup_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

class _FakeRepo extends MailRepository {
  MailAuthOutcome outcome = MailAuthOutcome.ok;
  List<MailMessageJson> inbox = const [];

  @override
  Future<MailAuthOutcome> verifyPassword(
          String account, String password) async =>
      outcome;

  @override
  Future<Result<List<MailMessageJson>>> getMessages(
          [String folderPath = MailRepository.inboxPath]) async =>
      Ok(inbox);

  @override
  Future<List<MailMessageJson>> cachedMessages(
          [String folderPath = MailRepository.inboxPath]) async =>
      const [];

  @override
  Future<List<MailFolderJson>> cachedFolders() async => const [];

  /// 頁面載完清單之後會順手抓資料夾清單與未讀數。這兩個不擋下來的話會真的
  /// 開 socket——widget 測試裡那會變成 fake_async 的 timer 例外。
  @override
  Future<Result<List<MailFolderJson>>> getFolders() async => const Ok([]);

  @override
  Future<int?> unreadCount(
          [String folderPath = MailRepository.inboxPath]) async =>
      0;

  /// 設定完成之後 `MailPage` 會叫 `MailWatchController.start()`，那條路第一件
  /// 事就是問最新的 UID。不擋下來的話 widget 測試會真的開 socket。
  @override
  Future<int?> latestUid(
          {String folderPath = MailRepository.inboxPath}) async =>
      1;

  @override
  Future<List<MailMessageJson>?> fetchNewerThan(int afterUid,
          {String folderPath = MailRepository.inboxPath}) async =>
      const [];
}

/// 第一次使用信箱：從說明頁輸入密碼到換成清單的整條路徑。
///
/// 這一組原本守的是一個真的踩到的 bug：`_start()` 在 `initState` 裡**同步**
/// 呼叫 `showTatDialog`（一次 `Navigator.push`），而那時頁面自己還在被 push、
/// navigator 處於 `_debugLocked`，對話框開得出來但 pop 時會炸在
/// `'!_debugLocked': is not true`，症狀是轉圈轉到天荒地老。
///
/// 現在密碼頁**是分頁的第一層內容**，不是被 push 上來的一條 route，那個 bug
/// 已經不可能發生。所以第一條測試改成守住那個結構本身：畫面上不該有第二條
/// route。剩下的幾條守的是驗證分支——那些和當初一樣重要。
void main() {
  late _FakeRepo repo;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestL10n();
  });

  setUp(() {
    resetAppStatics();
    repo = _FakeRepo();
    MailRepository.instance = repo;
    CredentialsStore.instance.setAccount('B11000000');
    CredentialsStore.instance.setMailPassword('');
  });

  tearDown(() {
    // 設定成功那幾條會把盯信打開，留著計時器會漏到下一條測試。
    MailWatchController.instance.reset();
    MailRepository.instance = MailRepository();
    Get.reset();
  });

  /// **不能用 `pumpAndSettle`**：清單載入時 `ResultView` 畫的是 `LoadingPage`
  /// 的無限轉圈，永遠不會停下來，settle 只會逾時。
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: MailPage()));
    await settle(tester);
  }

  Future<void> submit(WidgetTester tester, String password) async {
    await tester.enterText(find.byType(TextField), password);
    // 主鈕在密碼是空的時候停用，所以要先讓那一次 setState 畫完才點得到。
    await tester.pump();
    // 這一頁比 800x600 的測試視窗高，主鈕落在 ListView 的可視範圍外——沒有
    // 建出來的 widget 是點不到的。先捲到它。
    await tester.ensureVisible(find.text(R.current.mailLogin));
    await tester.pump();
    await tester.tap(find.text(R.current.mailLogin));
    await settle(tester);
  }

  testWidgets('沒設定密碼時整格就是設定頁，不是彈上來的對話框', (tester) async {
    await pumpPage(tester);

    expect(find.byType(MailSetupPage), findsOneWidget);
    expect(find.byType(MailListPage), findsNothing);
    // 只有一條 route：設定頁是這一格的內容，不是疊在清單上的東西。回歸的
    // 話這裡會變成 2，而那正是 _debugLocked 那個 bug 的前提。
    expect(
      tester.widgetList(find.byType(Navigator)).length,
      1,
      reason: '設定頁不該是被 push 上來的',
    );
  });

  testWidgets('驗證成功後換成清單，密碼存得下去', (tester) async {
    await pumpPage(tester);

    await submit(tester, 'mail-pw');

    expect(tester.takeException(), isNull);
    expect(find.byType(MailSetupPage), findsNothing);
    expect(find.byType(MailListPage), findsOneWidget);
    expect(CredentialsStore.instance.mailPassword, 'mail-pw');
    // 設定成功會啟動盯信的計時器。它是 App 生命週期的東西，但 widget 測試在
    // 「測試主體結束」就會檢查有沒有還沒收掉的 Timer，而那個檢查早於 tearDown。
    MailWatchController.instance.stop();
  });

  testWidgets('密碼錯時留在設定頁，而且密碼不會被存下去', (tester) async {
    repo.outcome = MailAuthOutcome.rejected;
    await pumpPage(tester);

    await submit(tester, 'wrong');

    expect(find.byType(MailSetupPage), findsOneWidget);
    expect(CredentialsStore.instance.mailPassword, isEmpty,
        reason: '驗不過就不能寫進 Keychain');
  });

  testWidgets('連不上與密碼錯是兩句不同的話', (tester) async {
    repo.outcome = MailAuthOutcome.unreachable;
    await pumpPage(tester);

    await submit(tester, 'whatever');

    // 兩條路徑必須顯示不同的訊息：連不上時叫使用者重打密碼是白費力氣。
    expect(find.text(R.current.mailPasswordUnreachable), findsOneWidget);
    expect(find.text(R.current.mailPasswordRejected), findsNothing);
  });

  testWidgets('密碼是空的時候主鈕停用，不會白跑一次連線', (tester) async {
    // 停用而不是按下去才回一句錯——那句錯會和欄位的提示字一字不差。
    await pumpPage(tester);

    await tester.ensureVisible(find.byType(FilledButton));
    await tester.pump();
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'x');
    await settle(tester);

    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
  });

  testWidgets('帳號與密碼兩列一樣高', (tester) async {
    // 帳號那一列是一段文字、密碼那一列是輸入框加一顆眼睛，內容本來就不一樣
    // 高。高度沒有釘死的話兩列會差二十幾 px，同一張卡片裡看起來就是歪的。
    await pumpPage(tester);

    final rows = tester
        .widgetList<ConstrainedBox>(find.descendant(
          of: find.byType(MailSetupPage),
          matching: find.byType(ConstrainedBox),
        ))
        .where((b) => b.constraints.minHeight == 56)
        .toList();
    expect(rows.length, 2, reason: '兩列都要吃到同一個最小高度');

    final heights = <double>{
      for (final label in [R.current.account, R.current.password])
        tester
            .getSize(find
                .ancestor(
                  of: find.text(label),
                  matching: find.byType(ConstrainedBox),
                )
                .first)
            .height,
    };
    expect(heights.length, 1, reason: '兩列的實際高度要一致：$heights');
  });

  testWidgets('有主 logo，和登入頁同一顆', (tester) async {
    await pumpPage(tester);

    final image = tester.widget<Image>(find.descendant(
      of: find.byType(MailSetupPage),
      matching: find.byType(Image),
    ));
    expect(
        (image.image as AssetImage).assetName, 'assets/launcher/ios-icon.png');
  });

  testWidgets('已經設定過就直接進清單，不再問一次密碼', (tester) async {
    CredentialsStore.instance.setMailPassword('already-set');

    await pumpPage(tester);

    expect(find.byType(MailSetupPage), findsNothing);
    expect(find.byType(MailListPage), findsOneWidget);
    MailWatchController.instance.stop();
  });
}
