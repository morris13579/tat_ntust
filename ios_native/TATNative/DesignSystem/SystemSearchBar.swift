import SwiftUI
import UIKit

/// 系統的 `UISearchBar`，給掛不了 `.searchable` 的地方用（例如 page 樣式分頁裡的單一頁）：
/// 外觀、清除鈕、開始打字時旁邊的關閉鈕與鍵盤的「搜尋」鍵都跟導覽列上的搜尋列一樣。
struct SystemSearchBar: UIViewRepresentable {
  @Binding var text: String
  let prompt: String

  func makeUIView(context: Context) -> UISearchBar {
    let bar = UISearchBar()
    bar.searchBarStyle = .minimal
    bar.autocorrectionType = .no
    bar.autocapitalizationType = .none
    bar.returnKeyType = .search
    bar.delegate = context.coordinator
    bar.setContentHuggingPriority(.defaultHigh, for: .vertical)
    return bar
  }

  func updateUIView(_ bar: UISearchBar, context: Context) {
    context.coordinator.text = $text
    bar.placeholder = prompt
    if bar.text != text { bar.text = text }
    if text.isEmpty, !bar.isFirstResponder, bar.showsCancelButton {
      bar.setShowsCancelButton(false, animated: false)
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text)
  }

  @MainActor
  final class Coordinator: NSObject, UISearchBarDelegate {
    var text: Binding<String>

    init(text: Binding<String>) {
      self.text = text
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
      text.wrappedValue = searchText
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
      searchBar.setShowsCancelButton(true, animated: true)
    }

    /// 跟 `.searchable` 一樣：還有關鍵字時收起鍵盤，關閉鈕留著；按關閉鈕才清空。
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
      if searchBar.text?.isEmpty ?? true {
        searchBar.setShowsCancelButton(false, animated: true)
      }
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
      searchBar.text = ""
      text.wrappedValue = ""
      searchBar.resignFirstResponder()
      searchBar.setShowsCancelButton(false, animated: true)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
      searchBar.resignFirstResponder()
    }
  }
}
