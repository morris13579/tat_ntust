import 'package:flutter/services.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/controller/main_page/main_controller.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 「首次登入時 Moodle 還沒登完就跳錯誤框」的迴歸測試。
///
/// 成因是 _checkMoodle 繞過 AuthSession 直接呼叫 connector，也就繞過了
/// inFlight，於是與課表頁的 preloadSemesterList 各開一個登入頁。
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestL10n();
    // `onInit` 把 `_loadMoodleProfile` 丟到背景，那條路會跑到 tearDown 之後
    // ——那時 probe 已經被換回 `PlatformConnectivityProbe`，於是它去打真的
    // connectivity_plus channel，在測試環境裡直接 MissingPluginException，
    // 而那是一個沒人接的 async error，會被算到這一條測試頭上。
    //
    // 之前這條測試在整套跑的時候會過，只是因為別的測試檔剛好先裝了 handler；
    // 換一批測試檔（順序變了）就紅。自己裝一個才不吃順序。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (call) async => 'wifi',
    );
  });

  setUp(() {
    resetAppStatics();
    ConnectivityProbe.instance = FakeConnectivityProbe(online: false);
  });

  tearDown(() {
    // **不要換回 UninstalledAuthSession 與 PlatformConnectivityProbe。**
    // `onInit` 把 `_loadMoodleProfile` 丟到背景，那條路（一路到
    // `NotificationBadgeController.refresh`）會跑到這一行之後才走到
    // `AuthSession.ensure`；撞上 Uninstalled 它就丟例外，而那時測試已經結束，
    // 沒有人接得住，framework 只會報「This test failed after it had already
    // completed」。留著無害的替身，讓那條路安靜地跑完。
    // 下一條測試的 setUp 有 resetAppStatics()，不會吃到這裡留下的東西。
    AuthSession.instance = FakeAuthSession();
    ConnectivityProbe.instance = FakeConnectivityProbe(online: false);
  });

  test('Moodle 登入要經過 AuthSession.ensure，不能繞過去', () async {
    final auth = FakeAuthSession();
    AuthSession.instance = auth;

    await MainController().onInit();
    // onInit 是 unawaited 的，讓背景那條路跑完。
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    // Set 的 == 是同一性比較，所以攤平來看。
    final ensured = auth.ensureCalls.expand((e) => e).toSet();
    expect(
      ensured,
      contains(SystemId.moodleWebApi),
      reason: '繞過 ensure 就繞過 inFlight，首次登入會同時開兩個 Moodle 登入頁',
    );
  });

  test('沒有憑證時完全不發起 Moodle 登入', () async {
    final auth = FakeAuthSession(isSignedIn: false);
    AuthSession.instance = auth;

    await MainController().onInit();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final ensured = auth.ensureCalls.expand((e) => e).toSet();
    expect(ensured, isNot(contains(SystemId.moodleWebApi)));
  });
}
