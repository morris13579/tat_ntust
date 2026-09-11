import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/src/controller/setting/moodle_setting_controller.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_setting_entity.dart';
import 'package:flutter_app/ui/pages/other/page/setting/moodle_setting_page.dart';
import 'package:flutter_app/ui/components/tat_switch.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../helpers/test_l10n.dart';

// entity 的類別名稱長到會蓋掉測試本身的內容，這裡只在測試內取短名。
typedef _Component = MoodleSettingPreferencesComponents;
typedef _Notification = MoodleSettingPreferencesComponentsNotifications;
typedef _Processor = MoodleSettingPreferencesComponentsNotificationsProcessors;
typedef _LoggedIn
    = MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedin;
typedef _LoggedOff
    = MoodleSettingPreferencesComponentsNotificationsProcessorsLoggedoff;

/// 不打網路的 MoodleSettingController。
///
/// 只覆寫兩個會碰到 MoodleWebApiConnector 的方法，其餘（scrollControllerOf、
/// onClose、isToggling 在 UI 眼中的意義）都用真品。
class FakeMoodleSettingController extends MoodleSettingController {
  FakeMoodleSettingController(this.componentCount);

  final int componentCount;

  /// 測試用來把 toggleSetting 停在「寫入中」的閘門。
  Completer<void>? gate;
  int toggleCount = 0;

  @override
  Future<void> getSettingData() async {
    tab.value = [
      MoodleSettingPreferencesProcessors(displayname: 'Email', name: 'email'),
      MoodleSettingPreferencesProcessors(displayname: 'Popup', name: 'popup'),
    ];
    settingList.value = List.generate(
      componentCount,
      (i) => _Component(
        displayname: '元件 $i',
        notifications: [
          _Notification(
            displayname: '通知 $i',
            preferencekey: 'key$i',
            processors: [
              _Processor(
                name: 'email',
                enabled: false,
                loggedin: _LoggedIn(),
                loggedoff: _LoggedOff(),
              ),
            ],
          ),
        ],
      ),
    );
    tabController = TabController(length: tab.length, vsync: this);
  }

  /// 複製真品在 UI 眼中的狀態轉換：isToggling true → 等待 → false，
  /// 全程不碰 isLoading。真品那條路徑由
  /// test/controller/moodle_setting_controller_test.dart 把關。
  @override
  Future<void> toggleSetting(String key, String type, bool checked) async {
    toggleCount++;
    isToggling.value = true;
    if (gate != null) {
      await gate!.future;
    }
    isToggling.value = false;
  }
}

Future<FakeMoodleSettingController> _pumpPage(WidgetTester tester,
    {int componentCount = 20}) async {
  final controller = FakeMoodleSettingController(componentCount);
  Get.put<MoodleSettingController>(controller);
  await tester.pumpWidget(const GetMaterialApp(home: MoodleSettingPage()));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadTestL10n();
    // 開關的 onChanged 第一件事是 `await HapticFeedback.lightImpact()`。
    // 沒有假的 handler 的話這個回覆要走真的 event loop，fake async 的
    // pump() 不會推進它，後面的 toggleSetting 就永遠不會被呼叫。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            SystemChannels.platform, (call) async => null);
  });

  tearDown(Get.reset);

  testWidgets('寫入期間列表不會被 LoadingPage 換掉，捲動位置原地不動', (tester) async {
    final controller = await _pumpPage(tester);
    final scrollController = controller.scrollControllerOf('email');

    scrollController.jumpTo(300);
    await tester.pump();
    final positionBefore = scrollController.position;

    final gate = Completer<void>();
    controller.gate = gate;
    await tester.tap(find.byType(TatSwitch).hitTestable().first);
    await tester.pump();

    // 寫入進行中。這個瞬間不能把列表換成 LoadingPage：列表不在畫面上時
    // ScrollController 一個 position 都沒有，連 .offset 都會丟 StateError，
    // 而「延遲幾毫秒再 jumpTo(offset)」補救不了——Obx 要到下一個 frame 才重建，
    // jumpTo 當下多半還沒 attach，debug 丟 assert、release 什麼也沒做，
    // 結果就是彈回最上面。
    expect(controller.toggleCount, 1);
    expect(find.byType(ListView), findsWidgets);
    expect(scrollController.offset, 300);

    gate.complete();
    await tester.pumpAndSettle();

    // 同一個 ScrollPosition 物件：列表全程沒有被銷毀重建過。
    expect(identical(scrollController.position, positionBefore), isTrue);
    expect(scrollController.offset, 300);
  });

  testWidgets('寫入期間所有開關停用，寫完才恢復', (tester) async {
    final controller = await _pumpPage(tester);
    final gate = Completer<void>();
    controller.gate = gate;

    await tester.tap(find.byType(TatSwitch).hitTestable().first);
    await tester.pump();

    // 停用不只是忙碌提示：toggleSetting 是「讀目前 enabled 清單 → 送整份
    // 清單 → 重抓」，兩個請求交錯的話後送的那份會蓋掉前一個的結果。
    expect(
      tester
          .widget<TatSwitch>(find.byType(TatSwitch).hitTestable().first)
          .onChanged,
      isNull,
    );

    gate.complete();
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TatSwitch>(find.byType(TatSwitch).hitTestable().first)
          .onChanged,
      isNotNull,
    );
  });

  testWidgets('切頁動畫期間兩個分頁的 ScrollController 各自只掛一個 position', (tester) async {
    final controller = await _pumpPage(tester);

    controller.tabController!.animateTo(1);
    // 只推進一半，讓前後兩個分頁的 ListView 同時存在。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final email = controller.scrollControllerOf('email');
    final popup = controller.scrollControllerOf('popup');
    // 兩個分頁共用一顆 ScrollController 的話，這個瞬間會有兩個 position
    // 掛在同一顆上，`.offset`（_positions.single）就會丟 StateError。
    expect(email.positions.length, 1);
    expect(popup.positions.length, 1);
    expect(() => email.offset, returnsNormally);

    await tester.pumpAndSettle();
  });
}
