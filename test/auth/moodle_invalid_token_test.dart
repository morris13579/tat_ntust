import 'package:flutter_app/src/auth/app_auth_session.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_token_entity.dart';
import 'package:flutter_app/src/store/moodle_session_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/reset_statics.dart';

/// Moodle 回 invalidtoken 時要把 token 作廢，讓下一次 ensure 重登。
///
/// 前提是 `MoodleWebApiConnector.onApiError` 這個掛鉤在啟動時真的被指派：
/// 沒接上的話，token 過期的使用者只會看到通用的重試對話框，而重試會帶著
/// 同一顆死 token 再失敗一次。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppAuthSession auth;

  MoodleApiException invalidToken() => MoodleApiException(
        wsFunction: 'core_webservice_get_site_info',
        exception: 'moodle_exception',
        errorcode: 'invalidtoken',
        message: 'Invalid token - token not found',
      );

  MoodleApiException otherError() => MoodleApiException(
        wsFunction: 'core_enrol_get_users_courses',
        exception: 'moodle_exception',
        errorcode: 'nopermissions',
        message: 'no permission',
      );

  setUp(() {
    resetAppStatics();
    auth = AppAuthSession();
    MoodleWebApiConnector.wsToken = 'dead-token';
  });

  test('invalidtoken 會作廢記憶體裡的 token', () {
    auth.onMoodleApiError(invalidToken());

    expect(MoodleWebApiConnector.wsToken, isNull);
  });

  test('作廢 token 連帶清掉跟著它的身分與快取', () {
    // wsToken 的 setter 負責這件事——換 token 就等於換身分。這裡驗的是
    // 這條路真的有走到那個 setter，而不是直接改私有欄位。
    MoodleWebApiConnector.userId = '42';
    MoodleWebApiConnector.siteInfo = null;

    auth.onMoodleApiError(invalidToken());

    expect(MoodleWebApiConnector.userId, isNull);
  });

  test('清掉磁碟上那一顆，否則下次冷啟動會把同一顆死 token 撈回來', () async {
    await MoodleSessionStore.instance
        .save(MoodleTokenEntity('sig', 'dead-token', 'priv'));

    auth.onMoodleApiError(invalidToken());
    // clear() 是 unawaited 的，讓它跑完。
    await Future<void>.delayed(Duration.zero);

    expect(MoodleSessionStore.instance.token, isNull);
  });

  test('其他錯誤碼不動 token——只有 invalidtoken 代表憑證死了', () {
    auth.onMoodleApiError(otherError());

    expect(MoodleWebApiConnector.wsToken, 'dead-token');
  });

  test('已經清過就不再重複——九條讀取路徑可能同時失敗', () async {
    auth.onMoodleApiError(invalidToken());
    expect(MoodleWebApiConnector.wsToken, isNull);

    // 第二次應該安靜地什麼都不做，不是拋例外。
    expect(() => auth.onMoodleApiError(invalidToken()), returnsNormally);
  });
}
