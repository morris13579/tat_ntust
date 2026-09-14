import SwiftUI

@MainActor
@Observable
final class CourseScoreModel {
  private(set) var score: MoodleCourseScore?
  private(set) var expanded: Set<Int64> = []
  @ObservationIgnored private var loading = false
  let course: MoodleGradeCourse
  private let client: ScoreClient

  init(client: ScoreClient, course: MoodleGradeCourse) {
    self.client = client
    self.course = course
  }

  /// 課程 Moodle 頁進場時就開始抓，分頁畫出來時又會要一次：同一時間只跑一趟。
  func load() async {
    guard !loading else { return }
    loading = true
    defer { loading = false }
    let result = try? await client.courseScore(courseId: course.courseId)
    score = result ?? MoodleCourseScore(rows: [], error: L10n.unknownError, signedIn: true)
  }

  func toggle(_ row: MoodleGradeRow) {
    if expanded.contains(row.id) { expanded.remove(row.id) } else { expanded.insert(row.id) }
  }
}

/// 一門課在 Moodle 上的成績，照 `course_score_page.dart`：刻意攤平，課程總分粗體、類別總分半粗；
/// 有老師回饋的列點開看回饋，其餘的列不吃點擊。
struct CourseScoreView: View {
  @Environment(AppEnvironment.self) private var app
  @State private var model: CourseScoreModel
  @State private var web: WebPage?

  init(model: CourseScoreModel) {
    _model = State(initialValue: model)
  }

  var body: some View {
    CourseScoreContent(model: model)
      .moodleLinks(client: app.courseMoodle, folder: model.course.name, web: $web)
      .browserSheet(item: $web) { url in
        (try? await app.courseMoodle.isAutologinScript(url: url.absoluteString)) ?? false
      }
      .navigationTitle(model.course.name)
      .navigationBarTitleDisplayMode(.inline)
  }
}

/// 成績項目的清單本身。成績頁推進來的那一頁與課程 Moodle 的「成績」分頁共用。
struct CourseScoreContent: View {
  @Environment(AppEnvironment.self) private var app
  let model: CourseScoreModel

  var body: some View {
    ScrollView {
      content
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 32, trailing: 16))
    }
    .pageScrollInset()
    .background(Color(.systemGroupedBackground))
    .refreshable { await model.load() }
    .task {
      if model.score == nil { await model.load() }
    }
  }

  @ViewBuilder private var content: some View {
    if let score = model.score {
      if let notice = score.notice {
        NoticeBar(message: notice, icon: Lucide.history, actionLabel: L10n.refresh) {
          Task { await model.load() }
        }
        .clipShape(ListGroupShape.card)
        .padding(.bottom, 10)
      }
      if let error = score.error, score.rows.isEmpty {
        InlineErrorView(message: error, signedIn: score.signedIn, presenter: app.presenter) {
          await model.load()
        }
      } else {
        VStack(spacing: 2) {
          ForEach(Array(score.rows.enumerated()), id: \.element.id) { index, row in
            rowView(row, index: index, count: score.rows.count)
          }
        }
      }
    } else {
      ProgressView().padding(.vertical, 40)
    }
  }

  private func rowView(_ row: MoodleGradeRow, index: Int, count: Int) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text(row.title)
            .font(.body.weight(weight(row.kind)))
          if let meta = row.meta {
            Text(meta)
              .font(.subheadline.monospacedDigit())
              .foregroundStyle(.secondary)
          }
        }
        Spacer(minLength: 0)
        grade(row)
      }
      if model.expanded.contains(row.id), let feedback = row.feedback {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text(L10n.assignFeedback)
              .font(.footnote.weight(.semibold))
              .foregroundStyle(.secondary)
            Spacer()
            Button(L10n.collapse) { withAnimation { model.toggle(row) } }
              .font(.subheadline)
          }
          // 回饋可能夾著圖片（點開全螢幕看）與 pluginfile 的附件連結（點了下載）。
          MoodleHTMLView(html: feedback, client: app.courseMoodle)
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 13)
    .background(
      Color(.secondarySystemGroupedBackground), in: GroupedRowShape(index: index, count: count))
    .contentShape(Rectangle())
    .onTapGesture {
      guard row.feedback != nil else { return }
      withAnimation { model.toggle(row) }
    }
  }

  /// 沒有分數時印「尚未評分」而不是留白：留白看起來像畫面壞了。
  @ViewBuilder private func grade(_ row: MoodleGradeRow) -> some View {
    if let grade = row.grade {
      Text(grade)
        .font(.title3.weight(.semibold).monospacedDigit())
    } else {
      Text(L10n.assignNotGraded)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
  }

  private func weight(_ kind: GradeRowKind) -> Font.Weight {
    switch kind {
    case .course: .bold
    case .category: .semibold
    case .item: .medium
    }
  }
}
