#import <Flutter/Flutter.h>

NS_ASSUME_NONNULL_BEGIN

/// 只註冊 Dart 核心用得到的外掛。
///
/// 刻意**不是** Flutter 產生的 `GeneratedPluginRegistrant`，兩個理由：
///
/// 1. 目標架構把 UI 類外掛（image_picker、share_plus、local_auth…）與 Firebase
///    都歸給 Swift，核心不需要它們。
/// 2. 那份產生的 registrant 會註冊全部 31 個外掛，而 firebase_* 的 framework
///    需要 `Firebase/Firebase.h`——那個 umbrella 標頭由 `Firebase` 這個
///    「只有標頭」的 pod 提供，`flutter build ios-framework` **不會**把它
///    輸出成 xcframework。詳見計畫書 §四 E5。
///
/// `path_provider` 不在清單裡是對的：`path_provider_foundation` 2.6.0 在 Apple
/// 平台宣告的是 `dartPluginClass`（純 Dart + FFI），`.flutter-plugins-dependencies`
/// 裡的 `native_build` 是 false，沒有 pod 也沒有 xcframework，不需要註冊。
@interface CorePluginRegistrant : NSObject
+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry> *)registry;
@end

NS_ASSUME_NONNULL_END
