import 'dart:async';

import 'package:bot_toast/bot_toast.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/firebase_options.dart';
import 'package:flutter_app/src/config/app_config.dart';
import 'package:flutter_app/src/config/app_themes.dart';
import 'package:flutter_app/src/providers/app_provider.dart';
import 'package:flutter_app/src/providers/category_provider.dart';
import 'package:flutter_app/src/util/analytics_utils.dart';
import 'package:flutter_app/src/util/cloud_messaging_utils.dart';
import 'package:flutter_app/ui/screen/main_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'debug/log/log.dart';
import 'generated/l10n.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
    await CloudMessagingUtils.init();
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
        child: const MyApp(),
      ),
    );
  }, (dynamic exception, StackTrace stack, {dynamic context}) {
    Log.error(exception.toString(), stack);
    FirebaseCrashlytics.instance.recordError(exception, stack);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder:
        (BuildContext context, AppProvider appProvider, Widget? child) {
      appProvider.navigatorKey = Get.key;
      return GetMaterialApp(
        title: AppConfig.appName,
        theme: appProvider.theme,
        darkTheme: AppThemes.darkTheme,
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
        home: const MainScreen(),
        debugShowCheckedModeBanner: false,
        logWriterCallback: (String text, {bool? isError}) {
          Log.d(text);
        },
      );
    });
  }
}
