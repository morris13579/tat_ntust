import SwiftUI

/// 設定校內信箱，照 `mail_setup_page.dart`：帳號帶入不給改，只填密碼，驗過才存。
struct MailSetupView: View {
  let address: String
  let client: MailClient
  let onDone: () -> Void
  @State private var password = ""
  @State private var hidden = true
  @State private var verifying = false
  @State private var error: String?
  @FocusState private var focused: Bool

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        // 和登入頁同一顆：這一頁做的事跟那一頁一樣，填一組帳密把某個東西接起來。
        Image(uiImage: UIImage(named: "ios-icon") ?? UIImage())
          .resizable()
          .scaledToFill()
          .frame(width: 64, height: 64)
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          .accessibilityHidden(true)

        Text(L10n.mailSetupTitle)
          .font(.title3.weight(.semibold))
          .padding(.top, 24)

        Text(L10n.mailSetupDesc)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .padding(.top, 8)

        VStack(alignment: .leading, spacing: 12) {
          benefit(Lucide.reply, L10n.mailSetupBenefitRead)
          benefit(Lucide.search, L10n.mailSetupBenefitSearch)
          benefit(Lucide.download, L10n.mailSetupBenefitAttachment)
        }
        .padding(.top, 20)

        fields
          .padding(.top, 24)

        if let error {
          Text(error)
            .font(.footnote)
            .foregroundStyle(Color(.systemRed))
            .padding(.top, 8)
            .padding(.horizontal, 4)
        }

        HStack(alignment: .firstTextBaseline, spacing: 8) {
          LucideImage(Lucide.shieldCheck, size: 16)
            .alignedToFirstTextLine(.footnote)
          Text(L10n.login_hint)
            .font(.footnote)
        }
        .foregroundStyle(.secondary)
        .padding(.top, 14)
        .padding(.horizontal, 4)

        Button(action: submit) {
          ZStack {
            Text(L10n.mailLogin).opacity(verifying ? 0 : 1)
            if verifying { ProgressView() }
          }
          .font(.headline)
          .frame(maxWidth: .infinity)
        }
        .prominentButtonStyle()
        .controlSize(.large)
        // 空密碼由停用主鈕擋掉，不另外給一句和提示字一樣的錯誤。
        .disabled(verifying || password.isEmpty)
        .padding(.top, 18)
      }
      .padding(EdgeInsets(top: 20, leading: 24, bottom: 32, trailing: 24))
    }
    .scrollDismissesKeyboard(.interactively)
    .background(Color(.systemGroupedBackground))
    .navigationTitle(L10n.mailTab)
    .navigationBarTitleDisplayMode(.inline)
  }

  private func benefit(_ icon: LucideIcon, _ label: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 11) {
      LucideImage(icon, size: 18)
        .foregroundStyle(Color.tatBrand)
        .alignedToFirstTextLine(.body)
      Text(label)
    }
  }

  /// 帳號與密碼一張卡兩列，標籤在左，和寫信頁的欄位群組同一個排法。
  private var fields: some View {
    VStack(spacing: 0) {
      row(L10n.account) {
        Text(address)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      Divider().padding(.leading, 14)
      row(L10n.password) {
        HStack(spacing: 4) {
          Group {
            if hidden {
              SecureField(text: $password, prompt: Text(L10n.passwordNull)) { Text(L10n.password) }
            } else {
              TextField(text: $password, prompt: Text(L10n.passwordNull)) { Text(L10n.password) }
            }
          }
          .textContentType(.password)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .submitLabel(.go)
          .focused($focused)
          .onSubmit(submit)
          .disabled(verifying)

          Button {
            // SecureField 與 TextField 是不同的 view，切換時焦點會掉，要自己補回。
            let wasFocused = focused
            hidden.toggle()
            if wasFocused { DispatchQueue.main.async { focused = true } }
          } label: {
            LucideImage(hidden ? Lucide.eyeOff : Lucide.eye, size: 18)
              .foregroundStyle(.secondary)
              .frame(width: 44, height: 44)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel(hidden ? L10n.showPassword : L10n.hidePassword)
        }
      }
    }
    .background(
      Color(.secondarySystemGroupedBackground), in: ListGroupShape.card)
  }

  private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
    HStack(spacing: 10) {
      Text(label)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(width: 68, alignment: .leading)
      content()
    }
    .padding(.leading, 14)
    .padding(.trailing, 6)
    .frame(minHeight: 52)
  }

  /// 密碼錯與連不上分開講：前者留在這裡重打，後者重打幾次都一樣。
  private func submit() {
    guard !password.isEmpty, !verifying else { return }
    focused = false
    verifying = true
    error = nil
    Task {
      let result = try? await client.setup(password: password)
      verifying = false
      if result?.ok == true {
        password = ""
        onDone()
      } else {
        error = result == nil ? L10n.mailPasswordUnreachable : result?.error
      }
    }
  }
}
