import SwiftUI

/// 資料夾模組的某一層，照 `course_folder_page.dart`：先子資料夾、再檔案。進子資料夾是把自己再推一次，
/// 返回手勢天生就回到上一層。
struct CourseFolderView: View {
  @Environment(AppEnvironment.self) private var app
  let client: CourseMoodleClient
  let course: CourseRef
  let moduleId: Int64
  let path: String
  let title: String
  @State private var folder: CourseFolder?
  @State private var loaded = false
  @State private var subfolder: FolderEntry?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        content
      }
      .padding(EdgeInsets(top: 12, leading: 16, bottom: 32, trailing: 16))
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle(folder?.title ?? title)
    .analyticsScreen("/CourseFolderPage")
    .navigationBarTitleDisplayMode(.inline)
    .navigationDestination(item: $subfolder) { entry in
      CourseFolderView(client: client, course: course, moduleId: moduleId, path: entry.path, title: entry.name)
    }
    .task {
      guard !loaded else { return }
      folder = try? await client.folder(courseId: course.courseId, moduleId: moduleId, path: path)
      loaded = true
    }
  }

  @ViewBuilder private var content: some View {
    if !loaded {
      ProgressView()
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    } else if let folder, !(folder.folders.isEmpty && folder.files.isEmpty) {
      SectionHeader(title: folder.breadcrumb, first: true)
      let total = folder.folders.count + folder.files.count
      VStack(spacing: 2) {
        ForEach(Array(folder.folders.enumerated()), id: \.offset) { index, entry in
          row(
            icon: Lucide.folder, iconColor: Color.tatBrand, name: entry.name, subtitle: entry.subtitle,
            trailing: Lucide.chevronRight, index: index, count: total
          ) {
            subfolder = entry
          }
        }
        ForEach(Array(folder.files.enumerated()), id: \.offset) { offset, file in
          row(
            icon: MoodleFileIcon.of(file.fileIcon), iconColor: Color.tatBrand, name: file.name,
            subtitle: file.subtitle, trailing: Lucide.download, index: folder.folders.count + offset, count: total
          ) {
            Task {
              await MoodleFiles.open(
                MoodleFileLink(name: file.name, url: file.url), folder: course.name, presenter: app.presenter)
            }
          }
        }
      }
    } else {
      SectionEmptyState(message: L10n.folderEmpty, icon: Lucide.folder)
    }
  }

  private func row(
    icon: LucideIcon, iconColor: Color, name: String, subtitle: String?, trailing: LucideIcon, index: Int,
    count: Int, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 11) {
        LucideImage(icon, size: 20).foregroundStyle(iconColor)
        VStack(alignment: .leading, spacing: 3) {
          Text(name)
            .foregroundStyle(Color.primary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
          if let subtitle {
            Text(subtitle)
              .font(.subheadline.monospacedDigit())
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        LucideImage(trailing, size: 17)
          .foregroundStyle(trailing == Lucide.download ? Color.tatBrand : Color.secondary)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(Color(.secondarySystemGroupedBackground), in: GroupedRowShape(index: index, count: count))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}
