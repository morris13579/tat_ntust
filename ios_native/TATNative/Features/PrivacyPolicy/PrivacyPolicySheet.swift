import SwiftUI

/// 隱私權條款的唯讀入口（「關於」與登入頁），照 `privacy_policy_page.dart`。
struct PrivacyPolicySheet: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      PrivacyPolicyContent()
        .navigationTitle(L10n.PrivacyPolicy)
        .analyticsScreen("/PrivacyPolicyPage")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { SheetCloseButton(label: L10n.close) { dismiss() } }
    }
  }
}

/// 條款內容，照 `privacy_policy_view.dart`：最上面是摘要——學生真正在問的是帳號密碼存哪、成績會不會被看到，
/// 一千多字的本文沒有人從頭讀——接著是預設收起的一節一節本文，最後是修訂紀錄。唯讀的 sheet 與啟動時的同意閘門共用。
struct PrivacyPolicyContent: View {
  @State private var sections: [PolicySection] = []
  @State private var failed = false
  @State private var loading = true
  @State private var expanded: Set<Int> = []

  private static let source = URL(string: "https://raw.githubusercontent.com/morris13579/tat_ntust/master/privacy-policy.md")!
  private static let history = URL(string: "https://github.com/morris13579/tat_ntust/commits/master/privacy-policy.md")!

  var body: some View {
    Group {
      if loading {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if failed {
        ContentUnavailableView {
          Label {
            Text(L10n.pleaseConnectToNetwork)
          } icon: {
            LucideImage(Lucide.circleAlert, size: 44)
          }
        } actions: {
          Button(L10n.restart) { Task { await load() } }
        }
      } else {
        content
      }
    }
    .background(Color(.systemGroupedBackground))
    .task { await load() }
  }

  private var content: some View {
    let intro = sections.filter { $0.title == nil && !$0.body.isEmpty }
    let chapters = sections.filter { $0.title != nil }
    return ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        summary
        SectionHeader(
          title: L10n.privacyBodyTitle, icon: Lucide.fileText,
          trailing: L10n.privacySectionCount(String(chapters.count)))
        ForEach(intro) { section in
          blocks(section.body)
            .padding(EdgeInsets(top: 0, leading: 4, bottom: 12, trailing: 4))
        }
        // 預設全部收起：收起來一屏看得完，要找「會不會給別人」才點開。
        VStack(spacing: 2) {
          ForEach(Array(chapters.enumerated()), id: \.element.id) { index, section in
            chapter(section, index: index, count: chapters.count)
          }
        }
        historyLink
          .padding(.top, 20)
      }
      .padding(EdgeInsets(top: 12, leading: 16, bottom: 24, trailing: 16))
    }
  }

  private var summary: some View {
    let items: [(LucideIcon, String, String)] = [
      (Lucide.shieldCheck, L10n.privacySummaryLocalTitle, L10n.privacySummaryLocalBody),
      (Lucide.graduationCap, L10n.privacySummaryDataTitle, L10n.privacySummaryDataBody),
      (Lucide.chartColumn, L10n.privacySummaryAnalyticsTitle, L10n.privacySummaryAnalyticsBody),
      (Lucide.circleAlert, L10n.privacySummaryCrashTitle, L10n.privacySummaryCrashBody),
    ]
    return VStack(spacing: 2) {
      ForEach(Array(items.enumerated()), id: \.offset) { index, item in
        HStack(alignment: .firstTextBaseline, spacing: 12) {
          LucideImage(item.0, size: 18)
            .foregroundStyle(Color.tatBrand)
            .alignedToFirstTextLine(.body)
          VStack(alignment: .leading, spacing: 4) {
            Text(item.1).font(.body.weight(.semibold))
            Text(item.2).font(.subheadline).foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(EdgeInsets(top: 13, leading: 14, bottom: 13, trailing: 14))
        .background(Color(.secondarySystemGroupedBackground), in: GroupedRowShape(index: index, count: items.count))
      }
    }
  }

  private func chapter(_ section: PolicySection, index: Int, count: Int) -> some View {
    let open = expanded.contains(index)
    return VStack(alignment: .leading, spacing: 0) {
      Button {
        withAnimation(.easeOut(duration: 0.18)) {
          if open { expanded.remove(index) } else { expanded.insert(index) }
        }
      } label: {
        HStack(spacing: 8) {
          Text(section.title ?? "")
            .foregroundStyle(Color.primary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
          LucideImage(open ? Lucide.chevronDown : Lucide.chevronRight, size: 18)
            .foregroundStyle(.secondary)
        }
        .padding(EdgeInsets(top: 13, leading: 14, bottom: 13, trailing: 12))
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      if open {
        blocks(section.body)
          .padding(EdgeInsets(top: 0, leading: 14, bottom: 13, trailing: 14))
      }
    }
    .background(Color(.secondarySystemGroupedBackground), in: GroupedRowShape(index: index, count: count))
  }

  private var historyLink: some View {
    Link(destination: Self.history) {
      HStack(spacing: 12) {
        LucideImage(Lucide.history, size: 18)
          .foregroundStyle(.secondary)
        Text(L10n.privacyHistoryLink)
          .foregroundStyle(Color.primary)
          .frame(maxWidth: .infinity, alignment: .leading)
        LucideImage(Lucide.externalLink, size: 16)
          .foregroundStyle(.secondary)
      }
      .padding(14)
      .background(Color(.secondarySystemGroupedBackground), in: ListGroupShape.card)
    }
  }

  private func blocks(_ body: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(Array(paragraphs(of: body).enumerated()), id: \.offset) { _, block in
        block
      }
    }
    .font(.subheadline)
    .foregroundStyle(.secondary)
    .textSelection(.enabled)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// 不用 `AttributedString` 的整份文件模式：它會把 `* ` 條列吃掉。
  private func paragraphs(of body: String) -> [AnyView] {
    var result: [AnyView] = []
    var paragraph: [String] = []

    func flushParagraph() {
      let text = paragraph.joined(separator: " ").trimmingCharacters(in: .whitespaces)
      paragraph.removeAll()
      guard !text.isEmpty else { return }
      result.append(AnyView(Text(inline(text))))
    }

    for line in body.components(separatedBy: "\n") {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.isEmpty {
        flushParagraph()
        continue
      }
      if trimmed.hasPrefix("* ") || trimmed.hasPrefix("- ") {
        flushParagraph()
        let item = String(trimmed.dropFirst(2))
        result.append(AnyView(
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: "•")
            Text(inline(item))
          }
        ))
        continue
      }
      paragraph.append(trimmed)
    }
    flushParagraph()
    return result
  }

  private func inline(_ text: String) -> AttributedString {
    (try? AttributedString(
      markdown: text,
      options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    )) ?? AttributedString(text)
  }

  /// 先網路、失敗退回打包的那一份，同 `PrivacyPolicyController.fetchPolicy`。
  private func load() async {
    loading = true
    failed = false
    defer { loading = false }
    if let (data, response) = try? await URLSession.shared.data(from: Self.source),
      (response as? HTTPURLResponse)?.statusCode == 200,
      let text = String(data: data, encoding: .utf8)
    {
      sections = PolicySection.parse(text)
      return
    }
    if let path = Bundle.main.path(forResource: "privacy-policy", ofType: "md"),
      let text = try? String(contentsOfFile: path, encoding: .utf8)
    {
      sections = PolicySection.parse(text)
      return
    }
    failed = true
  }
}
