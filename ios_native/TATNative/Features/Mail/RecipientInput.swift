import SwiftUI
import UIKit

/// 收件者欄那一截還在打的字。SwiftUI 的 TextField 攔不到「空欄位按退格」，
/// 而那是刪掉最後一顆籤最順手的方法，照 `MailRecipientField._onKey`。
struct RecipientInput: UIViewRepresentable {
  @Binding var text: String
  @Binding var focused: Bool
  let label: String
  var onReturn: () -> Void
  var onDeleteEmpty: () -> Void
  var onEndEditing: () -> Void

  func makeUIView(context: Context) -> BackspaceTextField {
    let field = BackspaceTextField()
    field.font = .preferredFont(forTextStyle: .body)
    field.adjustsFontForContentSizeCategory = true
    field.keyboardType = .emailAddress
    field.textContentType = .emailAddress
    // 位址不該被自動大寫：`Prof@` 和 `prof@` 看起來就像兩個人。
    field.autocapitalizationType = .none
    field.autocorrectionType = .no
    field.spellCheckingType = .no
    field.returnKeyType = .next
    field.delegate = context.coordinator
    field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
    field.setContentHuggingPriority(.defaultLow, for: .horizontal)
    field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return field
  }

  func updateUIView(_ field: BackspaceTextField, context: Context) {
    context.coordinator.parent = self
    if field.text != text { field.text = text }
    field.accessibilityLabel = label
    field.onDeleteEmpty = onDeleteEmpty
    if focused, !field.isFirstResponder {
      DispatchQueue.main.async { field.becomeFirstResponder() }
    } else if !focused, field.isFirstResponder {
      DispatchQueue.main.async { field.resignFirstResponder() }
    }
  }

  func sizeThatFits(_ proposal: ProposedViewSize, uiView: BackspaceTextField, context: Context) -> CGSize? {
    CGSize(width: proposal.width ?? 48, height: ceil((uiView.font?.lineHeight ?? 20) + 16))
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  @MainActor
  final class Coordinator: NSObject, UITextFieldDelegate {
    var parent: RecipientInput

    init(parent: RecipientInput) {
      self.parent = parent
    }

    @objc func changed(_ field: UITextField) {
      parent.text = field.text ?? ""
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
      if !parent.focused { parent.focused = true }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
      if parent.focused { parent.focused = false }
      parent.onEndEditing()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
      parent.onReturn()
      return false
    }
  }
}

final class BackspaceTextField: UITextField {
  var onDeleteEmpty: (() -> Void)?

  override func deleteBackward() {
    if (text ?? "").isEmpty { onDeleteEmpty?() }
    super.deleteBackward()
  }
}

/// 籤一顆顆往後排，最後的輸入框吃掉那一行剩下的寬度；剩不到 [minInputWidth] 就換到下一行，
/// 照 `MailRecipientField._inputWidth`。同一行裡高度不同的子項垂直置中。
struct TokenFlowLayout: Layout {
  var spacing: CGFloat = 6
  var minInputWidth: CGFloat = 80

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let width = proposal.width ?? 320
    return CGSize(width: width, height: arrange(width: width, subviews: subviews).map(\.maxY).max() ?? 0)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    for (index, frame) in arrange(width: bounds.width, subviews: subviews).enumerated() {
      subviews[index].place(
        at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(frame.size))
    }
  }

  private func arrange(width: CGFloat, subviews: Subviews) -> [CGRect] {
    var frames: [CGRect] = []
    var line: [Int] = []
    var x: CGFloat = 0
    var y: CGFloat = 0
    var lineHeight: CGFloat = 0

    func closeLine() {
      for index in line {
        frames[index].origin.y = y + (lineHeight - frames[index].height) / 2
      }
      y += lineHeight + spacing
      x = 0
      lineHeight = 0
      line = []
    }

    for (index, view) in subviews.enumerated() {
      var size = view.sizeThatFits(.unspecified)
      let isInput = index == subviews.count - 1
      let fits = isInput ? width - x >= minInputWidth : x + min(size.width, width) <= width
      if x > 0, !fits { closeLine() }
      size.width = isInput ? width - x : min(size.width, width)
      frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
      line.append(index)
      x += size.width + spacing
      lineHeight = max(lineHeight, size.height)
    }
    if !line.isEmpty { closeLine() }
    return frames
  }
}
