#import "CorePluginRegistrant.h"

// import 的寫法照抄 Flutter 產生的 GeneratedPluginRegistrant：
// **先試標頭、@import 只是退路**。直接寫 @import 會強制編模組，而
// firebase_* 的標頭 include 了 Firebase 這個非模組化的 umbrella pod，
// 於是撞上 -Wnon-modular-include-in-framework-module（而且是 -Werror）。

#if __has_include(<charset_converter/CharsetConverterPlugin.h>)
#import <charset_converter/CharsetConverterPlugin.h>
#else
@import charset_converter;
#endif

#if __has_include(<connectivity_plus/ConnectivityPlusPlugin.h>)
#import <connectivity_plus/ConnectivityPlusPlugin.h>
#else
@import connectivity_plus;
#endif

#if __has_include(<firebase_core/FLTFirebaseCorePlugin.h>)
#import <firebase_core/FLTFirebaseCorePlugin.h>
#else
@import firebase_core;
#endif

#if __has_include(<firebase_crashlytics/FLTFirebaseCrashlyticsPlugin.h>)
#import <firebase_crashlytics/FLTFirebaseCrashlyticsPlugin.h>
#else
@import firebase_crashlytics;
#endif

#if __has_include(<firebase_remote_config/FLTFirebaseRemoteConfigPlugin.h>)
#import <firebase_remote_config/FLTFirebaseRemoteConfigPlugin.h>
#else
@import firebase_remote_config;
#endif

#if __has_include(<fk_user_agent/FkUserAgentPlugin.h>)
#import <fk_user_agent/FkUserAgentPlugin.h>
#else
@import fk_user_agent;
#endif

#if __has_include(<flutter_secure_storage/FlutterSecureStoragePlugin.h>)
#import <flutter_secure_storage/FlutterSecureStoragePlugin.h>
#else
@import flutter_secure_storage;
#endif

#if __has_include(<in_app_review/InAppReviewPlugin.h>)
#import <in_app_review/InAppReviewPlugin.h>
#else
@import in_app_review;
#endif

#if __has_include(<package_info_plus/FPPPackageInfoPlusPlugin.h>)
#import <package_info_plus/FPPPackageInfoPlusPlugin.h>
#else
@import package_info_plus;
#endif

#if __has_include(<shared_preferences_foundation/SharedPreferencesPlugin.h>)
#import <shared_preferences_foundation/SharedPreferencesPlugin.h>
#else
@import shared_preferences_foundation;
#endif

#if __has_include(<sqflite_darwin/SqflitePlugin.h>)
#import <sqflite_darwin/SqflitePlugin.h>
#else
@import sqflite_darwin;
#endif

#if __has_include(<url_launcher_ios/URLLauncherPlugin.h>)
#import <url_launcher_ios/URLLauncherPlugin.h>
#else
@import url_launcher_ios;
#endif

@implementation CorePluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry> *)registry {
  // Firebase：Crashlytics 與 Remote Config。
  //
  // Crashlytics 走 Flutter 外掛而不是原生 API，因為那個外掛會把 Dart 的堆疊
  // 轉成 FIRExceptionModel 的 stackTraceElements（真的 FIRStackFrame，有檔名
  // 行號）。改用原生的 record(error:) 只會得到一段字串，Dart 的框架就沒了。
  //
  // Remote Config 是 AppNoticeRepository 要的（App 自己的公告）。
  // Analytics 與 Messaging 不在這裡：它們的呼叫端都在 UI 或 main.dart，
  // 在原生版是 Swift 的責任。
  [FLTFirebaseCorePlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTFirebaseCorePlugin"]];
  [FLTFirebaseCrashlyticsPlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTFirebaseCrashlyticsPlugin"]];
  [FLTFirebaseRemoteConfigPlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTFirebaseRemoteConfigPlugin"]];

  [CharsetConverterPlugin registerWithRegistrar:[registry registrarForPlugin:@"CharsetConverterPlugin"]];
  [ConnectivityPlusPlugin registerWithRegistrar:[registry registrarForPlugin:@"ConnectivityPlusPlugin"]];
  // DioConnector 組 User-Agent 時會用到。
  [FkUserAgentPlugin registerWithRegistrar:[registry registrarForPlugin:@"FkUserAgentPlugin"]];
  [FlutterSecureStoragePlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterSecureStoragePlugin"]];
  // 評分邀請、更新提示與意見回饋要版本號；更新提示送去 App Store 走 url_launcher。
  [FPPPackageInfoPlusPlugin registerWithRegistrar:[registry registrarForPlugin:@"FPPPackageInfoPlusPlugin"]];
  [InAppReviewPlugin registerWithRegistrar:[registry registrarForPlugin:@"InAppReviewPlugin"]];
  [SharedPreferencesPlugin registerWithRegistrar:[registry registrarForPlugin:@"SharedPreferencesPlugin"]];
  [SqflitePlugin registerWithRegistrar:[registry registrarForPlugin:@"SqflitePlugin"]];
  [URLLauncherPlugin registerWithRegistrar:[registry registrarForPlugin:@"URLLauncherPlugin"]];
}

@end
