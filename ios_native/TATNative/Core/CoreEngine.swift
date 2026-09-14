import Flutter

/// 唯一一顆 FlutterEngine，跑 `lib/core_main.dart` 的 `coreMain`，不畫任何東西。
final class CoreEngine {
  private let flutter = FlutterEngine(name: "tat-core")

  var messenger: FlutterBinaryMessenger { flutter.binaryMessenger }

  func start(uiHost: TatCoreUiApi, transfers: TatTransferHost, mail: TatMailHost) {
    // libraryURI 不可以省：只給名稱時只在根函式庫（main.dart）裡找。回傳值也不可信，
    // 找不到進入點時照樣回 true。
    _ = flutter.run(withEntrypoint: "coreMain", libraryURI: "package:flutter_app/core_main.dart")
    // 要在 run 之後：少了它，Dart 端讀 Keychain / SharedPreferences 會是 MissingPluginException。
    CorePluginRegistrant.register(with: flutter)
    TatCoreUiApiSetup.setUp(binaryMessenger: messenger, api: uiHost)
    TatTransferHostSetup.setUp(binaryMessenger: messenger, api: transfers)
    TatMailHostSetup.setUp(binaryMessenger: messenger, api: mail)
  }
}

/// Dart 那一側打包進 App.framework 的資源（`pubspec.yaml` 的 flutter.assets）。
enum CoreAssets {
  static func url(_ asset: String) -> URL? {
    let key = FlutterDartProject.lookupKey(forAsset: asset)
    return Bundle.main.url(forResource: key, withExtension: nil)
  }
}
