import Foundation

extension L10n {
  static func use(_ language: AppLanguage) {
    use(lproj: language.lproj, locale: language == .zhTW ? "zh_Hant_TW" : "en")
  }
}

extension AppLanguage {
  /// 字串檔的 lproj。寫給小工具的課表也用它記住介面語言。
  var lproj: String {
    switch self {
    case .zhTW: "zh-Hant"
    case .en: "en"
    }
  }

  /// 使用者沒選過語言時用系統的。和 Flutter 的語系比對一致：中文（含簡體）落到繁中，其餘英文。
  static var system: AppLanguage {
    guard let first = Locale.preferredLanguages.first,
      Locale(identifier: first).language.languageCode == .chinese
    else { return .en }
    return .zhTW
  }
}
