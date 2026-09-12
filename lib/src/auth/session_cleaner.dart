import 'dart:io';

import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/connector/classroom_connector.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/store/cache_store.dart';
import 'package:flutter_app/src/store/mail_store.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/store/moodle_session_store.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';

/// 登出時要清掉的所有 session 狀態。[AuthSession.ensure] 的鏡像。
///
/// **住在 `lib/src/auth/` 而不是 `service/`**：它要呼叫
/// `AuthSession.invalidate`，而 `tool/deps.py` 裡 auth 排在 util 上面——
/// 放在 service 會是 `util -> auth` 的上行邊。「登出」本來就是 auth 的事。
///
/// 下面每一項都要清乾淨；漏掉任何一項，換帳號之後 B 就會看到 A 的資料：
///
/// - `MoodleWebApiConnector.wsToken`：留著就照樣讀得到 A 的課程、成績與
///   個人資料。
/// - 平台 WebView 的 cookie store：成績頁的 HeadlessInAppWebView 靠的就是
///   這一套 cookie。
/// - courseId 對照表與其他 `cache_` 快取。
/// - 桌面小工具的截圖 `course_widget.png`。
///
/// 四個外部副作用以建構子注入，讓這個類別可以在沒有平台通道的環境下測試。
class SessionCleaner {
  final Future<void> Function() clearWebViewCookies;
  final Future<void> Function() clearDioCookies;
  final Future<void> Function() clearModel;
  final Future<void> Function() clearWidgetImage;

  SessionCleaner({
    required this.clearWebViewCookies,
    required this.clearDioCookies,
    required this.clearModel,
    required this.clearWidgetImage,
  });

  /// 正式環境使用的預設實作。
  factory SessionCleaner.platform() => SessionCleaner(
        clearWebViewCookies: () => CookieManager.instance().deleteAllCookies(),
        // 直接回傳 deleteCookies() 的 Future，不要包一層 `() async => ...`：
        // 那層 arrow-async 會讓 logoutAll 的 await 在 cookie 真的刪掉之前就回來，
        // 也會把刪除失敗擋在 _step 的 try/catch 外面。
        clearDioCookies: () => DioConnector.instance.deleteCookies(),
        clearModel: () => Model.instance.logout(),
        clearWidgetImage: () async {
          if (!Platform.isAndroid) return;
          final dir = await getApplicationSupportDirectory();
          final file = File('${dir.path}/course_widget.png');
          if (await file.exists()) {
            await file.delete();
          }
        },
      );

  /// 清掉所有與「目前這位使用者」有關的狀態。
  ///
  /// 每一步都各自 try/catch：任何一步失敗都不該讓後面的步驟被跳過。
  ///
  /// 刻意**不**呼叫 `Get.delete<MainController>()`：MainScreen 以 State
  /// 欄位持有它，OtherPage 與 SettingPage 在登出後仍會 `Get.find` 它，
  /// 刪掉會直接拋 not found。重設狀態即可。
  Future<void> logoutAll() async {
    await _step('resetLoginFlags', () async {
      // 走 AuthSession 而不是直接改旗標：登入狀態的所有權在它那裡，
      // 在這裡再抄一份清單就會漏。SystemId.values 是「全部」。
      await AuthSession.instance.invalidate(SystemId.values.toSet());
    });
    await _step('clearMoodleToken', () async {
      // 記憶體快取與持久化兩邊都要清。
      MoodleWebApiConnector.wsToken = null;
      // userId 是 site_info 快取下來的，屬於前一位使用者。
      MoodleWebApiConnector.userId = null;
      // 這份課程清單是上一位使用者的，留著就是拿 A 的課程去解析 B 的課號。
      MoodleWebApiConnector.clearCoursesCache();
      // siteInfo 裝著前一位使用者的 function 清單與 userprivateaccesskey。
      MoodleWebApiConnector.siteInfo = null;
      await MoodleSessionStore.instance.clear();
    });
    await _step('clearClassroomPages', () async {
      // 留在記憶體裡的那份 ViewState 是上一位使用者的 cour01 session 上的
      // 頁面狀態。它本身不含個人資料，但留著會讓下一位使用者的第一次查詢
      // 帶著一份已經作廢的狀態出去，白跑一趟重試。
      ClassroomConnector.clearCachedPages();
    });
    await _step('clearMailStore', () async {
      // 信件不在 `cache_` 前綴那批裡，它有自己的 SQLite 檔。漏掉這一步，
      // 換帳號之後 B 會看到 A 的信件標題與寄件者。
      await MailStore.instance.clear();
    });
    await _step('clearCaches', () async {
      // 同時清掉 cache_moodle_support（courseId 對照表）與其他 cache_ 前綴的
      // 離線快取。Model.logout 也會清一次，重複無害。
      await CacheStore.instance.clearAll();
    });
    await _step('clearWebViewCookies', clearWebViewCookies);
    await _step('clearDioCookies', clearDioCookies);
    await _step('clearModel', clearModel);
    await _step('clearWidgetImage', clearWidgetImage);
  }

  Future<void> _step(String name, Future<void> Function() body) async {
    try {
      await body();
    } catch (e, stack) {
      Log.eWithStack("logout step failed: $name / $e", stack);
    }
  }
}
