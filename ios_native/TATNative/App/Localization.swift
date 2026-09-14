import Foundation

/// 介面字串的執行期。key 與翻譯來自 `lib/l10n/*.arb`，由 `tool/gen_ios_l10n.py` 產生
/// `Resources/*.lproj/Localizable.strings` 與 `Resources/Generated/L10n.swift`。
///
/// **語言跟著核心的設定走，不跟系統**：核心送給學校的請求也看那個設定（課名、子系統清單），
/// 兩邊各自決定的話會變成英文課名配中文介面。
///
/// 小工具 extension 也編這個檔案，所以這裡不認得核心的型別；App 的語言設定怎麼換成 lproj 在 `AppLanguage+L10n.swift`。
enum L10n {
  nonisolated(unsafe) private static var bundle = Bundle.main

  /// 日期與數字的格式也跟著介面語言，不跟系統。
  nonisolated(unsafe) private(set) static var locale = Locale(identifier: "zh_Hant_TW")

  static func use(lproj: String, locale identifier: String) {
    bundle = Bundle.main.path(forResource: lproj, ofType: "lproj")
      .flatMap(Bundle.init(path:)) ?? .main
    locale = Locale(identifier: identifier)
  }

  static func tr(_ key: String, _ args: CVarArg...) -> String {
    let format = bundle.localizedString(forKey: key, value: nil, table: nil)
    return args.isEmpty ? format : String(format: format, arguments: args)
  }
}
