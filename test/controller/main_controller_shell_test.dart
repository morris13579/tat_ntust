import 'dart:async';

import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/controller/main_page/main_controller.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// [AuthSession.ensure] 永遠不完成，模擬「Moodle 那條路要花很久」。
class _HangingAuthSession extends FakeAuthSession {
  @override
  Future<AuthError?> ensure(Set<SystemId> requires,
          {bool interactive = true}) =>
      Completer<AuthError?>().future; // 永遠 pending
}

/// App 外殼不能被 Moodle 擋住：`onInit` 不得 await Moodle 登入。
/// 課表不需要 Moodle，等它等於讓使用者輸入完帳密後再盯著載入畫面空等一輪。
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestL10n();
  });

  setUp(() {
    resetAppStatics();
    ConnectivityProbe.instance = FakeConnectivityProbe(online: false);
  });

  tearDown(() {
    AuthSession.instance = const UninstalledAuthSession();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
  });

  test('Moodle 那條路卡住時，onInit 仍然要回來', () async {
    AuthSession.instance = _HangingAuthSession();
    final controller = MainController();

    // 沒有 unawaited 的話這裡會永遠等下去，測試逾時失敗。
    await controller.onInit().timeout(
          const Duration(seconds: 2),
          onTimeout: () => fail('onInit 在等 Moodle，外殼會被擋住'),
        );
  });
}
