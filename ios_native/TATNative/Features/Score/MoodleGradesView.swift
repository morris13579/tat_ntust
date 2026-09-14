import SwiftUI

@MainActor
@Observable
final class MoodleGradesModel {
  private(set) var grades: MoodleGrades?
  let client: ScoreClient
  private var started = false

  init(client: ScoreClient) {
    self.client = client
  }

  /// 進頁時是背景載入：使用者只是點了一列，不該被丟一個登入頁。
  func start() async {
    guard !started else { return }
    started = true
    await load(refresh: false)
  }

  func refresh() async {
    await load(refresh: true)
  }

  private func load(refresh: Bool) async {
    let result = try? await client.moodleGrades(refresh: refresh)
    grades = result ?? MoodleGrades(courses: [], error: L10n.unknownError, signedIn: true)
  }
}

/// Moodle 目前成績，照 `moodle_course_grades_page.dart`。「這是即時總分、不是正式成績」排在任何數字之前。
struct MoodleGradesView: View {
  @Environment(AppEnvironment.self) private var app
  @State private var model: MoodleGradesModel

  init(model: MoodleGradesModel) {
    _model = State(initialValue: model)
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 10) {
        hint
        list
      }
      .padding(EdgeInsets(top: 8, leading: 16, bottom: 32, trailing: 16))
    }
    .background(Color(.systemGroupedBackground))
    .refreshable { await model.refresh() }
    .navigationTitle(L10n.moodleCourseGrades)
    .analyticsScreen("/MoodleCourseGradesPage")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        if let semester = model.grades?.semester {
          Text(semester)
            .font(.footnote.monospacedDigit())
            .foregroundStyle(.secondary)
        }
      }
    }
    .task { await model.start() }
  }

  private var hint: some View {
    HStack(alignment: .top, spacing: 8) {
      LucideImage(Lucide.info, size: 16)
        .padding(.top, 1)
      Text(L10n.moodleCourseGradesHint)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .font(.footnote)
    .foregroundStyle(.secondary)
    .padding(14)
    .background(
      Color(.secondarySystemGroupedBackground),
      in: ListGroupShape.card)
  }

  @ViewBuilder private var list: some View {
    if let grades = model.grades {
      if let notice = grades.notice {
        NoticeBar(message: notice, icon: Lucide.history, actionLabel: L10n.refresh) {
          Task { await model.refresh() }
        }
        .clipShape(ListGroupShape.card)
      }
      if let error = grades.error, grades.courses.isEmpty {
        InlineErrorView(message: error, signedIn: grades.signedIn, presenter: app.presenter) {
          await model.refresh()
        }
      } else if grades.courses.isEmpty {
        SectionEmptyState(message: L10n.moodleCourseGradesEmpty, icon: Lucide.graduationCap)
      } else {
        VStack(spacing: 2) {
          ForEach(Array(grades.courses.enumerated()), id: \.offset) { index, course in
            NavigationLink(value: ScoreRoute.course(course)) {
              row(course, index: index, count: grades.courses.count)
            }
            .buttonStyle(.plain)
          }
        }
      }
    } else {
      ProgressView().padding(.vertical, 40)
    }
  }

  private func row(_ course: MoodleGradeCourse, index: Int, count: Int) -> some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(course.name)
          .foregroundStyle(Color.primary)
          .lineLimit(2)
          .multilineTextAlignment(.leading)
        Text(course.courseId)
          .font(.subheadline.monospacedDigit())
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 8)
      // 伺服器格式化好的字串原樣顯示：它跟的是 Moodle 帳號語系，而且量尺與等第不是數字。
      Text(course.grade)
        .font(.body.weight(.semibold).monospacedDigit())
        .foregroundStyle(Color.primary)
      LucideImage(Lucide.chevronRight, size: 18)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 14)
    .background(
      Color(.secondarySystemGroupedBackground), in: GroupedRowShape(index: index, count: count))
    .contentShape(Rectangle())
  }
}
