import SwiftUI

/// 「檔案」分頁，照 `course_directory_page.dart`：週次課程把本週攤開、其餘有內容的週次列在下面、
/// 空白的週收起來；主題式課程每個主題先露三個項目。上面釘著一條檔名搜尋。
struct CourseDirectoryView: View {
  @Environment(AppEnvironment.self) private var app
  let model: CourseMoodleModel
  @State private var expanded: Set<Int64> = []
  @State private var showAll: Set<Int64> = []
  @State private var currentWeekOpen = true
  @State private var showEmptyWeeks = false

  /// 主題式一次先露幾個項目。
  private static let previewCount = 3

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        content
      }
      .padding(EdgeInsets(top: 4, leading: 16, bottom: 32, trailing: 16))
    }
    .scrollDismissesKeyboard(.immediately)
    .pageScrollInset()
    .pinnedTopBar { searchField }
    .refreshable { await model.loadDirectory() }
  }

  /// 系統的搜尋列，跟其他有搜尋的頁面同一個樣子；這一頁在分頁裡，掛不了 `.searchable`。
  /// 不墊底色：內容捲到搜尋列後面時由系統淡出。
  private var searchField: some View {
    SystemSearchBar(text: Binding(get: { model.query }, set: { model.query = $0 }), prompt: L10n.searchFileName)
      .padding(.horizontal, 8)
      .onChange(of: model.query) {
        Task { await model.search() }
      }
  }

  @ViewBuilder private var content: some View {
    if let directory = model.directory {
      if let notice = directory.notice {
        NoticeBar(message: notice, icon: Lucide.history, actionLabel: L10n.refresh) {
          Task { await model.loadDirectory() }
        }
        .clipShape(ListGroupShape.card)
        .padding(.bottom, 10)
      }
      if let error = directory.error, directory.currentWeek == nil, directory.sections.isEmpty {
        InlineErrorView(message: error, signedIn: directory.signedIn, presenter: app.presenter) {
          await model.loadDirectory()
        }
      } else if !model.query.trimmingCharacters(in: .whitespaces).isEmpty {
        searchResults
      } else if directory.weekly {
        weekly(directory)
      } else {
        topics(directory)
      }
    } else {
      ProgressView()
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
  }

  @ViewBuilder private var searchResults: some View {
    if model.searchResults.isEmpty {
      SectionEmptyState(message: L10n.fileSearchNoResult, icon: Lucide.search)
    } else {
      // 命中的列留在原本那一段底下：只有一串檔名看不出它是哪一週的。
      ForEach(Array(model.searchResults.enumerated()), id: \.element.id) { index, section in
        SectionHeader(title: section.title, first: index == 0)
        group(section.modules.map { .module($0) })
      }
    }
  }

  @ViewBuilder private func weekly(_ directory: CourseDirectory) -> some View {
    stats(directory.stats)
    if let current = directory.currentWeek {
      // 本週那一張的項目就攤在底下，右邊不再放數字。
      group(
        [.section(current, badge: true, open: currentWeekOpen, count: nil, folder: false)]
          + (currentWeekOpen ? current.modules.map { .module($0) } : []))
    }
    if !directory.sections.isEmpty {
      SectionHeader(title: directory.currentWeek == nil ? L10n.weeksWithFiles : L10n.otherWeeksWithFiles)
      group(sectionRows(directory.sections, folder: false, limit: nil))
    }
    if !directory.emptySections.isEmpty {
      Spacer().frame(height: 20)
      group(
        [
          .disclosure(
            showEmptyWeeks
              ? L10n.hideEmptyWeeks : L10n.showEmptyWeeks(String(directory.emptySections.count)),
            open: showEmptyWeeks, action: .emptyWeeks)
        ] + (showEmptyWeeks ? sectionRows(directory.emptySections, folder: false, limit: nil) : []))
    }
  }

  @ViewBuilder private func topics(_ directory: CourseDirectory) -> some View {
    stats(directory.stats)
    SectionHeader(title: L10n.topic, first: true)
    group(sectionRows(directory.sections, folder: true, limit: Self.previewCount))
  }

  private func stats(_ text: String) -> some View {
    Text(text)
      .font(.footnote.monospacedDigit())
      .foregroundStyle(.secondary)
      .padding(.horizontal, 4)
      .padding(.top, 4)
      .padding(.bottom, 10)
  }

  /// 一段一列，展開的段把模組接在自己底下。[limit] 有值時先只露那麼多列，其餘收在一列連結後面。
  private func sectionRows(_ sections: [CourseSectionItem], folder: Bool, limit: Int?) -> [Row] {
    var rows: [Row] = []
    for section in sections {
      let open = expanded.contains(section.id)
      rows.append(
        .section(
          section, badge: false, open: open, count: section.modules.isEmpty ? nil : section.modules.count,
          folder: folder))
      guard open else { continue }
      let visible =
        limit == nil || showAll.contains(section.id) ? section.modules : Array(section.modules.prefix(limit!))
      rows += visible.map { .module($0) }
      let hidden = section.modules.count - visible.count
      if hidden > 0 {
        rows.append(.disclosure(L10n.showRemainingFiles(String(hidden)), open: false, action: .showAll(section.id)))
      }
    }
    return rows
  }

  /// 一串相連的列：頭尾大圓角、中間小圓角。
  private func group(_ rows: [Row]) -> some View {
    VStack(spacing: 2) {
      ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
        rowView(row, index: index, count: rows.count)
      }
    }
  }

  @ViewBuilder private func rowView(_ row: Row, index: Int, count: Int) -> some View {
    switch row {
    case .section(let section, let badge, let open, let rowCount, let folder):
      sectionRow(section, badge: badge, open: open, count: rowCount, folder: folder, index: index, total: count)
    case .module(let module):
      CourseModuleRow(module: module, index: index, count: count) {
        Task { await model.open(module, presenter: app.presenter) }
      }
    case .disclosure(let label, let open, let action):
      disclosureRow(label, open: open, action: action, index: index, count: count)
    }
  }

  private func sectionRow(
    _ section: CourseSectionItem, badge: Bool, open: Bool, count: Int?, folder: Bool, index: Int, total: Int
  ) -> some View {
    // 本週與展開中的段換一套色：它底下接的模組列同樣是圓角塊，兩層一樣白的話分不出哪一行是標題。
    let active = badge || open
    return Button {
      withAnimation(.easeOut(duration: 0.18)) {
        if badge {
          currentWeekOpen.toggle()
        } else if expanded.contains(section.id) {
          expanded.remove(section.id)
        } else {
          expanded.insert(section.id)
        }
      }
    } label: {
      HStack(spacing: 12) {
        if folder {
          LucideImage(Lucide.folder, size: 20)
        }
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 9) {
            if badge {
              Text(L10n.thisWeek).font(.footnote.weight(.semibold))
            }
            Text(section.title)
              .font(.body.monospacedDigit())
              .foregroundStyle(active ? Color.tatBrand : Color.primary)
              .lineLimit(2)
              .multilineTextAlignment(.leading)
          }
          if let summary = section.summary {
            Text(summary)
              .font(.subheadline)
              .lineLimit(1)
          }
        }
        Spacer(minLength: 8)
        if let count {
          Text("\(count)").font(.subheadline.monospacedDigit())
        }
        LucideImage(badge ? (currentWeekOpen ? Lucide.chevronUp : Lucide.chevronDown) : (open ? Lucide.chevronUp : Lucide.chevronDown), size: 18)
      }
      .foregroundStyle(active ? Color.tatBrand : Color.secondary)
      .padding(.horizontal, 14)
      .padding(.vertical, 13)
      .background(
        active ? Color.tatBrand.opacity(0.14) : Color(.secondarySystemGroupedBackground),
        in: GroupedRowShape(index: index, count: total)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private func disclosureRow(_ label: String, open: Bool, action: Disclosure, index: Int, count: Int) -> some View {
    let isLink: Bool = if case .showAll = action { true } else { false }
    return Button {
      withAnimation(.easeOut(duration: 0.18)) {
        switch action {
        case .emptyWeeks: showEmptyWeeks.toggle()
        case .showAll(let id): showAll.insert(id)
        }
      }
    } label: {
      HStack(spacing: 9) {
        Text(label)
          .font(.subheadline.weight(.medium))
          .lineLimit(1)
        if !isLink {
          LucideImage(open ? Lucide.chevronUp : Lucide.chevronDown, size: 17)
        }
      }
      .foregroundStyle(isLink ? Color.tatBrand : Color.secondary)
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 14)
      .padding(.vertical, 13)
      .background(Color(.secondarySystemGroupedBackground), in: GroupedRowShape(index: index, count: count))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private enum Disclosure: Hashable {
    case emptyWeeks
    case showAll(Int64)
  }

  private enum Row: Identifiable {
    case section(CourseSectionItem, badge: Bool, open: Bool, count: Int?, folder: Bool)
    case module(CourseModuleItem)
    case disclosure(String, open: Bool, action: Disclosure)

    var id: String {
      switch self {
      case .section(let section, let badge, _, _, _): "section-\(section.id)-\(badge)"
      case .module(let module): "module-\(module.id)"
      case .disclosure(_, _, let action): "disclosure-\(action)"
      }
    }
  }
}

/// 課程模組的一列，照 `CourseModuleRow`：檔案是「類型圖示 + 檔名 + PDF · 2.4 MB + 下載」，
/// 其他模組依種類換圖示與尾端。說明是可以展開的第二層，展開的箭頭與整列的動作分開。
struct CourseModuleRow: View {
  let module: CourseModuleItem
  let index: Int
  let count: Int
  let onTap: () -> Void
  @State private var descriptionOpen = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if module.kind == .label {
        HStack(alignment: .top, spacing: 11) {
          LucideImage(Lucide.tag, size: 20)
            .foregroundStyle(Color.tatBrand)
          HTMLText(html: module.descriptionHtml ?? "")
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
      } else {
        HStack(spacing: 11) {
          Button(action: onTap) {
            HStack(spacing: 11) {
              LucideImage(icon, size: 20)
                .foregroundStyle(Color.tatBrand)
              VStack(alignment: .leading, spacing: 3) {
                Text(module.name)
                  .foregroundStyle(Color.primary)
                  .lineLimit(2)
                  .multilineTextAlignment(.leading)
                if let subtitle = module.subtitle {
                  Text(subtitle)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
              }
              .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          if module.descriptionHtml != nil {
            Button {
              withAnimation(.easeOut(duration: 0.16)) { descriptionOpen.toggle() }
            } label: {
              LucideImage(descriptionOpen ? Lucide.chevronUp : Lucide.chevronDown, size: 17)
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(module.name)
          }
          trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        if descriptionOpen, let description = module.descriptionHtml {
          HTMLText(html: description)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
      }
    }
    .background(Color(.secondarySystemGroupedBackground), in: GroupedRowShape(index: index, count: count))
  }

  private var icon: LucideIcon {
    switch module.kind {
    case .resource: MoodleFileIcon.of(module.fileIcon)
    case .forum: Lucide.messageSquare
    case .assign: Lucide.clipboardList
    case .folder: Lucide.folder
    case .quiz: Lucide.fileQuestionMark
    case .label: Lucide.tag
    case .url: Lucide.link
    case .page, .other: Lucide.copy
    }
  }

  @ViewBuilder private var trailing: some View {
    switch module.kind {
    case .resource:
      LucideImage(Lucide.download, size: 18).foregroundStyle(Color.tatBrand)
    case .url:
      LucideImage(Lucide.externalLink, size: 17).foregroundStyle(.secondary)
    case .label:
      EmptyView()
    default:
      LucideImage(Lucide.chevronRight, size: 17).foregroundStyle(.secondary)
    }
  }
}
