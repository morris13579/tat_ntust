import SwiftUI

/// 「作業」分頁，照 `course_assignment_page.dart`：一句件數、每一份作業一列，狀態籤或分數在右邊，
/// 為什麼是這個狀態由副標講完。
struct CourseAssignmentsView: View {
  @Environment(AppEnvironment.self) private var app
  let model: CourseMoodleModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        content
      }
      .padding(EdgeInsets(top: 12, leading: 16, bottom: 32, trailing: 16))
    }
    .pageScrollInset()
    .refreshable { await model.loadAssignments() }
  }

  @ViewBuilder private var content: some View {
    if let list = model.assignments {
      if let notice = list.notice {
        NoticeBar(message: notice, icon: Lucide.history, actionLabel: L10n.refresh) {
          Task { await model.loadAssignments() }
        }
        .clipShape(ListGroupShape.card)
        .padding(.bottom, 10)
      }
      if let error = list.error, list.rows.isEmpty {
        InlineErrorView(message: error, signedIn: list.signedIn, presenter: app.presenter) {
          await model.loadAssignments()
        }
      } else if list.rows.isEmpty {
        SectionEmptyState(message: L10n.assignmentEmpty, icon: Lucide.clipboardList)
      } else {
        Text(list.summary)
          .font(.footnote.monospacedDigit())
          .foregroundStyle(.secondary)
          .padding(.horizontal, 4)
          .padding(.bottom, 10)
        VStack(spacing: 2) {
          ForEach(Array(list.rows.enumerated()), id: \.element.id) { index, row in
            Button {
              model.openAssignment(row)
            } label: {
              AssignmentRowView(row: row, index: index, count: list.rows.count)
            }
            .buttonStyle(.plain)
          }
        }
      }
    } else {
      ProgressView()
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
  }
}

struct AssignmentRowView: View {
  let row: AssignmentRow
  let index: Int
  let count: Int

  var body: some View {
    HStack(spacing: 13) {
      LucideImage(icon.symbol, size: 20)
        .foregroundStyle(icon.color)
      VStack(alignment: .leading, spacing: 4) {
        Text(row.name)
          .foregroundStyle(Color.primary)
          .lineLimit(2)
          .multilineTextAlignment(.leading)
        Text(row.subtitle)
          .font(.subheadline.monospacedDigit())
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      trailing
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 13)
    .background(Color(.secondarySystemGroupedBackground), in: GroupedRowShape(index: index, count: count))
    .contentShape(Rectangle())
  }

  @ViewBuilder private var trailing: some View {
    if let grade = row.grade {
      HStack(alignment: .firstTextBaseline, spacing: 3) {
        Text(grade).font(.title3.weight(.semibold).monospacedDigit())
        if let suffix = row.gradeSuffix {
          Text(suffix)
            .font(.footnote.monospacedDigit())
            .foregroundStyle(.secondary)
        }
      }
    } else if row.loading {
      ProgressView().controlSize(.small)
    } else if let label = row.statusLabel, let tone = row.statusTone {
      StatusPill(label: label, tone: tone.pill, stale: row.stale)
    }
  }

  /// 狀態決定圖示與顏色：逾期是紅、還沒交完是橘、交出去或評完了是中性與綠。
  private var icon: (symbol: LucideIcon, color: Color) {
    switch row.icon {
    case .unknown: (Lucide.clipboardList, Color.secondary)
    case .overdue: (Lucide.circleAlert, Color(.systemRed))
    case .draft: (Lucide.fileText, Color(.systemOrange))
    case .attention: (Lucide.circleAlert, Color(.systemOrange))
    case .submitted: (Lucide.circleCheck, Color.secondary)
    case .graded: (Lucide.circleCheck, Color(.systemGreen))
    case .noSubmission: (Lucide.circleCheck, Color.secondary)
    }
  }
}

extension AssignmentRow: Identifiable {}
