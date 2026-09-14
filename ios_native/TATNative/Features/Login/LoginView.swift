import SwiftUI

/// 內容與流程照 `login_screen.dart`，元件、字級、顏色用 iOS 的。
struct LoginView: View {
  @State private var model: LoginModel
  @State private var showPrivacyPolicy = false
  @FocusState private var accountFocused: Bool
  @FocusState private var passwordFocused: Bool
  private let onSaved: () -> Void

  init(model: LoginModel, onSaved: @escaping () -> Void) {
    _model = State(initialValue: model)
    self.onSaved = onSaved
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Image(uiImage: UIImage(named: "ios-icon") ?? UIImage())
          .resizable()
          .scaledToFill()
          .frame(width: 64, height: 64)
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          .accessibilityHidden(true)

        Text(L10n.loginTitle)
          .font(.title3.weight(.semibold))
          .padding(.top, 24)

        Text(L10n.loginDescription)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .padding(.top, 8)

        TatField(
          label: L10n.account,
          prompt: L10n.accountHint,
          text: $model.account,
          error: model.accountMissing ? L10n.accountNull : nil,
          focused: $accountFocused,
          textContentType: .username,
          keyboardType: .asciiCapable,
          submitLabel: .next,
          onSubmit: { passwordFocused = true }
        )
        .padding(.top, 32)

        TatField(
          label: L10n.password,
          prompt: L10n.password,
          text: $model.password,
          error: model.passwordMissing ? L10n.passwordNull : nil,
          focused: $passwordFocused,
          isSecure: $model.passwordHidden,
          textContentType: .password,
          submitLabel: .go,
          onSubmit: submit
        )
        .padding(.top, 16)

        Button(action: submit) {
          ZStack {
            Text(L10n.login).opacity(model.isSaving ? 0 : 1)
            if model.isSaving { ProgressView() }
          }
          .font(.headline)
          .frame(maxWidth: .infinity)
        }
        .prominentButtonStyle()
        .controlSize(.large)
        .disabled(model.isLoading || model.isSaving)
        .padding(.top, 24)

        Text(L10n.login_hint)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity)
          .padding(.top, 16)

        Text(consent)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity)
          .padding(.top, 12)
          .environment(\.openURL, OpenURLAction { _ in
            showPrivacyPolicy = true
            return .handled
          })
      }
      .padding(EdgeInsets(top: 32, leading: 24, bottom: 24, trailing: 24))
    }
    .scrollDismissesKeyboard(.interactively)
    .background(Color(.systemGroupedBackground))
    .onTapGesture {
      accountFocused = false
      passwordFocused = false
    }
    .sheet(isPresented: $showPrivacyPolicy) { PrivacyPolicySheet() }
    .task { await model.load() }
  }

  private var consent: AttributedString {
    var link = AttributedString(L10n.PrivacyPolicy)
    link.link = URL(string: "tat://privacy-policy")
    return AttributedString(L10n.continueMeansAgree + " ") + link
  }

  private func submit() {
    accountFocused = false
    passwordFocused = false
    Task {
      if await model.save() { onSaved() }
    }
  }
}
