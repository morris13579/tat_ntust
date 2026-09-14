import SwiftUI

@MainActor
@Observable
final class QuizDetailModel {
  private(set) var result: QuizDetailResult?
  var web: WebPage?
  let client: QuizClient
  let moodle: CourseMoodleClient
  let course: CourseRef
  let quizId: Int64
  let name: String

  init(client: QuizClient, moodle: CourseMoodleClient, course: CourseRef, quizId: Int64, name: String) {
    self.client = client
    self.moodle = moodle
    self.course = course
    self.quizId = quizId
    self.name = name
  }

  func load(refresh: Bool) async {
    let fetched = try? await client.detail(courseId: course.courseId, quizId: quizId, refresh: refresh)
    result = fetched ?? QuizDetailResult(error: L10n.unknownError, signedIn: true)
  }

  func answerInWeb() async {
    guard let link = try? await client.answerLink(courseId: course.courseId, quizId: quizId),
      let url = URL(string: link.url)
    else { return }
    web = WebPage(
      title: result?.detail?.name ?? name, url: url, fallbackURL: link.fallbackUrl.flatMap(URL.init(string:)))
  }
}

/// 一個測驗的唯讀資訊，照 `course_quiz_detail_page.dart`；作答一律走「在網頁作答」。
struct QuizDetailView: View {
  @Environment(AppEnvironment.self) private var app
  @State private var model: QuizDetailModel

  init(model: QuizDetailModel) {
    _model = State(initialValue: model)
  }

  var body: some View {
    ScrollView {
      content
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 32, trailing: 16))
    }
    .background(Color(.systemGroupedBackground))
    .refreshable { await model.load(refresh: true) }
    .navigationTitle(model.result?.detail?.name ?? model.name)
    .analyticsScreen("/CourseQuizDetailPage")
    .navigationBarTitleDisplayMode(.inline)
    .moodleLinks(
      client: model.moodle, folder: model.course.name,
      web: Binding(get: { model.web }, set: { model.web = $0 }))
    .browserSheet(item: Binding(get: { model.web }, set: { model.web = $0 })) { url in
      (try? await model.moodle.isAutologinScript(url: url.absoluteString)) ?? false
    }
    .task {
      if model.result == nil { await model.load(refresh: false) }
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

  private func sections(_ detail: QuizDetail) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      if let notice = detail.notice {
        NoticeBar(message: notice, icon: Lucide.history, actionLabel: L10n.refresh) {
          Task { await model.load(refresh: true) }
        }
        .clipShape(ListGroupShape.card)
        .padding(.bottom, 4)
      }
      IconSectionHeader(icon: Lucide.calendarClock, title: L10n.quizSectionWindow, first: true)
      SectionCard {
        // 染紅只給「已關閉」；沒有時間限制是次要的字。
        Text(detail.windowHint)
          .font(.headline)
          .foregroundStyle(windowColor(detail.windowTone))
        if !detail.windowFields.isEmpty {
          Divider()
          fields(detail.windowFields)
        }
      }
      IconSectionHeader(icon: Lucide.timer, title: L10n.quizSectionRules) {
        if let label = detail.attemptsChipLabel, let tone = detail.attemptsChipTone {
          StatusPill(label: label, tone: tone.pill, stale: detail.attemptsChipStale)
        }
      }
      SectionCard { fields(detail.rules) }
      IconSectionHeader(icon: Lucide.award, title: L10n.quizSectionGrade)
      grade(detail)
      IconSectionHeader(icon: Lucide.listOrdered, title: L10n.quizSectionAttempts)
      attempts(detail)
      IconSectionHeader(icon: Lucide.fileText, title: L10n.quizIntro)
      SectionCard {
        if let intro = detail.introHtml {
          MoodleHTMLView(html: intro, client: model.moodle)
        } else {
          Text(L10n.nothingHere).foregroundStyle(.secondary)
        }
      }
      Button {
        Task { await model.answerInWeb() }
      } label: {
        Label { Text(L10n.quizAnswerInWeb) } icon: { LucideImage(Lucide.externalLink, size: 18) }
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .controlSize(.large)
      .padding(.top, 28)
    }
  }

  @ViewBuilder private func grade(_ detail: QuizDetail) -> some View {
    SectionCard {
      if let error = detail.gradeError {
        InlineErrorView(message: error, signedIn: model.result?.signedIn ?? true, presenter: app.presenter) {
          await model.load(refresh: true)
        }
      } else {
        // 沒有成績涵蓋「沒作答」與「老師關掉分數顯示」，伺服器沒有再細分的訊號。
        if let best = detail.bestGrade {
          VStack(alignment: .leading, spacing: 2) {
            Text(L10n.quizBestGrade)
              .font(.footnote)
              .foregroundStyle(.secondary)
            Text(best).font(.title2.weight(.semibold).monospacedDigit())
          }
        } else {
          Text(L10n.quizNoGrade).foregroundStyle(.secondary)
        }
        if let pass = detail.gradeToPass {
          LabeledValueRow(label: L10n.quizGradeToPass, value: pass)
        }
      }
    }
  }

  @ViewBuilder private func attempts(_ detail: QuizDetail) -> some View {
    if let error = detail.attemptsError {
      SectionCard {
        InlineErrorView(message: error, signedIn: model.result?.signedIn ?? true, presenter: app.presenter) {
          await model.load(refresh: true)
        }
      }
    } else if detail.attempts.isEmpty {
      SectionEmptyState(message: L10n.quizAttemptsEmpty, icon: Lucide.listOrdered)
    } else {
      SectionCard {
        ForEach(Array(detail.attempts.enumerated()), id: \.offset) { index, attempt in
          if index > 0 { Divider() }
          VStack(alignment: .leading, spacing: 6) {
            HStack {
              Text(attempt.title).font(.headline)
              Spacer()
              StatusPill(label: attempt.stateLabel, tone: attempt.tone.pill)
            }
            if let time = attempt.time {
              LabeledValueRow(label: time.label, value: time.value)
            }
          }
        }
      }
    }
  }

  private func windowColor(_ tone: QuizWindowTone) -> Color {
    switch tone {
    case .closed: Color(.systemRed)
    case .always: Color.secondary
    case .upcoming, .open: Color.primary
    }
  }

  private func fields(_ rows: [FieldRow]) -> some View {
    ForEach(Array(rows.enumerated()), id: \.offset) { _, field in
      LabeledValueRow(label: field.label, value: field.value)
    }
  }
}
