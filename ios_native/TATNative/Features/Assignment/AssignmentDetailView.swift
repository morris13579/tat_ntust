import SwiftUI

/// 一份作業的詳情，照 `course_assignment_detail_page.dart`：截止、繳交狀態、成績與回饋、次數、團隊、
/// 作答時限、說明，最後是繳交入口。會動到伺服器上那一份的「沿用」「移除」放在右上角的選單裡。
struct AssignmentDetailView: View {
  @Environment(AppEnvironment.self) private var app
  @State private var model: AssignmentDetailModel
  @State private var confirm: Confirm?
  @State private var gradingSheet = false
  @State private var statementAccepted = false

  private enum Confirm: Identifiable {
    case copy, remove
    var id: Self { self }
  }

  init(model: AssignmentDetailModel) {
    _model = State(initialValue: model)
  }

  var body: some View {
    ScrollView {
      content
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 32, trailing: 16))
    }
    .background(Color(.systemGroupedBackground))
    .refreshable { await model.load(refresh: true) }
    .navigationTitle(model.detail?.name ?? model.name)
    .analyticsScreen("/CourseAssignmentDetailPage")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar { toolbar }
    .moodleLinks(
      client: model.moodle, folder: model.course.name,
      web: Binding(get: { model.web }, set: { model.web = $0 }))
    .browserSheet(item: Binding(get: { model.web }, set: { model.web = $0 })) { url in
      (try? await model.moodle.isAutologinScript(url: url.absoluteString)) ?? false
    }
    .navigationDestination(
      isPresented: Binding(get: { model.submit != nil }, set: { if !$0 { model.submit = nil } })
    ) {
      if let submit = model.submit {
        AssignmentSubmitView(model: submit) { outcome in
          model.apply(outcome, presenter: app.presenter)
        }
      }
    }
    .alert(
      confirm == .copy ? L10n.assignCopyPrevious : L10n.assignRemoveSubmission,
      isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }),
      presenting: confirm
    ) { action in
      Button(L10n.cancel, role: .cancel) {}
      Button(L10n.sure, role: action == .remove ? .destructive : nil) {
        Task {
          switch action {
          case .copy: await model.copyPrevious(presenter: app.presenter)
          case .remove: await model.removeSubmission(presenter: app.presenter)
          }
        }
      }
    } message: { action in
      Text(action == .copy ? model.detail?.copyConfirm ?? "" : model.detail?.removeConfirm ?? "")
    }
    .sheet(isPresented: $gradingSheet) { gradingConfirmation }
    .task {
      if model.result == nil { await model.load(refresh: false) }
    }
  }

  @ToolbarContentBuilder private var toolbar: some ToolbarContent {
    ToolbarItemGroup(placement: .topBarTrailing) {
      if model.writing {
        ProgressView()
      }
      // 導網頁是最後手段，不是常見任務的答案，所以在這裡而不是頁面底部的一顆大鈕。
      Button {
        Task { await model.openInWeb() }
      } label: {
        LucideImage(Lucide.externalLink, size: 18)
      }
      .accessibilityLabel(L10n.assignOpenInWeb)
      .disabled(model.detail == nil)
      .toolbarButtonTint()
      if let detail = model.detail, detail.canCopyPrevious || detail.canRemove {
        Menu {
          if detail.canCopyPrevious {
            Button {
              confirm = .copy
            } label: {
              Label { Text(L10n.assignCopyPrevious) } icon: { Image(uiImage: Lucide.copy.uiImage()) }
            }
          }
          if detail.canRemove {
            Button(role: .destructive) {
              confirm = .remove
            } label: {
              Label { Text(L10n.assignRemoveSubmission) } icon: { Image(uiImage: Lucide.trash2.destructiveUIImage()) }
            }
          }
        } label: {
          LucideImage(Lucide.ellipsis, size: 20)
        }
        .disabled(model.writing)
        .toolbarButtonTint()
      }
    }
  }

  @ViewBuilder private var content: some View {
    if let result = model.result {
      if let detail = result.detail {
        sections(detail)
      } else {
        InlineErrorView(
          message: result.error ?? L10n.unknownError, signedIn: result.signedIn, presenter: app.presenter
        ) {
          await model.load(refresh: true)
        }
      }
    } else {
      ProgressView()
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
  }

  @ViewBuilder private func sections(_ detail: AssignmentDetail) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      if let notice = detail.notice {
        NoticeBar(message: notice, icon: Lucide.history, actionLabel: L10n.refresh) {
          Task { await model.load(refresh: true) }
        }
        .clipShape(ListGroupShape.card)
        .padding(.bottom, 4)
      }
      IconSectionHeader(icon: Lucide.calendarClock, title: L10n.assignDueDate, first: true)
      deadline(detail)
      IconSectionHeader(icon: Lucide.clipboardCheck, title: L10n.assignSubmissionStatus) {
        if let label = detail.chipLabel, let tone = detail.chipTone {
          StatusPill(label: label, tone: tone.pill, stale: detail.chipStale)
        }
      }
      status(detail)
      if let feedback = detail.feedback {
        IconSectionHeader(icon: Lucide.fileCheck2, title: L10n.assignSectionGradeFeedback)
        feedbackCard(feedback)
      }
      if !detail.attempts.isEmpty {
        IconSectionHeader(icon: Lucide.history, title: L10n.assignPreviousAttempts)
        SectionCard {
          ForEach(Array(detail.attempts.enumerated()), id: \.offset) { index, field in
            if index == 1 { Divider() }
            LabeledValueRow(label: field.label, value: field.value)
          }
        }
      }
      if !detail.teamNotes.isEmpty {
        IconSectionHeader(icon: Lucide.users, title: L10n.assignTeamSubmission)
        SectionCard {
          ForEach(Array(detail.teamNotes.enumerated()), id: \.offset) { _, note in
            InlineNote(text: note.text, blocking: note.blocking)
          }
          if detail.teamOpenInWeb {
            Button {
              Task { await model.openInWeb() }
            } label: {
              Label { Text(L10n.assignOpenInWeb) } icon: { LucideImage(Lucide.externalLink, size: 18) }
            }
            .buttonStyle(.bordered)
          }
        }
      }
      if let timer = detail.timer {
        IconSectionHeader(icon: Lucide.timer, title: L10n.assignTimeLimit)
        timerCard(timer, skew: detail.clockSkewSeconds)
      }
      IconSectionHeader(icon: Lucide.fileText, title: L10n.assignIntro)
      intro(detail)
      submit(detail)
        .padding(.top, 28)
    }
  }

  private func deadline(_ detail: AssignmentDetail) -> some View {
    SectionCard {
      VStack(alignment: .leading, spacing: 4) {
        // 提示跟著生效的截止時間走，有延長期限時說「已逾期」是錯的。
        Text(detail.dueHint)
          .font(.headline)
          .foregroundStyle(
            detail.dueAlarm ? Color(.systemRed) : (detail.dueDate == nil ? Color.secondary : Color.primary))
        if let date = detail.dueDate {
          Text(date)
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
        }
      }
      if !detail.deadlineFields.isEmpty {
        Divider()
        fields(detail.deadlineFields)
      }
    }
  }

  @ViewBuilder private func status(_ detail: AssignmentDetail) -> some View {
    if let error = detail.statusError {
      SectionCard {
        InlineErrorView(message: error, signedIn: model.result?.signedIn ?? true, presenter: app.presenter) {
          await model.load(refresh: true)
        }
      }
    } else if detail.statusFields.isEmpty {
      SectionCard {
        ProgressView().frame(maxWidth: .infinity)
      }
    } else {
      SectionCard {
        fields(detail.statusFields)
        if !detail.submittedFiles.isEmpty {
          Divider()
          SectionSubLabel(text: L10n.assignSubmittedFiles)
          MoodleFileList(files: detail.submittedFiles, folder: model.course.name)
        }
        if let html = detail.onlineTextHtml {
          Divider()
          SectionSubLabel(text: L10n.assignOnlineText)
          MoodleHTMLView(html: html, client: model.moodle)
        }
        ForEach(Array(detail.statusNotes.enumerated()), id: \.offset) { _, note in
          InlineNote(text: note.text, blocking: note.blocking)
        }
      }
    }
  }

  private func feedbackCard(_ feedback: AssignFeedback) -> some View {
    SectionCard {
      if let grade = feedback.grade {
        VStack(alignment: .leading, spacing: 2) {
          Text(L10n.assignGrade)
            .font(.footnote)
            .foregroundStyle(.secondary)
          Text(grade)
            .font(.title2.weight(.semibold).monospacedDigit())
        }
      }
      if let gradedAt = feedback.gradedAt {
        LabeledValueRow(label: L10n.assignGradedAt, value: gradedAt)
      }
      if let comments = feedback.commentsHtml {
        Divider()
        SectionSubLabel(text: L10n.assignFeedback)
        MoodleHTMLView(html: comments, client: model.moodle)
      }
      if !feedback.files.isEmpty {
        Divider()
        SectionSubLabel(text: L10n.assignFeedbackFiles)
        MoodleFileList(files: feedback.files, folder: model.course.name)
      }
    }
  }

  private func timerCard(_ timer: AssignTimer, skew: Int64) -> some View {
    SectionCard {
      LabeledValueRow(label: L10n.assignTimeLimit, value: timer.limit)
      if let endsAt = timer.endsAt {
        // 值就是那個數字：標籤已經說了是「剩餘時間」。
        TimelineView(.periodic(from: .now, by: 1)) { context in
          let left = Int(endsAt) - (Int(context.date.timeIntervalSince1970) + Int(skew))
          if left > 0 {
            LabeledValueRow(label: L10n.assignTimeRemaining, value: Countdown.format(left))
          } else {
            InlineNote(text: L10n.assignTimeExpiredStillEditable)
          }
        }
      }
      if let note = timer.note {
        InlineNote(text: note, blocking: timer.alert)
      }
    }
  }

  private func intro(_ detail: AssignmentDetail) -> some View {
    SectionCard {
      if let html = detail.introHtml {
        MoodleHTMLView(html: html, client: model.moodle)
      } else if let placeholder = detail.introPlaceholder {
        Text(placeholder)
          .italic(detail.introHidden)
          .foregroundStyle(.secondary)
      }
      if !detail.introFiles.isEmpty {
        Divider()
        SectionSubLabel(text: L10n.assignAttachments)
        MoodleFileList(files: detail.introFiles, folder: model.course.name)
      }
    }
  }

  @ViewBuilder private func submit(_ detail: AssignmentDetail) -> some View {
    VStack(spacing: 10) {
      if detail.needsFresh {
        // `Stale` 一定伴隨舊資料的橫幅，重新整理的入口在那上面，這裡只講一句。
        Text(L10n.assignSubmitNeedsFresh)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity)
      }
      if let entry = detail.entryLabel {
        Button {
          Task { await model.openSubmit() }
        } label: {
          Label { Text(entry) } icon: { LucideImage(Lucide.filePen, size: 18) }
            .frame(maxWidth: .infinity)
        }
        .prominentButtonStyle()
        .controlSize(.large)
        if detail.canSubmitForGrading {
          Button {
            statementAccepted = false
            gradingSheet = true
          } label: {
            Label { Text(L10n.assignSubmitForGrading) } icon: { LucideImage(Lucide.send, size: 18) }
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
          .controlSize(.large)
          .disabled(model.writing)
        }
      }
      ForEach(Array(detail.submitNotes.enumerated()), id: \.offset) { _, note in
        InlineNote(text: note.text, blocking: note.blocking)
      }
    }
  }

  /// 送出評分之後就不能再改。要同意聲明時伺服器是真的會擋的，但不說原因，所以先要求勾選。
  private var gradingConfirmation: some View {
    SheetStack(title: L10n.assignSubmitForGrading, closeLabel: L10n.cancel) {
      List {
        Section {
          Text(L10n.assignSubmitForGradingConfirm)
        }
        if let statement = model.detail?.statementHtml {
          Section {
            MoodleHTMLView(html: statement, client: model.moodle)
            Toggle(L10n.assignAcceptStatement, isOn: $statementAccepted)
          }
        }
      }
      .bottomAction(L10n.sure, isEnabled: model.detail?.statementHtml == nil || statementAccepted) {
        gradingSheet = false
        let accepted = statementAccepted
        Task { await model.submitForGrading(acceptStatement: accepted, presenter: app.presenter) }
      }
    }
  }

  private func fields(_ rows: [FieldRow]) -> some View {
    ForEach(Array(rows.enumerated()), id: \.offset) { _, field in
      LabeledValueRow(label: field.label, value: field.value)
    }
  }
}
