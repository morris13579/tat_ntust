import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/auth/app_auth_session.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/service/file_pick_service.dart';
import 'package:flutter_app/src/service/image_pick_service.dart';
import 'package:flutter_app/src/service/interactive_login_gateway.dart';
import 'package:flutter_app/src/store/cache_store.dart';
import 'package:flutter_app/src/store/course_table_store.dart';
import 'package:flutter_app/src/store/credentials_store.dart';
import 'package:flutter_app/src/store/key_value_store.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/store/moodle_session_store.dart';
import 'package:flutter_app/src/store/score_store.dart';
import 'package:flutter_app/src/store/secure_store.dart';
import 'package:flutter_app/src/store/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 每個測試共用的一組乾淨儲存層。
class TestStores {
  final KeyValueStore plain;
  final InMemorySecureStore secure;

  TestStores(this.plain, this.secure);
}

/// 這個 App 把登入狀態放在 process 級 static、把儲存放在 static 單例，
/// 測試之間會互相污染。每個 setUp 都要呼叫這個函式重設。
///
/// 登入狀態不在這裡重設：它住在 AuthSession 的實例裡，換一顆新實例就等於重設。
TestStores resetAppStatics() {
  MoodleWebApiConnector.wsToken = null;
  MoodleWebApiConnector.userId = null;
  MoodleWebApiConnector.siteInfo = null;
  MoodleWebApiConnector.clearCoursesCache();
  MoodleWebApiConnector.onApiError = null;
  // autologin 的節流旗標、假時鐘與 wsPost / uploadPost 注入點也都是 process 級的。
  MoodleWebApiConnector.resetAutologinState();
  // 挑圖服務同理：預設換成什麼都不做的實作，測試不會碰到平台通道。
  ImagePickService.instance = const NoopImagePickService();
  // 挑檔案服務同理：沒有這一行，某個測試裝的 fake 會漏到別的測試。
  FilePickService.instance = const NoopFilePickService();
  // 課號 → Moodle 內部 id 的併發去重表也是 process 級的，會跨測試外洩。
  MoodleRepository.findIdInFlight.clear();
  // AuthSession.instance 也是可變的 public static，會跨測試外洩。
  // 重設成 UninstalledAuthSession 而不是 FakeAuthSession：忘了裝的測試應該當場
  // 拋 StateError，而不是靜靜地被當成「已經登入」。
  AuthSession.instance = const UninstalledAuthSession();
  // 進行中的登入是 process 級的，測試之間會外洩。
  AppAuthSession.inFlight.clear();
  // 同理：InteractiveLoginGateway.instance 不重設會跨測試外洩，
  // 忘了裝的測試應該當場拋，而不是靜靜地變成登入失敗。
  InteractiveLoginGateway.instance = const UninstalledInteractiveLoginGateway();
  SharedPreferences.setMockInitialValues({});

  // 一般設定與快取沿用 SharedPreferences 的 mock，讓既有測試能繼續用
  // setMockInitialValues 塞資料；憑證與 Moodle token 走記憶體 secure store。
  final plain = SharedPrefsKeyValueStore();
  final secure = InMemorySecureStore();

  Model.instance.store = plain;
  SettingsStore.instance = SettingsStore(plain);
  CacheStore.instance = CacheStore(plain);
  CourseTableStore.instance = CourseTableStore(plain);
  ScoreStore.instance = ScoreStore(plain);
  CredentialsStore.instance = CredentialsStore(secure, plain);
  MoodleSessionStore.instance = MoodleSessionStore(secure, plain);

  return TestStores(plain, secure);
}
