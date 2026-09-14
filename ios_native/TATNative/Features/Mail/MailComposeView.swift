import SwiftUI

/// 寫信，照 `mail_compose_page.dart`：收件者是一顆顆的籤，副本收在「副本」鈕後面，編輯器就地嵌在這一頁。
/// 按下寄出只是排進寄件匣，頁面立刻關掉，底下那條提示活著的幾秒內收得回來。
struct MailComposeView: View {
  @Environment(AppEnvironment.self) private var app
  @Environment(\.dismiss) private var dismiss
  @State private var model: MailComposeModel
  @State private var picking = false
  @State private var attachSource: AttachmentSource?
  @State private var confirmDiscard = false
  @State private var headerHeight: CGFloat = 0
  @FocusState private var subjectFocused: Bool
  let onQueued: () -> Void

  init(model: MailComposeModel, onQueued: @escaping () -> Void) {
    _model = State(initialValue: model)
    self.onQueued = onQueued
  }

  private static let editorAsset = "assets/editor/editor.html"
  /// 編輯面的高度地板。收件欄展開副本之後自己捲，不再從編輯面身上扣。
  private static let editorMinHeight: CGFloat = 220

  var body: some View {
    NavigationStack {
      GeometryReader { proxy in
        VStack(spacing: 8) {
          ScrollView {
            VStack(spacing: 12) {
              headerCard
              if !model.attachments.isEmpty { attachmentCard }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
          }
          .scrollBounceBehavior(.basedOnSize)
          .frame(
            height: min(headerHeight, max(proxy.size.height - Self.editorMinHeight - 58, proxy.size.height * 0.28)))
          editorCard
          formatBar
        }
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle(L10n.mailCompose)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { toolbar }
      .forumAttachmentPicker(source: $attachSource, remaining: Int(model.start?.pickLimit ?? 1)) { paths in
        Task { await model.addAttachments(paths, presenter: app.presenter) }
      }
      .alert(L10n.mailDraftDiscard, isPresented: $confirmDiscard) {
        Button(L10n.mailKeepEditing, role: .cancel) {}
        Button(L10n.mailDiscard, role: .destructive) { dismiss() }
      } message: {
        Text(L10n.mailDraftDiscardBody)
      }
    }
    .interactiveDismissDisabled(model.hasDraft || model.sending)
    .task {
      await model.begin()
      if CoreAssets.url(Self.editorAsset) == nil { model.editorBroke() }
    }
    .analyticsScreen("/MailComposePage")
  }

  @ToolbarContentBuilder private var toolbar: some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
      Button {
        close()
      } label: {
        LucideImage(Lucide.x, size: 22)
      }
      .accessibilityLabel(L10n.cancel)
      .toolbarButtonTint()
    }
    ToolbarItem(placement: .topBarTrailing) {
      Button {
        picking = true
      } label: {
        LucideImage(Lucide.paperclip, size: 20)
      }
      .accessibilityLabel(L10n.mailAttach)
      .disabled(model.sending)
      .toolbarButtonTint()
      .attachmentSourceDialog(isPresented: $picking) { attachSource = $0 }
    }
    // 寄出是不可復原的動作，值得一顆有字的主鈕。
    ToolbarItem(placement: .topBarTrailing) {
      Button {
        Task { await send() }
      } label: {
        Label {
          Text(L10n.mailSend)
        } icon: {
          LucideImage(Lucide.send, size: 17)
        }
        .labelStyle(.titleAndIcon)
      }
      .prominentButtonStyle()
      .disabled(model.sending || !model.editorReady)
    }
  }

  // MARK: - 收件者與主旨

  private var headerCard: some View {
    VStack(spacing: 0) {
      recipientField(.to, label: L10n.mailTo) {
        if !model.showCopyFields {
          // 展開之後把焦點交給副本那一列：只展開不給焦點，按了像沒反應。
          Button(L10n.mailCc) {
            model.showCopyFields = true
            model.focus = .cc
          }
          .font(.subheadline)
          .buttonStyle(.borderless)
          .frame(minHeight: 36)
        }
      }
      if model.showCopyFields {
        Divider().padding(.leading, 14)
        recipientField(.cc, label: L10n.mailCc) { EmptyView() }
        Divider().padding(.leading, 14)
        recipientField(.bcc, label: L10n.mailBcc) { EmptyView() }
      }
      Divider().padding(.leading, 14)
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Text(L10n.mailSubject)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .frame(width: 68, alignment: .leading)
        TextField(text: $model.subject) { Text(L10n.mailSubject) }
          .focused($subjectFocused)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
    }
    .disabled(model.sending)
    .background(
      Color(.secondarySystemGroupedBackground), in: ListGroupShape.card)
  }

  private func recipientField<Trailing: View>(
    _ field: MailField, label: String, @ViewBuilder trailing: () -> Trailing
  ) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .top, spacing: 10) {
        Text(label)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .frame(width: 68, alignment: .leading)
          .padding(.top, 9)
        TokenFlowLayout {
          ForEach(Array(model.recipients(field).enumerated()), id: \.offset) { index, recipient in
            chip(recipient) { model.remove(at: index, from: field) }
          }
          RecipientInput(
            text: Binding(get: { model.text(field) }, set: { model.setText($0, for: field) }),
            focused: Binding(
              get: { model.focus == field },
              set: { focused in
                if focused {
                  model.focus = field
                } else if model.focus == field {
                  model.focus = nil
                }
              }),
            label: label,
            onReturn: { Task { await model.commit(field) } },
            onDeleteEmpty: { model.removeLast(from: field) },
            onEndEditing: { Task { await model.commit(field) } }
          )
        }
        trailing()
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 4)
      .contentShape(Rectangle())
      // 點空白處也要進得去，不用瞄準那一小截輸入框。
      .onTapGesture { model.focus = field }

      // 建議畫在欄位底下而不是浮在上面：浮層要自己跟著鍵盤與捲動算位置。
      if model.suggestField == field, !model.suggestions.isEmpty {
        ForEach(model.suggestions, id: \.email) { contact in
          Button {
            Task { await model.pick(contact, for: field) }
          } label: {
            HStack(spacing: 8) {
              LucideImage(Lucide.user, size: 16)
                .foregroundStyle(.secondary)
              Text(contact.label)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 92)
            .padding(.trailing, 14)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  /// 格式不對的那一顆當場變紅，不用等按了寄出才知道。
  private func chip(_ recipient: MailRecipient, remove: @escaping () -> Void) -> some View {
    HStack(spacing: 2) {
      Text(recipient.address)
        .font(.subheadline)
        .lineLimit(1)
      Button(action: remove) {
        LucideImage(Lucide.x, size: 14)
          .frame(width: 24, height: 24)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("\(L10n.remove) \(recipient.address)")
    }
    .foregroundStyle(recipient.valid ? Color.primary : Color(.systemRed))
    .padding(.leading, 10)
    .padding(.trailing, 3)
    .padding(.vertical, 3)
    .background(
      recipient.valid ? Color(.tertiarySystemFill) : Color(.systemRed).opacity(0.14),
      in: RoundedRectangle(cornerRadius: 8, style: .continuous))
  }

  private var attachmentCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(verbatim: "\(L10n.mailAttachments) \(model.attachments.count)")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.top, 10)
      ForEach(model.attachments, id: \.self) { path in
        HStack(spacing: 12) {
          LucideImage(Lucide.paperclip, size: 18)
            .foregroundStyle(.secondary)
          Text((path as NSString).lastPathComponent)
            .font(.subheadline)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
          Button {
            model.removeAttachment(path)
          } label: {
            LucideImage(Lucide.x, size: 18)
              .foregroundStyle(.secondary)
              .frame(width: 44, height: 44)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel(L10n.delete)
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
      }
    }
    .disabled(model.sending)
    .background(
      Color(.secondarySystemGroupedBackground), in: ListGroupShape.card)
  }

  // MARK: - 編輯器

  @ViewBuilder private var editorCard: some View {
    ZStack {
      if model.editorFailed {
        InlineErrorView(message: L10n.mailBodyLoadFailed, signedIn: true, presenter: app.presenter) {
          model.retryEditor()
        }
      } else if let page = CoreAssets.url(Self.editorAsset), let script = model.start?.editorScript {
        RichEditorView(
          pageURL: page, contentScript: script, controller: model.editor,
          onReady: { model.editorLoaded() },
          onInput: { model.editorInput() },
          onState: { model.activeFormats = $0 },
          onFailed: { model.editorBroke() }
        )
        .id(model.editorGeneration)
      }
      if !model.editorReady && !model.editorFailed {
        ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color(.secondarySystemGroupedBackground))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(ListGroupShape.card)
  }

  private var formatBar: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 2) {
        ForEach(Array(Self.commands.enumerated()), id: \.offset) { _, item in
          formatButton(
            icon: item.icon, label: item.label, active: model.activeFormats.contains(item.command.rawValue)
          ) {
            model.editor.exec(item.command)
          }
          .disabled(!model.editorReady || model.sourceMode || model.sending)
        }
        Divider().frame(height: 24)
        formatButton(icon: Lucide.code, label: L10n.forumEditorSource, active: model.sourceMode) {
          model.toggleSource()
        }
        .disabled(!model.editorReady || model.sending)
        formatButton(icon: Lucide.chevronDown, label: L10n.forumEditorHideKeyboard, active: false) {
          dismissKeyboard()
        }
      }
      .padding(.horizontal, 6)
    }
    .frame(height: 50)
    .background(
      Color(.secondarySystemGroupedBackground), in: ListGroupShape.card)
  }

  private func formatButton(icon: LucideIcon, label: String, active: Bool, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      LucideImage(icon, size: 18)
        .foregroundStyle(active ? Color.tatBrand : Color.primary)
        .frame(width: 40, height: 40)
        .background(
          active ? Color.tatBrand.opacity(0.14) : Color.clear,
          in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }

  /// 寫信不放標題層級，照 `MailComposePage.toolbarCommands`。
  private static var commands: [(command: RichEditorController.Command, icon: LucideIcon, label: String)] {
    [
      (.bold, Lucide.bold, L10n.forumEditorBold),
      (.italic, Lucide.italic, L10n.forumEditorItalic),
      (.underline, Lucide.underline, L10n.forumEditorUnderline),
      (.strikeThrough, Lucide.strikethrough, L10n.forumEditorStrikethrough),
      (.unorderedList, Lucide.list, L10n.forumEditorBulletList),
      (.orderedList, Lucide.listOrdered, L10n.forumEditorNumberedList),
      (.removeFormat, Lucide.removeFormatting, L10n.forumEditorClearFormat),
    ]
  }

  // MARK: - 動作

  /// 收鍵盤兩邊都要收：欄位的焦點在 SwiftUI 與 UIKit 這一側，編輯器的游標在 WebView 裡面。
  private func dismissKeyboard() {
    model.focus = nil
    subjectFocused = false
    model.editor.blur()
  }

  /// 有草稿才問，每次都跳一個對話框是噪音。
  private func close() {
    guard !model.sending else { return }
    if model.hasDraft {
      dismissKeyboard()
      confirmDiscard = true
    } else {
      dismiss()
    }
  }

  /// 「收回」要跟著使用者走：寄完就切去別的分頁時，寄件匣那一段根本不在畫面上。
  private func send() async {
    dismissKeyboard()
    guard let result = await model.send(presenter: app.presenter), let id = result.queuedId else { return }
    dismiss()
    onQueued()
    let client = model.client
    let presenter = app.presenter
    presenter.toast(
      L10n.mailSendingUndo, icon: Lucide.send,
      action: ToastAction(label: L10n.mailRecall) {
        Task {
          let ok = (try? await client.recall(id: id)) ?? false
          presenter.toast(ok ? L10n.mailRecalled : L10n.mailOutboxSending, kind: ok ? .success : .error)
        }
      },
      duration: .seconds(Int(result.holdSeconds)))
  }
}
