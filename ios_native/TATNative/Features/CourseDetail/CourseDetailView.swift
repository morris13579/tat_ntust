import SwiftUI
import UIKit

/// 一門課的詳細資訊，照 `course_info_page.dart`：標題與標籤、短欄位表格、修課學生、課程宗旨、
/// 評量方式，其餘長欄位收起來、點開才看。
struct CourseDetailView: View {
  @Environment(AppEnvironment.self) private var app
  @State private var model: CourseDetailModel
  @State private var expanded: Set<Int> = []

  init(model: CourseDetailModel) {
    _model = State(initialValue: model)
  }

  var body: some View {
    ScrollView {
      content
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 32, trailing: 16))
    }
    .background(Color(.systemGroupedBackground))
    .refreshable { await model.load() }
    .navigationTitle(model.course.name)
    .analyticsScreen("/CourseDetailPage")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      if model.result == nil { await model.load() }
    }
  }

  @ViewBuilder private var content: some View {
    if let result = model.result {
      VStack(alignment: .leading, spacing: 0) {
        if let notice = result.notice {
          NoticeBar(message: notice, icon: Lucide.history, actionLabel: L10n.refresh) {
            Task { await model.load() }
          }
          .clipShape(ListGroupShape.card)
          .padding(.bottom, 12)
        }
        if let info = result.info {
          details(info)
        } else {
          InlineErrorView(
            message: result.error ?? L10n.unknownError, signedIn: true, presenter: app.presenter
          ) {
            await model.load()
          }
        }
      }
    } else {
      ProgressView()
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
  }

  private func details(_ info: CourseDetailInfo) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      header(info)
      if !info.facts.isEmpty {
        facts(info.facts).padding(.top, 20)
      }
      // 人數是主要 API 就給的，這一列立刻畫得出來；名單那支慢的查詢等真的點進去才打。
      if let count = info.memberCount {
        membersRow(count).padding(.top, 20)
      }
      if let objective = info.objective {
        section(objective.title) { prose(objective.body) }
      }
      if let grading = info.grading {
        section(L10n.courseGrading) { gradingRows(grading) }
      } else if let text = info.gradingText {
        section(L10n.courseGrading) { prose(text) }
      }
      if !info.more.isEmpty || info.courseUrl != nil {
        section(L10n.otherFields) { moreRows(info) }
      }
    }
  }

  private func header(_ info: CourseDetailInfo) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      if !info.name.isEmpty {
        Text(info.name).font(.title2.weight(.semibold))
      }
      if let subtitle = info.subtitle {
        Text(subtitle)
          .font(.subheadline.monospacedDigit())
          .foregroundStyle(.secondary)
          .padding(.top, 4)
      }
      if !info.chips.isEmpty {
        FlowLayout {
          ForEach(info.chips, id: \.self) { chip in
            Text(chip)
              .font(.footnote.weight(.medium))
              .foregroundStyle(.secondary)
              .padding(.horizontal, 10)
              .padding(.vertical, 4)
              .background(Color(.tertiarySystemFill), in: Capsule())
          }
        }
        .padding(.top, 12)
      }
    }
  }

  private func facts(_ facts: [CourseInfoFact]) -> some View {
    VStack(spacing: 2) {
      ForEach(Array(facts.enumerated()), id: \.offset) { index, fact in
        HStack(alignment: .firstTextBaseline, spacing: 14) {
          Text(fact.label)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(width: 96, alignment: .leading)
          VStack(alignment: .leading, spacing: 2) {
            Text(fact.value)
            if let footnote = fact.footnote {
              Text(footnote)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(
          Color(.secondarySystemGroupedBackground),
          in: GroupedRowShape(index: index, count: facts.count))
      }
    }
  }

  private func membersRow(_ count: String) -> some View {
    NavigationLink {
      CourseMembersView(
        model: CourseMembersModel(
          client: model.client, course: model.course, knownCount: Int(count) ?? 0))
    } label: {
      HStack(spacing: 12) {
        Text(L10n.enrolledStudents)
          .foregroundStyle(Color.primary)
        Spacer(minLength: 8)
        Text(L10n.peopleCount(count))
          .font(.subheadline.monospacedDigit())
          .foregroundStyle(.secondary)
        LucideImage(Lucide.chevronRight, size: 18)
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 15)
      .background(
        Color(.secondarySystemGroupedBackground),
        in: ListGroupShape.card)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  /// 標題在卡片外、內容在卡片裡。
  private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      SectionHeader(title: title)
      content()
    }
  }

  /// 長文加一顆明確的複製鈕：整張卡點一下就複製，沒有人看得出來那件事會發生。
  private func prose(_ body: String) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(body)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
      Divider().padding(.top, 11)
      copyButton(body)
    }
    .padding(.horizontal, 14)
    .padding(.top, 14)
    .background(
      Color(.secondarySystemGroupedBackground),
      in: ListGroupShape.card)
  }

  private func copyButton(_ text: String) -> some View {
    Button {
      UIPasteboard.general.string = text
      app.presenter.toast(L10n.copy, kind: .success)
    } label: {
      HStack(spacing: 8) {
        LucideImage(Lucide.copy, size: 16)
        Text(L10n.copyAction)
      }
      .font(.subheadline.weight(.medium))
      .foregroundStyle(Color.tatBrand)
      // 跟清單的一列一樣高，整列都點得到。
      .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private func gradingRows(_ rows: [CourseGradingRow]) -> some View {
    VStack(spacing: 2) {
      ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
        HStack(spacing: 12) {
          Text(row.label)
          Spacer(minLength: 8)
          Text(row.percent).font(.body.weight(.medium).monospacedDigit())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
          Color(.secondarySystemGroupedBackground),
          in: GroupedRowShape(index: index, count: rows.count))
      }
    }
  }

  private func moreRows(_ info: CourseDetailInfo) -> some View {
    let total = info.more.count + (info.courseUrl == nil ? 0 : 1)
    return VStack(spacing: 2) {
      ForEach(Array(info.more.enumerated()), id: \.offset) { index, field in
        VStack(alignment: .leading, spacing: 0) {
          Button {
            withAnimation(.easeOut(duration: 0.16)) {
              if expanded.contains(index) { expanded.remove(index) } else { expanded.insert(index) }
            }
          } label: {
            HStack(spacing: 12) {
              Text(field.title).foregroundStyle(Color.primary)
              Spacer(minLength: 8)
              LucideImage(Lucide.chevronDown, size: 18)
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(expanded.contains(index) ? 180 : 0))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          if expanded.contains(index) {
            VStack(alignment: .leading, spacing: 0) {
              Text(field.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
              Divider().padding(.top, 11)
              copyButton(field.body)
            }
            .padding(.horizontal, 14)
          }
        }
        .background(
          Color(.secondarySystemGroupedBackground), in: GroupedRowShape(index: index, count: total))
      }
      if let link = info.courseUrl {
        Button {
          if let url = URL(string: link) { UIApplication.shared.open(url) }
        } label: {
          HStack(spacing: 12) {
            Text(L10n.courseURL).foregroundStyle(Color.primary)
            Spacer(minLength: 8)
            Text(L10n.openInBrowser)
              .font(.subheadline.weight(.medium))
              .foregroundStyle(Color.tatBrand)
          }
          .padding(.horizontal, 14)
          .padding(.vertical, 13)
          .background(
            Color(.secondarySystemGroupedBackground),
            in: GroupedRowShape(index: total - 1, count: total))
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
  }
}
