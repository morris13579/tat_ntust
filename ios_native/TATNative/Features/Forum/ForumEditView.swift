import SwiftUI

/// 編輯自己的貼文，照 `CourseForumComposePage.edit` 與 `CourseForumRichEditPage`：排版或內嵌圖片撐不進
/// 純文字框時開所見即所得的編輯器。成功時帶著結果回討論串，失敗一律留在原地。
struct ForumEditView: View {
  @Environment(AppEnvironment.self) private var app
  @Environment(\.dismiss) private var dismiss
  @State private var model: ForumEditModel
  @State private var picking = false
  @State private var attachSource: AttachmentSource?
  @State private var confirmDiscard = false
  let onSaved: (ForumSendResult) -> Void

  init(model: ForumEditModel, onSaved: @escaping (ForumSendResult) -> Void) {
    _model = State(initialValue: model)
    self.onSaved = onSaved
  }

  var body: some View {
    Group {
      if model.isRich {
        richBody
      } else {
        plainBody
      }
    }
    .background(Color(.systemGroupedBackground))
    .pinnedBottomBar { saveBar }
    .navigationTitle(model.isRich ? L10n.forumEditRichTitle : L10n.forumEditPost)
    .navigationBarTitleDisplayMode(.inline)
    // 有草稿或送出中才換成自己的返回鍵攔下來；其他時候用系統的，右滑返回才有作用。
    .navigationBarBackButtonHidden(model.sending || model.hasDraft)
    .toolbar {
      if model.sending || model.hasDraft {
        BackButton { back() }
      }
    }
    .alert(L10n.forumDiscardDraft, isPresented: $confirmDiscard) {
      Button(L10n.cancel, role: .cancel) {}
      Button(L10n.sure, role: .destructive) { dismiss() }
    }
    .forumAttachmentPicker(
      source: $attachSource, remaining: max(0, Int(model.draft.attach.maxFiles) - model.total)
    ) { paths in
      Task { await model.addAttachments(paths, presenter: app.presenter) }
    }
    .task {
      if model.isRich && CoreAssets.url(Self.editorAsset) == nil { model.editorBroke() }
    }
  }

  private static let editorAsset = "assets/editor/editor.html"

  // MARK: - 純文字

  private var plainBody: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        IconSectionHeader(icon: Lucide.pencil, title: L10n.forumEditPost, first: true)
        SectionCard {
          if model.draft.isTopicPost {
            subjectField
            Divider()
          }
          ZStack(alignment: .topLeading) {
            if model.text.isEmpty {
              Text(L10n.forumMessageHint)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
                .padding(.leading, 5)
            }
            TextEditor(text: Binding(get: { model.text }, set: { model.text = $0 }))
              .frame(minHeight: 200)
              .scrollContentBackground(.hidden)
          }
        }
        attachmentSection
        // 一行說明，沒有鈕：這不是一個做得到的動作，只是一件事實。
        if let note = model.draft.note {
          Text(note)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 10)
            .padding(.horizontal, 4)
        }
      }
      .padding(EdgeInsets(top: 12, leading: 16, bottom: 16, trailing: 16))
      .allowsHitTesting(!model.sending)
    }
    .scrollDismissesKeyboard(.interactively)
  }

  /// 伺服器的 subject 是 varchar(255)，超過是寫入失敗，畫面上只會看到一句通用的送出失敗。
  private var subjectField: some View {
    TextField(
      L10n.forumSubjectHint,
      text: Binding(get: { model.subject }, set: { model.subject = String($0.prefix(255)) })
    )
    .font(.headline)
  }

  // MARK: - 所見即所得

  private var richBody: some View {
    VStack(spacing: 8) {
      if model.draft.isTopicPost {
        SectionCard { subjectField }
      }
      editorCard
      formatBar
      if model.total > 0 {
        SectionCard { attachmentRows }
          .frame(maxHeight: 160)
      }
    }
    .padding(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
    .allowsHitTesting(!model.sending)
  }

  @ViewBuilder private var editorCard: some View {
    ZStack {
      if model.editorFailed {
        InlineErrorView(message: L10n.forumEditorLoadFailed, signedIn: true, presenter: app.presenter) {
          model.retryEditor()
        }
      } else if let page = CoreAssets.url(Self.editorAsset), let script = model.draft.editorScript {
        RichEditorView(
          pageURL: page, contentScript: script, controller: model.editor,
          onReady: { model.editorLoaded() },
          onInput: { model.editorInput() },
          onState: { model.activeFormats = $0 },
          onFailed: { model.editorBroke() }
        )
        .id(model.editorGeneration)
        if !model.editorReady {
          VStack(spacing: 12) {
            ProgressView()
            Text(L10n.forumEditorLoading)
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color(.secondarySystemGroupedBackground))
        }
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
          model.editor.blur()
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

  /// 工具列的指令，照官方 App 的 rich-text-editor；沒有插入圖片，官方 App 也沒有。
  private static var commands: [(command: RichEditorController.Command, icon: LucideIcon, label: String)] {
    [
      (.bold, Lucide.bold, L10n.forumEditorBold),
      (.italic, Lucide.italic, L10n.forumEditorItalic),
      (.underline, Lucide.underline, L10n.forumEditorUnderline),
      (.strikeThrough, Lucide.strikethrough, L10n.forumEditorStrikethrough),
      (.paragraph, Lucide.pilcrow, L10n.forumEditorParagraph),
      (.heading3, Lucide.heading3, L10n.forumEditorHeading("3")),
      (.heading4, Lucide.heading4, L10n.forumEditorHeading("4")),
      (.heading5, Lucide.heading5, L10n.forumEditorHeading("5")),
      (.unorderedList, Lucide.list, L10n.forumEditorBulletList),
      (.orderedList, Lucide.listOrdered, L10n.forumEditorNumberedList),
      (.removeFormat, Lucide.removeFormatting, L10n.forumEditorClearFormat),
    ]
  }

  // MARK: - 附件

  @ViewBuilder private var attachmentSection: some View {
    if model.total > 0 {
      IconSectionHeader(icon: Lucide.paperclip, title: L10n.forumAttachments) {
        Text("\(model.total)/\(model.draft.attach.maxFiles)")
          .font(.footnote.monospacedDigit())
      }
      SectionCard {
        attachmentRows
        if model.draft.attach.enabled {
          Text(model.draft.attach.hint)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  @ViewBuilder private var attachmentRows: some View {
    ForEach(model.kept, id: \.self) { file in
      attachmentRow(name: file.name, icon: MoodleFileIcon.of(file.fileIcon)) {
        model.removeKept(file)
      } open: {
        Task {
          await MoodleFiles.open(
            MoodleFileLink(name: file.name, url: file.url), folder: model.course.name, presenter: app.presenter)
        }
      }
    }
    ForEach(model.added, id: \.self) { path in
      attachmentRow(name: (path as NSString).lastPathComponent, icon: Lucide.file) {
        model.removeAdded(path)
      } open: {}
    }
  }

  private func attachmentRow(
    name: String, icon: LucideIcon, remove: @escaping () -> Void, open: @escaping () -> Void
  ) -> some View {
    HStack(spacing: 11) {
      Button(action: open) {
        HStack(spacing: 11) {
          LucideImage(icon, size: 20)
            .foregroundStyle(Color.tatBrand)
          Text(name)
            .foregroundStyle(Color.primary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      Button(action: remove) {
        LucideImage(Lucide.x, size: 18)
          .foregroundStyle(.secondary)
          .frame(width: 36, height: 36)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(L10n.forumRemoveAttachment)
      .disabled(model.sending)
    }
  }

  // MARK: - 底列

  private var saveBar: some View {
    let progress = app.transfers.progress[model.transferKey]
    return VStack(alignment: .leading, spacing: 8) {
      if model.sending {
        HStack {
          Text(progress?.label ?? L10n.forumSending)
            .font(.footnote)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
          // 上傳可以取消（討論區上什麼都還沒動）；送出不行。
          if progress?.phase == .upload {
            Button(L10n.cancel) { Task { await model.cancelUpload() } }
              .font(.footnote.weight(.semibold))
          }
        }
        if let value = progress?.progress {
          ProgressView(value: value).tint(Color.tatBrand)
        } else {
          ProgressView().progressViewStyle(.linear).tint(Color.tatBrand)
        }
      } else if let reason = model.blockReason {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          LucideImage(Lucide.info, size: 14)
            .alignedToFirstTextLine(.footnote)
          Text(reason).font(.footnote)
        }
        .foregroundStyle(.secondary)
      }
      HStack {
        if model.draft.attach.enabled {
          Button {
            picking = true
          } label: {
            LucideImage(Lucide.paperclip, size: 20)
              .frame(width: 44, height: 44)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel(L10n.forumAddAttachment)
          .disabled(model.sending || model.total >= Int(model.draft.attach.maxFiles))
          .attachmentSourceDialog(isPresented: $picking) { attachSource = $0 }
        }
        Spacer()
        Button {
          Task { await save() }
        } label: {
          Label {
            Text(model.sending ? L10n.forumSending : L10n.forumSaveEdit)
          } icon: {
            LucideImage(Lucide.send, size: 18)
          }
        }
        .prominentButtonStyle()
        .controlSize(.large)
        .disabled(!model.canSave)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
  }

  private func save() async {
    guard let result = await model.save(transfers: app.transfers, presenter: app.presenter) else { return }
    onSaved(result)
    dismiss()
  }

  private func back() {
    // 送出中一律擋住：那一則已經在路上了。
    if model.sending {
      app.presenter.toast(L10n.forumSending)
    } else if model.hasDraft {
      confirmDiscard = true
    } else {
      dismiss()
    }
  }
}
