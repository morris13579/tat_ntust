import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/repository/ntust_repository.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 背景預載不准把登入頁蓋在使用者正在看的畫面上。
///
/// `run()` 的 background 只套在它自己那一次 ensure 上，而 _fetchSemesterList
/// 裡面還有一次 Moodle 的 tryEnsure。
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestL10n();
  });

  late FakeAuthSession auth;

  setUp(() {
    resetAppStatics();
    auth = FakeAuthSession();
    AuthSession.instance = auth;
    ConnectivityProbe.instance = FakeConnectivityProbe(online: true);
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
  });

  tearDown(() {
    AuthSession.instance = const UninstalledAuthSession();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
  });

  test('background 的學期清單，內部的 Moodle tryEnsure 也是非互動的', () async {
    await NtustRepository.instance.getSemesterList(background: true);

    expect(auth.tryEnsureCalls, contains(SystemId.moodleWebApi),
        reason: '當前學期只有 Moodle 答得出來，這一步不該被拿掉');
    expect(auth.tryEnsureInteractive, everyElement(isFalse),
        reason: '背景預載彈出登入頁，正是這條測試要擋的事');
  });

  test('前景的學期清單維持互動——那是使用者自己按的', () async {
    await NtustRepository.instance.getSemesterList();

    expect(auth.tryEnsureInteractive, everyElement(isTrue));
  });
}
