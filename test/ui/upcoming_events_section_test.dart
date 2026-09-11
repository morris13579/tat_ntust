import 'package:flutter/material.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_calendar_action_events.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/ui/components/page/loading_page.dart';
import 'package:flutter_app/ui/components/page/notice_bar.dart';
import 'package:flutter_app/ui/pages/calendar/upcoming_events_section.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/recording_ui.dart';
import '../helpers/test_l10n.dart';
import '../helpers/finders.dart';

/// 行事曆頁「待辦」區塊的畫面規格。
///
/// 區塊放在外層 ListView 裡，高度沒有上限；這裡每個測試都照正式路徑把它放進
/// ListView，順便盯著 ResultView 的 shrinkWrap 分支不會 RenderFlex 溢位。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 2026-09-09 是星期三。
  final now = DateTime(2026, 9, 9, 10, 0);
  late RecordingUi ui;

  setUpAll(() async {
    await loadTestL10n();
    // 副標的日期走 zh_TW 的格式（9月8日 23:59），沒有這一行只會拿到英文。
    await initializeDateFormatting();
  });

  setUp(() {
    ui = RecordingUi();
    TaskUiDelegate.instance = ui;
    AuthSession.instance = FakeAuthSession(isSignedIn: true);
  });

  tearDown(() {
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
    AuthSession.instance = const UninstalledAuthSession();
  });

  int secondsOf(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

  MoodleActionEvent event({
    required int id,
    required String title,
    required DateTime due,
    bool withCourse = true,
    String modulename = 'assign',
    String actionName = '新增繳交',
    bool actionable = true,
  }) =>
      MoodleActionEvent(
        id: id,
        name: '$title 到期',
        activityname: title,
        modulename: modulename,
        timesort: secondsOf(due),
        url: 'https://moodle2.ntust.edu.tw/mod/$modulename/view.php?id=$id',
        course: withCourse
            ? MoodleActionEventCourse(
                fullname: '115.1【AT1001301】軟體工程',
                shortname: '115.1【AT1001301】軟體工程',
              )
            : null,
        action: MoodleActionEventAction(
          name: actionName,
          url: 'https://moodle2.ntust.edu.tw/mod/$modulename/view.php?id=$id'
              '&action=editsubmission',
          actionable: actionable,
        ),
      );

  /// 四筆：昨天 23:59、今天 23:59、星期日 23:59（站台事件）、下週一 09:00。
  List<MoodleActionEvent> fourEvents() => [
        event(id: 1, title: '作業一', due: DateTime(2026, 9, 8, 23, 59)),
        event(
          id: 2,
          title: '小考一',
          due: DateTime(2026, 9, 9, 23, 59),
          modulename: 'quiz',
          actionName: '嘗試測驗',
        ),
        event(
          id: 3,
          title: '期中教學意見調查',
          due: DateTime(2026, 9, 13, 23, 59),
          withCourse: false,
          modulename: 'feedback',
          actionName: '前往',
        ),
        event(
          id: 4,
          title: '期末報告',
          due: DateTime(2026, 9, 14, 9, 0),
          actionable: false,
        ),
      ];

  Future<void> pump(
    WidgetTester tester,
    Rx<Result<List<MoodleActionEvent>>?> state, {
    Future<void> Function()? onRetry,
    Future<void> Function(MoodleActionEvent)? onOpen,
    bool settle = true,
  }) async {
    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            UpcomingEventsSection(
              state: state,
              onRetry: onRetry ?? () async {},
              onOpen: onOpen ?? (_) async {},
              clock: () => now,
            ),
          ],
        ),
      ),
    ));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  ColorScheme schemeOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(UpcomingEventsSection))).colorScheme;

  Color? subtitleColor(WidgetTester tester, int id) =>
      tester.widget<Text>(find.byKey(ValueKey('due-$id'))).style?.color;

  testWidgets('Ok：每一組自己帶標題與件數，標題與副標都畫出來', (tester) async {
    await pump(tester, Rxn(Ok(fourEvents())));

    // 有資料時不再另外掛一個「待辦」大標，組標題自己就寫了「待辦 · ⋯」。
    expect(find.text('待辦'), findsNothing);
    // 「之後」那一組再按月份切開：9/14 落在本月剩下的那半個月。
    for (final label in ['待辦 · 逾期', '待辦 · 今天', '待辦 · 本週', '待辦 · 9月下半']) {
      expect(find.text(label), findsOneWidget, reason: '缺少「$label」這一組');
    }
    // 每一組右邊都有件數，這裡四組各一件。
    expect(find.text('1 項'), findsNWidgets(4));

    for (final title in ['作業一', '小考一', '期中教學意見調查', '期末報告']) {
      expect(find.text(title), findsOneWidget);
    }

    // 副標：課名去掉學期與課號前綴，接上截止時間；近的那幾組再補剩餘時間。
    expect(find.text('軟體工程 · 9月8日 23:59'), findsOneWidget);
    expect(find.text('軟體工程 · 9月9日 23:59 · 剩 13 小時'), findsOneWidget);
    // 站台事件沒有 course，只剩時間。
    expect(find.text('9月13日 23:59 · 剩 4 天'), findsOneWidget);
    // 遠一點的那組不寫剩餘時間，寫了也沒有幫助。
    expect(find.text('軟體工程 · 9月14日 09:00'), findsOneWidget);
    expect(find.textContaining('軟體工程'), findsNWidgets(3),
        reason: '站台事件不該掛任何課名');
  });

  testWidgets('跨年的截止時間帶年份，組標題也帶年份', (tester) async {
    await pump(
        tester,
        Rxn(Ok([
          event(id: 9, title: '下學期報告', due: DateTime(2027, 1, 15, 23, 59)),
        ])));

    expect(find.text('軟體工程 · 2027年1月15日 23:59'), findsOneWidget);
    expect(find.text('待辦 · 2027年1月'), findsOneWidget);
  });

  testWidgets('逾期那一筆的副標用 error 色，今天那一筆不用', (tester) async {
    await pump(tester, Rxn(Ok(fourEvents())));
    final scheme = schemeOf(tester);

    expect(subtitleColor(tester, 1), scheme.error);
    expect(subtitleColor(tester, 2), isNot(scheme.error));
    expect(subtitleColor(tester, 2), scheme.onSurfaceVariant);
  });

  testWidgets('Ok 但清單是空的 → 空狀態文字加「待辦」標題，沒有任何分組', (tester) async {
    await pump(tester, Rxn(const Ok(<MoodleActionEvent>[])));

    expect(find.text('待辦'), findsOneWidget);
    expect(find.text('目前沒有待辦事項'), findsOneWidget);
    for (final label in ['待辦 · 逾期', '待辦 · 今天', '待辦 · 本週', '待辦 · 之後']) {
      expect(find.text(label), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('點一筆 → onOpen 收到那一筆', (tester) async {
    final opened = <int>[];
    await pump(tester, Rxn(Ok(fourEvents())),
        onOpen: (e) async => opened.add(e.id));

    await tester.tap(find.text('小考一'));
    await tester.pump();

    expect(opened, [2]);
  });

  testWidgets('Failed(NotSignedIn) 且沒登入 → 「請登入」加「登入」鈕，按了開登入頁再重試',
      (tester) async {
    AuthSession.instance = FakeAuthSession(isSignedIn: false);
    var retried = 0;
    await pump(tester, Rxn(const Failed(NotSignedIn())),
        onRetry: () async => retried++);

    expect(find.text('請登入'), findsOneWidget);
    expect(find.text('登入'), findsOneWidget);
    expect(find.text('重新整理'), findsNothing);

    await tester.tap(find.text('登入'));
    await tester.pump();

    expect(ui.openLoginCalls, 1);
    expect(retried, 1, reason: '從登入設定回來要重抓一次');
  });

  testWidgets('Failed(FetchFailed) 且已登入 → 標題還在，訊息加「重新整理」', (tester) async {
    var retried = 0;
    await pump(tester, Rxn(const Failed(FetchFailed('boom'))),
        onRetry: () async => retried++);

    expect(find.text('待辦'), findsOneWidget, reason: '失敗時標題要留著說明這塊是什麼');
    expect(find.text('boom'), findsOneWidget);
    expect(find.text('登入'), findsNothing);
    final refresh = buttonWithText('重新整理');
    expect(refresh, findsOneWidget);

    await tester.tap(refresh);
    await tester.pump();

    expect(retried, 1);
  });

  testWidgets('Stale → 橫幅寫著原因，底下的清單照畫，放在 ListView 裡不會溢位', (tester) async {
    await pump(tester, Rxn(Stale(fourEvents(), const Offline())));

    expect(find.text('網路發生錯誤'), findsOneWidget);
    expect(find.text('作業一'), findsOneWidget);
    expect(find.text('期末報告'), findsOneWidget);
    expect(find.text('待辦 · 逾期'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Stale 的橫幅是共用的 NoticeBar，而不是各自畫一條', (tester) async {
    await pump(tester, Rxn(Stale(fourEvents(), const Offline())));

    final bar = tester.widget<NoticeBar>(find.byType(NoticeBar));
    // 「你看到的是舊資料」用中性的 info，圖示蓋成 history。
    expect(bar.kind, NoticeKind.info);
    expect(bar.icon, LucideIcons.history);
    expect(find.byIcon(LucideIcons.history), findsOneWidget);
  });

  testWidgets('Stale 的橫幅有重試入口，按了會重抓', (tester) async {
    var retried = 0;
    await pump(tester, Rxn(Stale(fourEvents(), const Offline())),
        onRetry: () async => retried++);

    final refresh = buttonWithText('重新整理');
    expect(refresh, findsOneWidget);

    await tester.tap(refresh);
    await tester.pump();

    expect(retried, 1);
  });

  testWidgets('還在載入（null）→ LoadingPage，放在 ListView 裡不會炸', (tester) async {
    // LoadingPage 的轉圈永遠不會停，不能 pumpAndSettle。
    await pump(tester, Rxn<Result<List<MoodleActionEvent>>>(), settle: false);

    expect(find.byType(LoadingPage), findsOneWidget);
    expect(find.text('待辦'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('狀態從載入中變成 Ok 時畫面跟著換', (tester) async {
    final state = Rxn<Result<List<MoodleActionEvent>>>();
    await pump(tester, state, settle: false);
    expect(find.byType(LoadingPage), findsOneWidget);

    state.value = Ok(fourEvents());
    await tester.pumpAndSettle();

    expect(find.byType(LoadingPage), findsNothing);
    expect(find.text('作業一'), findsOneWidget);
  });
}
