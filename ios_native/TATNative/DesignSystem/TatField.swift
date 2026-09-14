import SwiftUI

/// 標籤在上、圓角填色的輸入欄。版面沿用 Flutter 版的 `InputField`，顏色與字級用系統的。
struct TatField: View {
  let label: String
  let prompt: String
  @Binding var text: String
  var error: String?
  var focused: FocusState<Bool>.Binding
  /// 非 nil 才有眼睛按鈕。
  var isSecure: Binding<Bool>?
  var textContentType: UITextContentType?
  var keyboardType: UIKeyboardType = .default
  var submitLabel: SubmitLabel = .return
  var onSubmit: () -> Void = {}

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label)
        .font(.subheadline)
        .padding(.leading, 4)

      HStack(spacing: 4) {
        field
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .textContentType(textContentType)
          .keyboardType(keyboardType)
          .submitLabel(submitLabel)
          .focused(focused)
          .onSubmit(onSubmit)

        if let isSecure {
          Button {
            // SecureField 與 TextField 是不同的 view，切換時焦點會掉，要自己補回。
            let wasFocused = focused.wrappedValue
            isSecure.wrappedValue.toggle()
            if wasFocused {
              DispatchQueue.main.async { focused.wrappedValue = true }
            }
          } label: {
            LucideImage(isSecure.wrappedValue ? Lucide.eyeOff : Lucide.eye, size: 18)
              .foregroundStyle(.secondary)
              .frame(width: 36, height: 36)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel(isSecure.wrappedValue ? L10n.showPassword : L10n.hidePassword)
        }
      }
      .padding(.leading, 14)
      .padding(.trailing, isSecure == nil ? 14 : 6)
      .frame(minHeight: 48)
      .background(Color(.secondarySystemGroupedBackground), in: shape)
      .overlay { shape.strokeBorder(error == nil ? Color.clear : Color(.systemRed), lineWidth: 1.5) }

      if let error {
        Text(error)
          .font(.footnote)
          .foregroundStyle(Color(.systemRed))
          .padding(.leading, 4)
      }
    }
  }

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: 12, style: .continuous)
  }

  @ViewBuilder private var field: some View {
    if isSecure?.wrappedValue == true {
      SecureField(text: $text, prompt: Text(prompt)) { Text(label) }
    } else {
      TextField(text: $text, prompt: Text(prompt)) { Text(label) }
    }
  }
}
