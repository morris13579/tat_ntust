import SwiftUI

/// 首次啟動的同意閘門，照 `privacy_policy_screen.dart`：沒有返回；同意鈕一直可按，不做倒數、也不要求捲到底——
/// 強迫閱讀不會讓人真的讀，只會讓人更快按掉。
struct PrivacyAgreementView: View {
  let onAgree: () -> Void

  var body: some View {
    NavigationStack {
      PrivacyPolicyContent()
        .pinnedBottomBar {
          VStack(spacing: 10) {
            Button(action: onAgree) {
              Text(L10n.privacyAgreeContinue)
                .frame(maxWidth: .infinity)
            }
            .prominentButtonStyle()
            .controlSize(.large)
            Text(L10n.privacyAgreeRequired)
              .font(.footnote)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
          }
          .padding(EdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24))
        }
        .navigationTitle(L10n.PrivacyPolicy)
        .navigationBarTitleDisplayMode(.inline)
        .analyticsScreen("/PrivacyPolicyScreen")
    }
  }
}
