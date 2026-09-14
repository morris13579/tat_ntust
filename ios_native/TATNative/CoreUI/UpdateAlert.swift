import SwiftUI
import UIKit

extension View {
  /// 有新版本時的提示：啟動時問一次，更多頁的「檢查新版本」也用同一個。
  func updateAlert(_ offer: Binding<UpdateOffer?>, onIgnore: @escaping () -> Void) -> some View {
    alert(
      L10n.updateTitle,
      isPresented: Binding(get: { offer.wrappedValue != nil }, set: { if !$0 { offer.wrappedValue = nil } }),
      presenting: offer.wrappedValue
    ) { offer in
      Button(L10n.update) {
        if let url = URL(string: offer.storeUrl) { UIApplication.shared.open(url) }
      }
      Button(L10n.updateIgnore, action: onIgnore)
      Button(L10n.updateLater, role: .cancel) {}
    } message: { offer in
      Text(updateMessage(offer))
    }
  }
}

private func updateMessage(_ offer: UpdateOffer) -> String {
  var parts = [L10n.updateBody(offer.installedVersion, offer.storeVersion)]
  if let notes = offer.releaseNotes, !notes.isEmpty {
    parts.append("\(L10n.updateReleaseNotes)\n\(notes)")
  }
  parts.append(L10n.updatePrompt)
  return parts.joined(separator: "\n\n")
}
