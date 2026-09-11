import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/firebase_options.dart';
import 'package:flutter_app/src/controller/app_binding.dart';
import 'package:flutter_app/src/config/app_config.dart';
import 'package:flutter_app/src/config/app_themes.dart';
import 'package:flutter_app/src/service/app_service.dart';
import 'package:flutter_app/src/service/theme_service.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/store/credentials_store.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/service/interactive_login_gateway.dart';
import 'package:flutter_app/ui/auth/get_interactive_login_gateway.dart';
import 'package:flutter_app/ui/components/update_prompt.dart';
import 'package:flutter_app/src/auth/app_auth_session.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/ui/service/get_task_ui_delegate.dart';
import 'package:flutter_app/ui/routes/route_utils.dart';
import 'package:flutter_app/src/util/analytics_utils.dart';
import 'package:flutter_app/src/util/cloud_messaging_utils.dart';
import 'package:flutter_app/ui/screen/login/login_screen.dart';
import 'package:flutter_app/ui/screen/main_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:get/get.dart';

import 'debug/log/log.dart';
import 'generated/l10n.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    final binding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: binding);

    // Init Firebase
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
    await CloudMessagingUtils.init();

    // Init App
    await DioConnector.instance.init();
    await Model.instance.getInstance();
    // 必須在這裡，不能移到 GetMaterialApp.onReady。下面第一次讀
    // getInitialRoute 就會問 AuthSession，而 onReady 要等第一幀之後才跑：
    // 那時 instance 還是 UninstalledAuthSession，isSignedIn 直接拋，
    // 例外被 runZonedGuarded 吞掉、runApp 不執行、原生 splash 也不會被移除
    // ——畫面就永遠停在啟動圖。單元測試不跑 main()，所以這件事只有冷啟動看得到。
    // 依賴順序：AppAuthSession.isSignedIn 讀 CredentialsStore，
    // 所以要在 Model.instance.getInstance() 之後。
    final auth = AppAuthSession();
    AuthSession.instance = auth;
    // Moodle 的 token 過期時作廢它，下一次 ensure 就會重登。connector 只把
    // 錯誤送出來、不自己重登，理由見 AppAuthSession.onMoodleApiError。
    MoodleWebApiConnector.onApiError = auth.onMoodleApiError;
    // 同樣必須在 runApp 之前。MainController.onInit（GetX 不 await 它）會在
    // initialBinding 建構時就跑到 MoodleWebApiConnector.login，比 onReady 早。
    InteractiveLoginGateway.instance = const GetInteractiveLoginGateway();
    final moodleToken = await Model.instance.getMoodleToken();
    if (moodleToken != null) {
      MoodleWebApiConnector.restoreToken(moodleToken);
    }
    await ThemeService.instance.init();
    final initialRoute = await getInitialRoute;

    // Style
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    unawaited(
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]));
    runApp(MyApp(initialRoute: initialRoute));
  }, (dynamic exception, StackTrace stack, {dynamic context}) {
    Log.error(exception.toString(), stack);
    FirebaseCrashlytics.instance.recordError(exception, stack);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.initialRoute});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
      return GetMaterialApp(
        title: AppConfig.appName,
        initialBinding: AppBindings(),
        onReady: () async {
          FlutterNativeSplash.remove();
          TaskUiDelegate.instance = const GetTaskUiDelegate();
          final appService = Get.find<AppService>();
          if (await appService.needsPrivacyAgreement) {
            await RouteUtils.toAgreePrivacyPolicyScreen();
          }
          await appService.init();
          await RouteUtils.showAnnouncement();
        },
        themeMode: ThemeService.instance.theme,
        theme: AppThemes.lightTheme(lightDynamic),
        darkTheme: AppThemes.darkTheme(darkDynamic),
        localizationsDelegates: const [
          S.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalMaterialLocalizations.delegate
        ],
        builder: (context, child) => UpdatePrompt(
          navigatorKey: Get.key,
          child: child ?? const SizedBox.shrink(),
        ),
        navigatorObservers: [AnalyticsUtils.observer],
        supportedLocales: S.delegate.supportedLocales,
        initialRoute: initialRoute,
        getPages: [
          GetPage(name: '/home', page: () => const MainScreen()),
          GetPage(name: '/login', page: () => const LoginScreen()),
        ],
        debugShowCheckedModeBanner: false,
        logWriterCallback: (String text, {bool? isError}) {
          Log.d(text);
        },
      );
    });
  }
}

Future<String> get getInitialRoute async {
  if (AuthSession.instance.isSignedIn) {
    return "home";
  }
  // **「讀不到」不等於「沒登入」。**
  //
  // 安全儲存區暫時不可用時（Android 從備份還原、iOS 在鎖定狀態下被背景推播
  // 喚醒），[CredentialsStore.load] 會回 unavailable 而且不填 _data，於是
  // `isSignedIn` 是 false——但那只代表這一次讀不出來，不代表使用者登出了。
  //
  // 舊行為是把人送到登入畫面，等於要求重打密碼：把「不知道」當成「已登出」，
  // 是三種解讀裡最糟的一個。CredentialsLoadResult 這個三態當初就是為了避免
  // 這件事而引入的，卻在這裡被丟掉。
  //
  // 現在改成照樣進主畫面。課表與成績都在硬碟上，看得到；真的需要憑證的操作
  // 會走 run() 既有的錯誤處理照實報錯，而不是先把使用者的登入狀態抹掉。
  if (CredentialsStore.instance.lastResult ==
      CredentialsLoadResult.unavailable) {
    return "home";
  }
  return "login";
}
