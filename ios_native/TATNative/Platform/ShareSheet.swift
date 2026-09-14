import UIKit

/// 系統的分享面板。從最上層正在顯示的畫面開，所以 sheet 開著的時候也開得出來。
@MainActor
enum ShareSheet {
  static func present(pngData: Data, fileName: String) {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    guard (try? pngData.write(to: url, options: .atomic)) != nil else { return }
    present(items: [url])
  }

  static func present(items: [Any]) {
    guard let top = TopViewController.find() else { return }
    let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
    // iOS 26 起 iPhone 的分享面板也走 popover，沒有錨點就開不出來。
    if let popover = controller.popoverPresentationController {
      popover.sourceView = top.view
      popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.maxY - 80, width: 1, height: 1)
    }
    top.present(controller, animated: true)
  }
}
