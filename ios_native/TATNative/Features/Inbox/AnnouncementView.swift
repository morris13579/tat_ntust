import SwiftUI

/// TAT 公告全文，照 `announcement_page.dart`：左右翻頁，控制項收在底部。啟動彈窗的最後一則要等倒數完才能按確定；
/// 翻頁不是關掉公告，所以不必等。
struct AnnouncementView: View {
  @Environment(AppEnvironment.self) private var app
  @Environment(\.dismiss) private var dismiss
  let notices: [InboxNotice]
  /// 放在 sheet 裡時右上角給關閉。
  var showClose = false
  @State private var index = 0
  @State private var remaining: Int

  init(notices: [InboxNotice], countDown: Int, showClose: Bool = false) {
    self.notices = notices
    self.showClose = showClose
    _remaining = State(initialValue: countDown)
  }

  var body: some View {
    TabView(selection: $index) {
      ForEach(Array(notices.enumerated()), id: \.offset) { offset, notice in
        page(notice, position: offset).tag(offset)
      }
    }
    .tabViewStyle(.page(indexDisplayMode: .never))
    .extendsUnderBars()
    .background(Color(.systemGroupedBackground))
    .pinnedBottomBar { bottomBar }
    .navigationTitle(L10n.appAnnouncement)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if showClose { SheetCloseButton { dismiss() } }
    }
    // 公告連的是表單與商店，不是 Moodle，一律交給系統。
    .environment(\.openURL, OpenURLAction { _ in .systemAction })
    .task {
      while remaining > 0 {
        guard (try? await Task.sleep(for: .seconds(1))) != nil else { return }
        remaining -= 1
      }
    }
    .analyticsScreen("/AnnouncementPage")
  }

  private func page(_ notice: InboxNotice, position: Int) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 9) {
          // 只有兩則以上才出現：一則的時候它只是在說「一共一則」。
          if notices.count > 1 {
            HStack(spacing: 6) {
              LucideImage(Lucide.megaphone, size: 14)
              Text(verbatim: "\(position + 1) / \(notices.count)").monospacedDigit()
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.tatBrand)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Color.tatBrand.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
          }
          Text(notice.date)
            .font(.footnote.monospacedDigit())
            .foregroundStyle(.secondary)
            .accessibilityLabel("\(L10n.announcementPublishedAt) \(notice.date)")
        }
        Text(notice.title)
          .font(.title2.weight(.bold))
        MarkdownText(markdown: notice.content)
          .textSelection(.enabled)
          .padding(16)
          .background(
            Color(.secondarySystemGroupedBackground), in: ListGroupShape.card)
      }
      .padding(16)
    }
    .pageScrollInset()
  }

  private var bottomBar: some View {
    let isLast = index >= notices.count - 1
    let waiting = remaining > 0
    return HStack(spacing: 10) {
      if notices.count > 1 {
        Button {
          withAnimation { index -= 1 }
        } label: {
          LucideImage(Lucide.chevronLeft, size: 20)
            .frame(width: 30, height: 30)
        }
        .buttonStyle(.bordered)
        .disabled(index == 0)
        .accessibilityLabel(L10n.announcementPrevious)
      }
      HStack(spacing: 7) {
        if notices.count > 1 {
          ForEach(notices.indices, id: \.self) { dot in
            Circle()
              .fill(dot == index ? Color.tatBrand : Color(.systemGray4))
              .frame(width: 8, height: 8)
          }
        }
      }
      .frame(maxWidth: .infinity)
      Button {
        if isLast {
          Task { try? await app.appNotice.markAnnouncementRead() }
          dismiss()
        } else {
          withAnimation { index += 1 }
        }
      } label: {
        Text(isLast ? (waiting ? "\(L10n.wait) \(remaining)" : L10n.sure) : L10n.announcementNext)
          .monospacedDigit()
          .frame(minWidth: 88)
      }
      .prominentButtonStyle()
      .controlSize(.large)
      .disabled(isLast && waiting)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }
}
