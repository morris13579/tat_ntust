import SwiftUI

/// 區塊層級的錯誤：訊息加一顆重試，沒登入時改成「登入」，照 `inline_error_view.dart`。
struct InlineErrorView: View {
  let message: String
  let signedIn: Bool
  let presenter: UiPresenter
  let retry: () async -> Void

  var body: some View {
    VStack(spacing: 12) {
      LucideImage(Lucide.triangleAlert, size: 28)
        .foregroundStyle(.secondary)
      Text(message)
        .font(.subheadline)
        .multilineTextAlignment(.center)
        .lineLimit(3)
      if signedIn {
        Button(L10n.refresh) { Task { await retry() } }
      } else {
        Button(L10n.login) {
          presenter.requestLogin { Task { await retry() } }
        }
        .prominentButtonStyle()
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 24)
    .padding(.horizontal, 20)
  }
}
