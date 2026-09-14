import SwiftUI

/// 「公告」分頁，照 `course_announcement_page.dart`：公告區與課程討論區併成一條時間軸，
/// 兩種都真的有列時才給篩選籤。
struct CourseFeedView: View {
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
    .refreshable { await model.loadFeed() }
  }

  @ViewBuilder private var content: some View {
    if let feed = model.feed {
      if let notice = feed.notice {
        NoticeBar(message: notice, icon: Lucide.history, actionLabel: L10n.refresh) {
          Task { await model.loadFeed() }
        }
        .clipShape(ListGroupShape.card)
        .padding(.bottom, 10)
      }
      if let error = feed.error, feed.entries.isEmpty {
        InlineErrorView(message: error, signedIn: feed.signedIn, presenter: app.presenter) {
          await model.loadFeed()
        }
      } else if feed.entries.isEmpty {
        SectionEmptyState(message: feed.emptyMessage, icon: Lucide.messageSquare)
      } else {
        // 數字是 0 的那一顆點下去只會清空畫面，那不是篩選，是死路。
        if feed.announcementCount > 0 && feed.discussionCount > 0 {
          filters(feed)
        }
        ForumEntryList(entries: model.feedEntries) { row in
          model.openDiscussion(row)
        }
      }
    } else {
      ProgressView()
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
  }

  private func filters(_ feed: CourseFeed) -> some View {
    FlowLayout {
      FilterChip(label: L10n.forumFilterAll, isOn: model.feedFilter == nil) {
        Task { await model.filterFeed(nil) }
      }
      FilterChip(
        label: L10n.forumFilterAnnouncements(String(feed.announcementCount)),
        isOn: model.feedFilter == .announcement
      ) {
        Task { await model.filterFeed(.announcement) }
      }
      FilterChip(
        label: L10n.forumFilterDiscussions(String(feed.discussionCount)),
        isOn: model.feedFilter == .discussion
      ) {
        Task { await model.filterFeed(.discussion) }
      }
    }
    .padding(.bottom, 4)
  }
}

/// 討論串清單：月份標題加一組組相連的列。公告分頁與討論區頁共用。
struct ForumEntryList: View {
  let entries: [FeedEntry]
  let onTap: (ForumRow) -> Void

  var body: some View {
    ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
      if let header = entry.header {
        SectionHeader(title: header, first: index == 0)
      } else if let row = entry.row {
        ForumRowView(row: row) { onTap(row) }
          .padding(.top, row.indexInGroup == 0 ? 0 : 2)
      }
    }
  }
}

/// 討論串清單的一列，照 `ForumDiscussionCard`：沒有已讀未讀，App 讀公告不會回寫 Moodle 的閱讀狀態。
struct ForumRowView: View {
  let row: ForumRow
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 10) {
        VStack(alignment: .leading, spacing: 5) {
          HStack(alignment: .firstTextBaseline, spacing: 6) {
            if row.pinned {
              LucideImage(Lucide.pin, size: 14).foregroundStyle(.secondary)
            }
            Text(row.name)
              .foregroundStyle(Color.primary)
              .lineLimit(2)
              .multilineTextAlignment(.leading)
          }
          Text(meta)
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        if row.hasAttachment {
          LucideImage(Lucide.paperclip, size: 16).foregroundStyle(.secondary)
        }
        if let replies = row.replies {
          HStack(spacing: 6) {
            LucideImage(Lucide.messageCircle, size: 16)
            Text("\(replies)").font(.subheadline.monospacedDigit())
          }
          .foregroundStyle(.secondary)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(L10n.forumReplies(String(replies)))
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 13)
      .background(
        Color(.secondarySystemGroupedBackground),
        in: GroupedRowShape(index: Int(row.indexInGroup), count: Int(row.groupLength))
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  /// 「姓名 · 學號 · 12」：名字要讀、學號要查，兩件事各有各的位置。
  private var meta: String {
    [row.author, row.studentId, row.day].compactMap { $0 }.joined(separator: " · ")
  }
}
