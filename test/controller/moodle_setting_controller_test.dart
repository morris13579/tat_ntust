import 'package:flutter/foundation.dart';
import 'package:flutter_app/src/controller/setting/moodle_setting_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// MoodleSettingController 的生命週期與旗標測試。
///
/// 這裡刻意不經過 Get.put：onInit 會打網路，而下面驗的三件事（每個分頁一顆
/// ScrollController、onClose 有把它們釋放、toggleSetting 不再動 isLoading）
/// 都不需要資料。
void main() {
  test('scrollControllerOf 同一個分頁回同一顆、不同分頁回不同顆', () {
    final controller = MoodleSettingController();

    expect(
      identical(controller.scrollControllerOf('email'),
          controller.scrollControllerOf('email')),
      isTrue,
    );
    // 每個分頁各一顆：TabBarView 切頁動畫期間前後兩個分頁的 ListView 會同時
    // attach，共用一顆的話 .offset / .jumpTo 會踩 _positions.single 的
    // StateError（release 也照拋）。
    expect(
      identical(controller.scrollControllerOf('email'),
          controller.scrollControllerOf('popup')),
      isFalse,
    );

    controller.onClose();
  });

  test('onClose 會把建立過的 ScrollController 都 dispose 掉', () {
    final controller = MoodleSettingController();
    final email = controller.scrollControllerOf('email');
    final popup = controller.scrollControllerOf('popup');

    controller.onClose();

    // ChangeNotifier dispose 之後再 addListener 會丟 FlutterError（debug）。
    expect(() => email.addListener(() {}), throwsA(isA<FlutterError>()));
    expect(() => popup.addListener(() {}), throwsA(isA<FlutterError>()));
  });

  test('toggleSetting 全程不碰 isLoading，只動 isToggling', () async {
    final controller = MoodleSettingController();
    final loadingEvents = <bool>[];
    final togglingEvents = <bool>[];
    final loadingSub = controller.isLoading.listen(loadingEvents.add);
    final togglingSub = controller.isToggling.listen(togglingEvents.add);

    // settingList 是空的，firstWhere 會立刻丟 StateError 走進 catch，
    // 因此這個呼叫不會碰到 MoodleWebApiConnector，也就不需要網路。
    await controller.toggleSetting('not-exist', 'email', true);

    await loadingSub.cancel();
    await togglingSub.cancel();

    // 動到 isLoading 的話 BasePage 會把整個 ListView 換成 LoadingPage，
    // 捲動位置隨列表一起被銷毀（「切一個開關就彈回最上面」）。
    expect(loadingEvents, isEmpty);
    expect(togglingEvents, [true, false]);
    expect(controller.isError.value, isTrue);

    controller.onClose();
  });
}
