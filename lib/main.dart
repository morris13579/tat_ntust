import 'dart:async';

import 'package:bot_toast/bot_toast.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/firebase_options.dart';
import 'package:flutter_app/src/binding/app_binding.dart';
import 'package:flutter_app/src/config/app_config.dart';
import 'package:flutter_app/src/config/app_themes.dart';
import 'package:flutter_app/src/providers/app_provider.dart';
import 'package:flutter_app/src/providers/category_provider.dart';
import 'package:flutter_app/src/service/app_service.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/analytics_utils.dart';
import 'package:flutter_app/src/util/cloud_messaging_utils.dart';
import 'package:flutter_app/ui/screen/login/login_screen.dart';
import 'package:flutter_app/ui/screen/main_screen.dart';
import 'package:flutter_app/ui/screen/privacy_policy/privacy_policy_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'debug/log/log.dart';
import 'generated/l10n.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    final binding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: binding);

    // Init Firebase
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
    await CloudMessagingUtils.init();

    // Init App
    await Model.instance.getInstance();
    final initialRoute = await getInitialRoute;

    await SystemChrome.setPreferredOrientations(
      [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ],
    );

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppProvider()),
          ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ],
        child: MyApp(initialRoute: initialRoute),
      ),
    );
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
    return Consumer<AppProvider>(builder: (BuildContext context, AppProvider appProvider, Widget? child) {
      appProvider.navigatorKey = Get.key;
      return DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          return GetMaterialApp(
            title: AppConfig.appName,
            initialBinding: AppBindings(),
            onReady: () async {
              FlutterNativeSplash.remove();
              await Get.find<AppService>().init();
            },
            themeMode: ThemeMode.light,
            theme: AppThemes.lightTheme(lightDynamic),
            darkTheme: AppThemes.darkTheme(darkDynamic),
            localizationsDelegates: const [
              S.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalMaterialLocalizations.delegate
            ],
            builder: BotToastInit(),
            navigatorObservers: [
              BotToastNavigatorObserver(),
              AnalyticsUtils.observer
            ],
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
        }
      );
    });
  }
}

Future<String> get getInitialRoute async {
  final isLogin = Model.instance.getAccount().isNotEmpty && Model.instance.getPassword().isNotEmpty;
  if(!isLogin) {
    return "login";
  }
  return "home";
}