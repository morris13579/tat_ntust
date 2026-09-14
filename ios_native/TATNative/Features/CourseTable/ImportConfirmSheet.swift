import SwiftUI

/// 匯入前的確認，照 `import_confirm_sheet.dart`：學號、學年期、門數，加上前幾門課的預覽。
/// 課名是進來之後才查的——查不到或沒網路也照樣匯得進去。
struct ImportConfirmSheet: View {
  let preview: SharePreview
  let raw: String
  let client: CourseTableClient
  let onConfirm: () -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var found: [String: SharedCourseInfo] = [:]

  private var hidden: Int64 { preview.courseCount - Int64(preview.courses.count) }

  var body: some View {
    SheetStack(title: L10n.importConfirmTitle, closeLabel: L10n.cancel) {
      List {
        Section {
          VStack(spacing: 4) {
            Text(preview.studentId)
              .font(.title2.weight(.semibold).monospacedDigit())
            Text("\(preview.semester) · \(L10n.courseCount(String(preview.courseCount)))")
              .font(.subheadline.monospacedDigit())
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 6)
        }
        Section {
          ForEach(preview.courses, id: \.id) { previewRow($0) }
          if hidden > 0 {
            Text(L10n.importMoreCourses(String(hidden)))
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
      }
      .bottomAction(L10n.importConfirmOpen) {
        onConfirm()
        dismiss()
      }
    }
    .task {
      for info in (try? await client.lookupPreview(raw: raw)) ?? [] {
        found[info.id] = info
      }
    }
  }

  /// 課名查回來之前就印課號：留白會讓人以為這門課壞了。右邊的節次一律來自分享碼。
  private func previewRow(_ course: SharePreviewCourse) -> some View {
    let info = found[course.id]
    let trailing = [course.slots, info?.classroom ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    return HStack(spacing: 12) {
      if let name = info?.name {
        Text(name).lineLimit(1)
      } else {
        Text(course.id).monospacedDigit().foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
      if !trailing.isEmpty {
        Text(trailing)
          .font(.subheadline.monospacedDigit())
          .foregroundStyle(.secondary)
      }
    }
  }
}
