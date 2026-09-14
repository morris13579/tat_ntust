import SwiftUI
import UniformTypeIdentifiers

/// 交作業的編輯頁，照 `course_assign_submit_page.dart`：釘住的狀態表頭、會捲動的工作區、釘在底下的動作列。
/// 「移除繳交」與「沿用上一次」動的是伺服器上那一份，住在詳情頁，這一頁沒有。
struct AssignmentSubmitView: View {
  @Environment(AppEnvironment.self) private var app
  @Environment(\.dismiss) private var dismiss
  @State private var model: AssignmentSubmitModel
  @State private var picking = false
  @State private var confirmSave: String?
  @State private var confirmStart: String?
  @State private var confirmDiscard = false
  @State private var web: WebPage?
  @FocusState private var textFocused: Bool
  let onClose: (AssignWriteResult) -> Void

  init(model: AssignmentSubmitModel, onClose: @escaping (AssignWriteResult) -> Void) {
    _model = State(initialValue: model)
    self.onClose = onClose
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        if model.state.blocked {
          blocked
        } else {
          workArea
        }
      }
      .padding(EdgeInsets(top: 12, leading: 16, bottom: 16, trailing: 16))
      .allowsHitTesting(!model.busy)
    }
    .scrollDismissesKeyboard(.interactively)
    .background(Color(.systemGroupedBackground))
    .safeAreaInset(edge: .top, spacing: 0) { header }
    .pinnedBottomBar {
      if !model.state.blocked { actionBar }
    }
    .navigationTitle(model.state.name)
    .analyticsScreen("/CourseAssignSubmitPage")
    .navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden(true)
    .toolbar {
      BackButton(isEnabled: !model.busy) { back() }
    }
    .fileImporter(isPresented: $picking, allowedContentTypes: contentTypes, allowsMultipleSelection: true) {
      result in
      guard case .success(let urls) = result else {
        app.presenter.toast(L10n.assignFilePickerUnavailable, kind: .error)
        return
      }
      Task { await model.add(urls, presenter: app.presenter) }
    }
    .alert(
      model.state.savesDraft ? L10n.assignSaveDraft : L10n.assignSubmit,
      isPresented: Binding(get: { confirmSave != nil }, set: { if !$0 { confirmSave = nil } }),
      presenting: confirmSave
    ) { _ in
      Button(L10n.cancel, role: .cancel) {}
      Button(L10n.sure) { Task { await save() } }
    } message: { body in
      Text(body)
    }
    .alert(
      L10n.assignStartAttempt,
      isPresented: Binding(get: { confirmStart != nil }, set: { if !$0 { confirmStart = nil } }),
      presenting: confirmStart
    ) { _ in
      Button(L10n.cancel, role: .cancel) {}
      Button(L10n.sure) { Task { await model.start(presenter: app.presenter) } }
    } message: { body in
      Text(body)
    }
    .alert(L10n.assignDiscardChanges, isPresented: $confirmDiscard) {
      Button(L10n.cancel, role: .cancel) {}
      Button(L10n.sure, role: .destructive) { Task { await leave() } }
    }
    .moodleLinks(client: model.moodle, folder: model.course.name, web: $web)
    .browserSheet(item: $web) { url in
      (try? await model.moodle.isAutologinScript(url: url.absoluteString)) ?? false
    }
  }

  // MARK: - 表頭

  private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(model.state.dueHint)
          .font(.headline)
          .foregroundStyle(model.state.dueAlarm ? Color(.systemRed) : Color.primary)
          .frame(maxWidth: .infinity, alignment: .leading)
        StatusPill(label: model.state.chipLabel, tone: model.state.chipTone.pill)
      }
      if !textFocused {
        if let due = model.state.dueLine {
          Text(due)
            .font(.footnote.monospacedDigit())
            .foregroundStyle(.secondary)
        }
      }
      if let timer = model.state.timer {
        timerRow(timer)
      }
      // 鍵盤升起時只留最上面那幾行：這一條不捲動，全開時會把編輯區壓到零。
      if !textFocused {
        if let team = model.state.teamNotice {
          iconLine(Lucide.users, team)
        }
        if let attempt = model.state.attemptLine {
          Text(attempt)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        Text(model.state.consequence)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .padding(.top, 2)
      }
    }
    .padding(.horizontal, 16)
    .padding(.top, 10)
    .padding(.bottom, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.systemBackground))
    .overlay(alignment: .bottom) { Divider() }
  }

  @ViewBuilder private func timerRow(_ timer: AssignTimer) -> some View {
    if let endsAt = timer.endsAt {
      TimelineView(.periodic(from: .now, by: 1)) { context in
        let left = Int(endsAt) - (Int(context.date.timeIntervalSince1970) + Int(model.clockSkew))
        if left > 0 {
          // 最後五分鐘才染紅：更早就紅的話，紅色在這一頁上就不再是訊號。
          HStack(spacing: 6) {
            LucideImage(Lucide.timer, size: 16)
            Text(L10n.assignTimeLeft(Countdown.format(left)))
              .font(.subheadline.weight(.semibold).monospacedDigit())
          }
          .foregroundStyle(left < 300 ? Color(.systemRed) : Color.primary)
        } else {
          iconLine(Lucide.timer, L10n.assignTimeExpiredStillEditable, color: Color(.systemRed))
        }
      }
    } else if let note = timer.note {
      iconLine(Lucide.timer, note, color: timer.alert ? Color(.systemRed) : Color.secondary)
    }
  }

  private func iconLine(_ icon: LucideIcon, _ text: String, color: Color = .secondary) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      LucideImage(icon, size: 16)
        .alignedToFirstTextLine(.footnote)
      Text(text).font(.footnote)
    }
    .foregroundStyle(color)
  }

  // MARK: - 工作區

  private var blocked: some View {
    SectionCard {
      InlineNote(text: L10n.assignSubmitWebOnlyPlugin, blocking: true)
      openInWebButton(L10n.assignOpenInWeb)
    }
  }

  @ViewBuilder private var workArea: some View {
    if model.state.filesEnabled {
      IconSectionHeader(icon: Lucide.paperclip, title: L10n.assignAttachmentSection, first: true)
      files
    }
    if model.state.textEnabled {
      IconSectionHeader(icon: Lucide.fileText, title: L10n.assignOnlineText, first: !model.state.filesEnabled) {
        if !model.state.textEditable && model.state.textKept {
          StatusPill(label: L10n.assignOnlineTextKeepAsIs, tone: .pending)
        }
      }
      onlineText
    }
    if model.state.statementRequired {
      IconSectionHeader(icon: Lucide.shieldCheck, title: L10n.assignSubmissionStatement) {
        if model.state.statementAtSubmit {
          StatusPill(label: L10n.assignStatementAtSubmit, tone: .pending)
        }
      }
      statement
    }
  }

  private var files: some View {
    SectionCard {
      // 限制寫在按鈕身上：紙夾撞到上限時只會變灰，不說原因等於讓人卡在那裡。
      Button {
        picking = true
      } label: {
        HStack(spacing: 12) {
          LucideImage(Lucide.plus, size: 22)
          VStack(alignment: .leading, spacing: 2) {
            Text(L10n.assignAddFiles)
            Text(model.state.pickerHint)
              .font(.footnote)
              .foregroundStyle(.secondary)
              .lineLimit(2)
              .multilineTextAlignment(.leading)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(model.state.pickerFull ? Color.secondary : Color.tatBrand)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(model.state.pickerFull)
      if !model.state.files.isEmpty {
        Divider()
        ForEach(Array(model.state.files.enumerated()), id: \.offset) { index, file in
          fileRow(file, index: index)
        }
      }
      if let note = model.state.filesNote {
        InlineNote(text: note.text, blocking: note.blocking)
      }
    }
  }

  private func fileRow(_ file: SubmitFile, index: Int) -> some View {
    HStack(spacing: 11) {
      Button {
        guard let url = file.url else { return }
        Task {
          await MoodleFiles.open(
            MoodleFileLink(name: file.name, url: url), folder: model.course.name, presenter: app.presenter)
        }
      } label: {
        HStack(spacing: 11) {
          LucideImage(MoodleFileIcon.of(file.fileIcon), size: 20)
            .foregroundStyle(Color.tatBrand)
          VStack(alignment: .leading, spacing: 2) {
            // 刪除線與淡色一起上：只調淡的話跟「停用」長得一模一樣。
            Text(file.name)
              .strikethrough(file.removing)
              .foregroundStyle(file.removing ? Color.secondary : Color.primary)
              .lineLimit(2)
              .multilineTextAlignment(.leading)
            Text(file.subtitle)
              .font(.footnote.monospacedDigit())
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(file.url == nil)
      Button {
        Task { await model.toggleFile(index, presenter: app.presenter) }
      } label: {
        LucideImage(file.removing ? Lucide.undo2 : Lucide.x, size: 18)
          .foregroundStyle(.secondary)
          .frame(width: 36, height: 36)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(file.removing ? L10n.assignRestoreFile : L10n.assignRemoveFile)
    }
  }

  @ViewBuilder private var onlineText: some View {
    if !model.state.textEditable {
      // 純文字框改不動這一段，但它會被原樣送回去，所以檔案照樣可以增減。
      SectionCard {
        Text(model.state.textKept ? L10n.assignOnlineTextPreserved : L10n.assignOnlineTextReadOnly)
          .font(.subheadline)
          .foregroundStyle(.secondary)
        openInWebButton(L10n.assignEditOnlineTextInWeb)
      }
    } else {
      SectionCard {
        ZStack(alignment: .topLeading) {
          if model.text.isEmpty {
            Text(L10n.assignOnlineTextHint)
              .foregroundStyle(.tertiary)
              .padding(.top, 8)
              .padding(.leading, 5)
          }
          TextEditor(text: Binding(get: { model.text }, set: { model.text = $0 }))
            .focused($textFocused)
            .frame(minHeight: 140)
            .scrollContentBackground(.hidden)
            .onChange(of: model.text) {
              Task { await model.textChanged() }
            }
        }
        if let count = model.state.wordCount {
          Divider()
          Text(count)
            .font(.footnote.monospacedDigit())
            .foregroundStyle(model.state.overWordLimit ? Color(.systemRed) : Color.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
          if model.state.overWordLimit {
            InlineNote(text: L10n.assignWordCountExceeded, blocking: true)
          }
        }
      }
    }
  }

  private var statement: some View {
    SectionCard {
      if let html = model.state.statementHtml {
        MoodleHTMLView(html: html, client: model.moodle)
      }
      // 有草稿階段時真正的閘門是詳情頁的「送出評分」，這裡只負責讓它不意外。
      if !model.state.statementAtSubmit {
        Toggle(
          L10n.assignAcceptStatement,
          isOn: Binding(
            get: { model.state.accepted },
            set: { accepted in Task { await model.setAccepted(accepted, presenter: app.presenter) } })
        )
        .font(.subheadline)
      }
    }
  }

  private func openInWebButton(_ title: String) -> some View {
    Button {
      Task {
        guard let link = try? await model.client.webLink(assignId: model.assignId), let url = URL(string: link.url)
        else { return }
        web = WebPage(title: model.state.name, url: url, fallbackURL: link.fallbackUrl.flatMap(URL.init(string:)))
      }
    } label: {
      Label { Text(title) } icon: { LucideImage(Lucide.externalLink, size: 18) }
    }
    .buttonStyle(.bordered)
  }

  // MARK: - 動作列

  private var actionBar: some View {
    VStack(alignment: .leading, spacing: 8) {
      if model.saving {
        transferRow
      } else if model.state.needsStart {
        startRow
      } else {
        if let reason = model.state.blockReason {
          HStack(alignment: .firstTextBaseline, spacing: 6) {
            LucideImage(model.state.blockIsError ? Lucide.circleAlert : Lucide.info, size: 14)
              .alignedToFirstTextLine(.footnote)
            Text(reason).font(.footnote).lineLimit(2)
          }
          .foregroundStyle(model.state.blockIsError ? Color(.systemRed) : Color.secondary)
        }
        Button {
          Task { await requestSave() }
        } label: {
          Label {
            Text(model.state.savesDraft ? L10n.assignSaveDraft : L10n.assignSubmit)
          } icon: {
            LucideImage(model.state.savesDraft ? Lucide.filePen : Lucide.send, size: 18)
          }
          .frame(maxWidth: .infinity)
        }
        .prominentButtonStyle()
        .controlSize(.large)
        .disabled(!model.state.canSave)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
  }

  /// 動作列留在擋點擊的範圍外面：校園網路上傳一個大檔可能很久，至少要按得到取消。
  private var transferRow: some View {
    let progress = app.transfers.progress[model.transferKey]
    return VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(progress?.label ?? L10n.assignSubmit)
          .font(.footnote)
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)
        Button(L10n.cancel) { Task { await model.cancel() } }
          .font(.footnote.weight(.semibold))
      }
      // 量不出來時畫不定量的：只改線上文字時沒有東西可以量，停在 0% 的實心條看起來就是當掉了。
      if let value = progress?.progress {
        ProgressView(value: value).tint(Color.tatBrand)
      } else {
        ProgressView().progressViewStyle(.linear).tint(Color.tatBrand)
      }
    }
  }

  private var startRow: some View {
    VStack(alignment: .leading, spacing: 8) {
      if !model.state.startAvailable {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          LucideImage(Lucide.info, size: 14)
            .alignedToFirstTextLine(.footnote)
          Text(L10n.assignTimerNotAvailable).font(.footnote)
        }
        .foregroundStyle(.secondary)
      }
      Button {
        Task { confirmStart = await model.startConfirmation() }
      } label: {
        Label { Text(L10n.assignStartAttempt) } icon: { LucideImage(Lucide.play, size: 18) }
          .frame(maxWidth: .infinity)
      }
      .prominentButtonStyle()
      .controlSize(.large)
      .disabled(!model.state.canStart || model.starting)
      if !model.state.startAvailable {
        openInWebButton(L10n.assignOpenInWeb)
          .frame(maxWidth: .infinity)
      }
    }
  }

  private var contentTypes: [UTType] {
    let types = model.state.fileExtensions.compactMap { UTType(filenameExtension: $0) }
    return types.isEmpty ? [.item] : types
  }

  // MARK: - 流程

  private func requestSave() async {
    textFocused = false
    if let body = await model.saveConfirmation() {
      confirmSave = body
    } else {
      await save()
    }
  }

  private func save() async {
    guard let outcome = await model.save(transfers: app.transfers, presenter: app.presenter), outcome.close else {
      return
    }
    onClose(AssignWriteResult(messages: [], detail: outcome.detail))
    dismiss()
  }

  private func back() {
    guard !model.busy else { return }
    if model.state.hasUnsavedChanges {
      confirmDiscard = true
    } else {
      Task { await leave() }
    }
  }

  /// 放棄的是草稿，不是「開始作答」那一趟已經寫進伺服器的事實。
  private func leave() async {
    if let outcome = await model.close() { onClose(outcome) }
    dismiss()
  }
}
