import UIKit

/// 最上層正在顯示的畫面，sheet 開著的時候也找得到。給只能從 UIKit 開的系統畫面用。
@MainActor
enum TopViewController {
  static func find() -> UIViewController? {
    var top = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)?
      .rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}
