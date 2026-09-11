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
  });

  setUp(() {
    resetAppStatics();
    ConnectivityProbe.instance = FakeConnectivityProbe(online: false);
  });

  tearDown(() {
    AuthSession.instance = const UninstalledAuthSession();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
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
