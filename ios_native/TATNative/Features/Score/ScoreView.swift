import SwiftUI

enum ScoreRoute: Hashable {
  case moodleGrades
  case course(MoodleGradeCourse)
}

/// 成績查詢，照 `score_page.dart`：學期分頁、摘要、每一門課的成績。
/// Moodle 目前成績暫時不放入口，頁面留著（`ScoreRoute`）。
struct ScoreView: View {
  @Environment(AppEnvironment.self) private var app
  @State private var model: ScoreModel

  init(model: ScoreModel) {
    _model = State(initialValue: model)
  }

  var body: some View {
    NavigationStack {
      content
        .background(Color(.systemGroupedBackground))
        .navigationTitle(L10n.searchScore)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button {
              Task { await model.refresh() }
            } label: {
              LucideImage(Lucide.refreshCw, size: 20)
            }
            .accessibilityLabel(L10n.update)
            .disabled(model.isBusy)
            .toolbarButtonTint()
          }
        }
        .navigationDestination(for: ScoreRoute.self) { route in
          switch route {
          case .moodleGrades:
            MoodleGradesView(model: MoodleGradesModel(client: model.client))
          case .course(let course):
            CourseScoreView(model: CourseScoreModel(client: model.client, course: course))
          }
        }
    }
    .task { await model.start() }
  }

  @ViewBuilder private var content: some View {
    switch model.phase {
    case .loading:
      ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
    case .notSignedIn:
      ContentUnavailableView {
        Label {
          Text(L10n.pleaseLogin)
        } icon: {
          LucideImage(Lucide.logIn, size: 44)
        }
      } actions: {
        Button(L10n.login) {
          app.presenter.requestLogin { Task { await model.refresh() } }
        }
        .prominentButtonStyle()
      }
    case .failed:
      ContentUnavailableView {
        Label {
          Text(L10n.getScoreError)
        } icon: {
          LucideImage(Lucide.triangleAlert, size: 44)
        }
      } actions: {
        Button(L10n.restart) { Task { await model.refresh() } }
          .prominentButtonStyle()
          .disabled(model.isBusy)
      }
    case .loaded:
      TabView(selection: $model.selection) {
        ForEach(model.semesters, id: \.semester) { semester in
          SemesterScoreList(semester: semester)
            .id("\(semester.semester)-\(model.loadCount)")
            .tag(Optional(semester.semester))
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .extendsUnderBars()
      // 學期籤不墊底色，成績捲到後面時由系統淡出。
      .pinnedTopBar { semesterTabs }
    }
  }

  /// 學期多的時候要能橫向捲，選到的那一個捲到中間。
  private var semesterTabs: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal) {
        HStack(spacing: 6) {
          ForEach(model.semesters, id: \.semester) { semester in
            let isOn = model.selection == semester.semester
            Button {
              withAnimation(.easeOut(duration: 0.2)) { model.selection = semester.semester }
            } label: {
              Text(semester.semester)
                .font(.subheadline.weight(.medium).monospacedDigit())
                .foregroundStyle(isOn ? Color.tatBrand : Color.secondary)
                .padding(.horizontal, 14)
                .frame(minHeight: 34)
                .background(isOn ? Color.tatBrand.opacity(0.14) : Color.clear, in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .id(semester.semester)
            .accessibilityAddTraits(isOn ? .isSelected : [])
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
      }
      .scrollIndicators(.hidden)
      .onChange(of: model.selection) { _, selection in
        withAnimation { proxy.scrollTo(selection, anchor: .center) }
      }
    }
  }
}

private struct SemesterScoreList: View {
  let semester: ScoreSemester
  @State private var appeared = false

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        ScoreSummaryCard(semester: semester)
          .staggeredAppear(0, appeared, .slide)
        SectionHeader(title: L10n.courseCount(String(semester.courses.count)))
          .staggeredAppear(1, appeared, .slide)
        VStack(spacing: 2) {
          ForEach(Array(semester.courses.enumerated()), id: \.offset) { index, course in
            ScoreRow(course: course, index: index, count: semester.courses.count)
              .staggeredAppear(index + 2, appeared, .slide)
          }
        }
      }
      .padding(EdgeInsets(top: 12, leading: 16, bottom: 32, trailing: 16))
    }
    .pageScrollInset()
    .task { appeared = true }
  }
}

/// GPA、學分、不及格門數三格。數字都是等寬數字，切學期時位數不會左右跳。
private struct ScoreSummaryCard: View {
  let semester: ScoreSemester

  var body: some View {
    HStack(spacing: 0) {
      // 沒有值時放破折號而不是 0：0.00 會被讀成「這學期 GPA 是零」。
      cell(L10n.gpaLabel, semester.gpa ?? "—")
      separator
      cell(L10n.credit, String(semester.credits))
      separator
      cell(L10n.scoreFailed, String(semester.failed), highlight: semester.failed > 0)
    }
    .padding(16)
    .background(
      Color(.secondarySystemGroupedBackground),
      in: ListGroupShape.card)
  }

  private var separator: some View {
    Rectangle()
      .fill(Color(.separator))
      .frame(width: 1, height: 36)
      .padding(.horizontal, 14)
  }

  private func cell(_ label: String, _ value: String, highlight: Bool = false) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(label)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .lineLimit(1)
      Text(value)
        .font(.title2.weight(.bold).monospacedDigit())
        .foregroundStyle(highlight ? Color(.systemRed) : Color.primary)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// 成績清單的一列：課名、課號／學分／向度，分數靠右。不及格靠底色、標籤與紅字三種方式表達。
private struct ScoreRow: View {
  let course: ScoreCourse
  let index: Int
  let count: Int

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(course.name)
          .foregroundStyle(Color.primary)
          .lineLimit(2)
          .multilineTextAlignment(.leading)
        HStack(spacing: 8) {
          Text(subtitle)
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
            .lineLimit(1)
          if course.failed {
            Text(L10n.scoreFailed)
              .font(.caption.weight(.semibold))
              .foregroundStyle(Color.white)
              .padding(.horizontal, 6)
              .padding(.vertical, 1)
              .background(Color(.systemRed), in: Capsule())
          }
        }
      }
      Spacer(minLength: 0)
      Text(course.label)
        .font(.title3.weight(.medium).monospacedDigit())
        .foregroundStyle(course.failed ? Color(.systemRed) : Color.primary)
        .multilineTextAlignment(.trailing)
        .lineLimit(2)
        .frame(maxWidth: 96, alignment: .trailing)
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 14)
    .background(
      course.failed ? Color(.systemRed).opacity(0.12) : Color(.secondarySystemGroupedBackground),
      in: GroupedRowShape(index: index, count: count))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      [course.name, subtitle, course.label, course.failed ? L10n.scoreFailed : nil]
        .compactMap { $0 }
        .joined(separator: "，"))
  }

  /// 「CS3039701 · 3 學分 · 向度 B」。
  private var subtitle: String {
    [
      course.courseId,
      L10n.creditCount(String(course.credits)),
      course.dimension.map { "\(L10n.general_dimension) \($0)" },
    ]
    .compactMap { $0 }
    .joined(separator: " · ")
  }
}
