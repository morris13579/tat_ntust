import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/firebase_options.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/version/app_version.dart';
import 'package:flutter_app/src/auth/app_auth_session.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/native/app_notice_bridge.dart';
import 'package:flutter_app/src/native/assignment_bridge.dart';
import 'package:flutter_app/src/native/browser_bridge.dart';
import 'package:flutter_app/src/native/calendar_bridge.dart';
import 'package:flutter_app/src/native/classroom_bridge.dart';
import 'package:flutter_app/src/native/core_bridge.dart';
import 'package:flutter_app/src/native/course_detail_bridge.dart';
import 'package:flutter_app/src/native/course_moodle_bridge.dart';
import 'package:flutter_app/src/native/course_search_bridge.dart';
import 'package:flutter_app/src/native/course_table_bridge.dart';
import 'package:flutter_app/src/native/developer_bridge.dart';
import 'package:flutter_app/src/native/forum_bridge.dart';
import 'package:flutter_app/src/native/inbox_bridge.dart';
import 'package:flutter_app/src/native/mail_bridge.dart';
import 'package:flutter_app/src/native/mail_compose_bridge.dart';
import 'package:flutter_app/src/native/mail_memo.dart';
import 'package:flutter_app/src/native/mail_message_bridge.dart';
import 'package:flutter_app/src/native/moodle_setting_bridge.dart';
import 'package:flutter_app/src/native/moodle_memo.dart';
import 'package:flutter_app/src/native/more_bridge.dart';
import 'package:flutter_app/src/native/native_interactive_login_gateway.dart';
import 'package:flutter_app/src/native/native_task_ui_delegate.dart';
import 'package:flutter_app/src/native/quiz_bridge.dart';
import 'package:flutter_app/src/native/score_bridge.dart';
import 'package:flutter_app/src/native/simulation_bridge.dart';
import 'package:flutter_app/src/native/simulation_sessions.dart';
import 'package:flutter_app/src/native/sub_system_bridge.dart';
import 'package:flutter_app/src/native/widget_bridge.dart';
import 'package:flutter_app/src/service/native_web_host.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:flutter_app/src/util/remote_config_utils.dart';

/// 給原生 App 用的進入點：跑起核心，但**不畫任何畫面**。
///
/// `main()` 與這裡的差別只有兩件事：這裡不 `runApp()`，也不安裝任何以
/// `lib/ui/` 實作的介面（`InteractiveLoginGateway`、`TaskUiDelegate`）。
/// 其餘啟動順序刻意與 `main.dart` 一致，兩邊要一起改。
///
/// **必須標 `@pragma('vm:entry-point')`**：原生端是用「進入點名稱」反查這個
/// 函式的，release 的 tree-shaking 與 obfuscation 會把沒標記的符號搖掉或改名。
/// 同樣的理由見 `cloud_messaging_utils.dart` 的背景推播 handler。
///
/// 原生端：
/// ```swift
/// let engine = FlutterEngine(name: "tat-core")
/// engine.run(withEntrypoint: "coreMain",
///            libraryURI: "package:flutter_app/core_main.dart")
/// CorePluginRegistrant.register(with: engine)
/// ```
///
/// **libraryURI 不可以省**：只給名稱時引擎只在根函式庫（建置目標 main.dart）
/// 裡找，而這個函式在另一個檔案。
@pragma('vm:entry-point')
Future<void> coreMain() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 接上原生端已經 configure 過的 default app（見 AppDelegate）。
  // 傳 options 是為了讓 Dart 這一側的設定與 firebase_options.dart 一致；
  // 原生端已經建好時 firebase_core 會回既有的那一個，不會重複建立。
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Dart 的錯誤走 Flutter 的 Crashlytics 外掛，不要改用原生 API：
  // 那個外掛會把 Dart 堆疊轉成 FIRExceptionModel 的 stackTraceElements，
  // Crashlytics 上看得到檔名與行號；原生的 record(error:) 只會是一段字串。
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

  await DioConnector.instance.init();
  // 讀憑證與設定。必須排在 R.load 之前：語系是從設定裡讀出來的。
  await Model.instance.getInstance();

  // **這一行不能省。** 核心層有 134 處 `R.current`，而 `R.current` 是
  // `S.current`——它只要求 `S.load` 跑過（不需要 BuildContext、不需要
  // navigator），但沒跑過就會 assert 失敗。headless 下永遠不會有 widget tree
  // 幫忙載，所以要自己來。
  //
  // 不走 `LanguageUtils.init`：那支需要 BuildContext，而且會呼叫
  // `Get.updateLocale`。語系之後由原生端決定並透過 channel 告知。
  await R
      .load(LanguageUtils.string2Locale(Model.instance.getOtherSetting().lang));
  // 日期格式的語系資料在 Flutter 版是 localization delegate 載的，headless 下沒有人載：
  // 少了這一行，zh_TW 的 DateFormat 一建就丟 LocaleDataException。
  await initializeDateFormatting();

  final auth = AppAuthSession();
  AuthSession.instance = auth;
  // 漏掉這一行，Moodle token 過期後每次重試都會帶著同一顆死 token 再失敗。
  MoodleWebApiConnector.onApiError = auth.onMoodleApiError;
  final moodleToken = await Model.instance.getMoodleToken();
  if (moodleToken != null) {
    MoodleWebApiConnector.restoreToken(moodleToken);
  }

  // TAT 公告（通知中心與啟動彈窗）要的。Flutter 版在 `AppService.init` 裡做，原生版沒有那一段。
  try {
    await RemoteConfigUtils.init();
  } catch (e, stack) {
    Log.eWithStack(e.toString(), stack);
  }

  // 升版後的資料遷移，同 `AppService.init`；要排在橋接裝上之前，畫面讀到的才是遷移過的資料。
  try {
    await APPVersion.migrateIfUpdated();
  } catch (e, stack) {
    Log.eWithStack(e.toString(), stack);
  }

  // 對話框、提示、進度框交給 Swift 畫。介面一字不改，`run()` 那些呼叫端
  // 不知道換了實作。
  NativeTaskUiDelegate.install();
  // WebView 換成 Swift 的 WKWebView：登入頁、成績頁、cookie、headless 登入都在那一側。
  // 不裝的話核心會去呼叫 flutter_inappwebview 的通道，而原生版沒有註冊那個外掛——
  // 得到的是 MissingPluginException。
  NativeWebHost.install();
  NativeInteractiveLoginGateway.install();
  CoreBridge.install();
  CourseTableBridge.install();
  WidgetBridge.install();
  CourseDetailBridge.install();
  // 作業清單與作業詳情共用抓過的作業與繳交狀態。
  final moodle = MoodleMemo();
  CourseMoodleBridge.install(moodle);
  AssignmentBridge.install(moodle);
  QuizBridge.install();
  ForumBridge.install(moodle);
  // 模擬排課頁與搜尋頁改的是同一份草稿。
  final simulations = SimulationSessions();
  SimulationBridge.install(simulations);
  CourseSearchBridge.install(simulations);
  ScoreBridge.install();
  CalendarBridge.install();
  MoreBridge.install();
  SubSystemBridge.install();
  MoodleSettingBridge.install();
  ClassroomBridge.install();
  InboxBridge.install();
  // 清單、內頁與寫信頁指的是同一批信。
  final mail = MailMemo();
  MailBridge.install(mail);
  MailMessageBridge.install(mail);
  MailComposeBridge.install(mail);
  AppNoticeBridge.install();
  BrowserBridge.install();
  DeveloperBridge.install();
  Log.d('coreMain 已啟動');
}

/// 原生版的 App.framework 以這個檔案為建置目標，建置目標一定要有 `main`；引擎實際跑的是 [coreMain]。
Future<void> main() => coreMain();
