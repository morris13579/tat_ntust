import SwiftUI

/// 一則討論串，照 `course_forum_thread_page.dart`：第一篇加全部回覆。**回覆不換頁**：底部釘一條回覆列，
/// 對話還在上面；只有編輯既有貼文才換頁。
struct ForumThreadView: View {
  @Environment(AppEnvironment.self) private var app
  @Environment(\.dismiss) private var dismiss
  @State private var model: ForumThreadModel
  @State private var deleting: ForumPostItem?
  @State private var confirmDiscard = false
  @State private var picking = false
  @State private var attachSource: AttachmentSource?
  @FocusState private var inputFocused: Bool

  init(model: ForumThreadModel) {
    _model = State(initialValue: model)
  }

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          content
        }
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
      }
      .scrollDismissesKeyboard(.interactively)
      .onChange(of: model.scrollTarget) { _, id in
        guard let id else { return }
        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .top) }
        model.scrollTarget = nil
      }
    }
    .background(Color(.systemGroupedBackground))
    .pinnedBottomBar { bottomBar }
    .refreshable { await model.load(refresh: true) }
    .navigationTitle(model.title)
    .analyticsScreen("/CourseForumThreadPage")
    .navigationBarTitleDisplayMode(.inline)
    // 有草稿或送出中才換成自己的返回鍵攔下來；其他時候用系統的，右滑返回才有作用。
    .navigationBarBackButtonHidden(model.sending || model.hasDraft)
    .toolbar {
      if model.sending || model.hasDraft {
        BackButton { back() }
      }
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          Task { await model.openInWeb() }
        } label: {
          LucideImage(Lucide.externalLink, size: 18)
        }
        .accessibilityLabel(L10n.forumOpenInWeb)
        .toolbarButtonTint()
      }
    }
    .moodleLinks(
      client: model.moodle, folder: model.course.name, web: Binding(get: { model.web }, set: { model.web = $0 })
    )
    .browserSheet(item: Binding(get: { model.web }, set: { model.web = $0 })) { url in
      (try? await model.moodle.isAutologinScript(url: url.absoluteString)) ?? false
    }
    .navigationDestination(
      isPresented: Binding(get: { model.editing != nil }, set: { if !$0 { model.editing = nil } })
    ) {
      if let editing = model.editing {
        ForumEditView(model: editing) { result in model.applyEdit(result) }
      }
    }
    .alert(
      deleting?.depth == 0 ? L10n.forumDeleteTopicConfirm : L10n.forumDeletePostConfirm,
      isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
      presenting: deleting
    ) { post in
      Button(L10n.cancel, role: .cancel) {}
      Button(L10n.sure, role: .destructive) {
        Task {
          if await model.delete(post, presenter: app.presenter) { dismiss() }
        }
      }
    }
    .alert(L10n.forumDiscardDraft, isPresented: $confirmDiscard) {
      Button(L10n.cancel, role: .cancel) {}
      Button(L10n.sure, role: .destructive) { dismiss() }
    }
    .forumAttachmentPicker(
      source: $attachSource,
      remaining: max(0, Int(model.thread?.attach.maxFiles ?? 0) - model.attachments.count)
    ) { paths in
      Task { await model.addAttachments(paths, presenter: app.presenter) }
    }
    .task {
      if model.thread == nil { await model.load(refresh: false) }
    }
  }

  @ViewBuilder private var content: some View {
    if let thread = model.thread {
      if let notice = thread.notice {
        NoticeBar(message: notice, icon: Lucide.history, actionLabel: L10n.refresh) {
          Task { await model.load(refresh: true) }
        }
        .clipShape(ListGroupShape.card)
      }
      ForEach(thread.posts) { post in
        postBlock(post, composer: thread.composer)
          .id(post.id)
      }
      if let error = thread.error {
        InlineErrorView(message: error, signedIn: thread.signedIn, presenter: app.presenter) {
          await model.load(refresh: true)
        }
      }
    } else {
      ProgressView()
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
  }

  /// 主文用品牌色的淡底，回覆用卡片底色：一眼看得出哪一則是被回覆的那一篇，不必先找縮排。
  private func postBlock(_ post: ForumPostItem, composer: ForumComposerMode) -> some View {
    let root = post.depth == 0
    return VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 11) {
        Text(post.initial)
          .font(.footnote.weight(.medium))
          .foregroundStyle(root ? Color.tatBrand : Color.secondary)
          .frame(width: 32, height: 32)
          .background(
            root ? Color(.secondarySystemGroupedBackground) : Color(.systemGroupedBackground), in: Circle())
        HStack(spacing: 6) {
          Text(post.author)
            .font(.subheadline.weight(.medium))
            .lineLimit(1)
          if root {
            Text(L10n.forumTopicStarter)
              .font(.caption.weight(.medium))
              .foregroundStyle(Color.tatBrand)
          }
        }
        Spacer(minLength: 8)
        Text(post.time)
          .font(.footnote.monospacedDigit())
          .foregroundStyle(.secondary)
      }
      if let subject = post.subject {
        Text(subject).font(.headline)
      }
      if let html = post.messageHtml {
        MoodleHTMLView(html: html, client: model.moodle)
      } else if let placeholder = post.placeholder {
        Text(placeholder)
          .italic(post.deleted)
          .foregroundStyle(.secondary)
      }
      if !post.attachments.isEmpty {
        SectionSubLabel(text: L10n.forumAttachments)
        MoodleFileList(files: post.attachments, folder: model.course.name)
      }
      if (post.canReply && composer == .reply) || post.canEdit || post.canDelete {
        HStack {
          if post.canReply && composer == .reply {
            Button {
              model.aim(post)
              inputFocused = true
            } label: {
              HStack(spacing: 7) {
                LucideImage(Lucide.reply, size: 16)
                Text(L10n.forumReply)
              }
              .font(.subheadline.weight(.medium))
              .foregroundStyle(Color.tatBrand)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
          }
          Spacer()
          if post.canEdit || post.canDelete {
            // 破壞性的動作放在需要多一次點擊的地方，比擺在回覆鈕旁邊安全。
            Menu {
              if post.canEdit {
                Button {
                  Task { await model.startEdit(post, presenter: app.presenter) }
                } label: {
                  Label { Text(L10n.forumEditPost) } icon: { Image(uiImage: Lucide.pencil.uiImage()) }
                }
              }
              if post.canDelete {
                // 本機推出來的「底下有回覆」會少算，所以只是停用並附一句理由；伺服器才是最後的答案。
                Button(role: .destructive) {
                  deleting = post
                } label: {
                  Label { Text(L10n.forumDeletePost) } icon: {
                    Image(uiImage: post.hasReplies ? Lucide.trash2.uiImage() : Lucide.trash2.destructiveUIImage())
                  }
                  if post.hasReplies { Text(L10n.forumCannotDeleteHasReplies) }
                }
                .disabled(post.hasReplies)
              }
            } label: {
              LucideImage(Lucide.ellipsisVertical, size: 18)
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
            }
            .accessibilityLabel(L10n.forumPostActions)
          }
        }
      }
    }
    .padding(14)
    .background(
      root ? Color.tatBrand.opacity(0.1) : Color(.secondarySystemGroupedBackground),
      in: ListGroupShape.card
    )
    .overlay {
      if model.target?.id == post.id {
        ListGroupShape.card.strokeBorder(Color.tatBrand, lineWidth: 1)
      }
    }
    .padding(.leading, CGFloat(min(post.depth, 3)) * 12)
  }

  // MARK: - 底部

  @ViewBuilder private var bottomBar: some View {
    if let thread = model.thread {
      switch thread.composer {
      case .hidden:
        EmptyView()
      case .locked:
        VStack(alignment: .leading, spacing: 4) {
          Text(L10n.forumThreadLocked)
            .font(.footnote)
            .foregroundStyle(.secondary)
          Button(L10n.forumOpenInWeb) { Task { await model.openInWeb() } }
            .font(.footnote.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
      case .reply:
        composer(thread)
      }
    }
  }

  private func composer(_ thread: ForumThread) -> some View {
    let progress = app.transfers.progress[model.transferKey]
    return VStack(alignment: .leading, spacing: 9) {
      if model.sending {
        if let value = progress?.progress {
          ProgressView(value: value).tint(Color.tatBrand)
        } else {
          ProgressView().progressViewStyle(.linear).tint(Color.tatBrand)
        }
      }
      if !model.attachments.isEmpty {
        HStack {
          Text(L10n.forumAttachments)
          Spacer()
          Text("\(model.attachments.count)/\(thread.attach.maxFiles)").monospacedDigit()
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        ForEach(model.attachments, id: \.self) { path in
          HStack(spacing: 10) {
            LucideImage(Lucide.paperclip, size: 16).foregroundStyle(.secondary)
            Text((path as NSString).lastPathComponent)
              .font(.subheadline)
              .lineLimit(1)
            Spacer()
            Button {
              model.removeAttachment(path)
            } label: {
              LucideImage(Lucide.x, size: 16)
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.forumRemoveAttachment)
            .disabled(model.sending)
          }
        }
      }
      // 回覆對象的那一列永遠都在：兩種狀態長得一樣的話，捲到第 17 則再打字的人會以為自己在回那一則。
      HStack(spacing: 8) {
        LucideImage(Lucide.reply, size: 15)
        Text(
          model.target.map { L10n.forumReplyingTo($0.author) } ?? L10n.forumReplyingToTopic(thread.title)
        )
        .font(.footnote)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { model.scrollTarget = model.target?.id ?? thread.posts.first?.id }
        if model.target != nil {
          Button {
            model.target = nil
          } label: {
            LucideImage(Lucide.x, size: 16)
              .frame(width: 32, height: 24)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel(L10n.forumCancelReplyTarget)
          .disabled(model.sending)
        }
      }
      .foregroundStyle(.secondary)
      HStack(alignment: .bottom, spacing: 10) {
        HStack(alignment: .bottom, spacing: 6) {
          if thread.attach.enabled {
            Button {
              picking = true
            } label: {
              LucideImage(Lucide.paperclip, size: 20)
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.forumAddAttachment)
            .disabled(model.sending || model.attachments.count >= Int(thread.attach.maxFiles))
            .attachmentSourceDialog(isPresented: $picking) { attachSource = $0 }
          }
          TextField(
            L10n.forumReplyHint, text: Binding(get: { model.text }, set: { model.text = $0 }), axis: .vertical
          )
          .lineLimit(1...6)
          .focused($inputFocused)
          .padding(.vertical, 6)
          .disabled(model.sending)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        sendSlot(progress)
      }
    }
    .padding(.horizontal, 16)
    .padding(.top, 10)
    .padding(.bottom, 10)
  }

  @ViewBuilder private func sendSlot(_ progress: TransferProgress?) -> some View {
    if model.sending {
      if progress?.phase == .upload {
        Button {
          Task { await model.cancelUpload() }
        } label: {
          LucideImage(Lucide.x, size: 20)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.cancel)
      } else {
        ProgressView().frame(width: 44, height: 44)
      }
    } else {
      Button {
        Task { await model.send(transfers: app.transfers, presenter: app.presenter) }
      } label: {
        LucideImage(Lucide.send, size: 20)
          .foregroundStyle(Color.white)
          .frame(width: 44, height: 44)
          .background(
            model.canSend ? Color.tatBrand : Color(.systemGray3),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .buttonStyle(.plain)
      .accessibilityLabel(L10n.forumSend)
      .disabled(!model.canSend)
    }
  }

  private func back() {
    // 送出中一律擋住：那一則已經在路上了，離開只會讓它沒有人接。
    if model.sending {
      app.presenter.toast(L10n.forumSending)
    } else if model.hasDraft {
      confirmDiscard = true
    } else {
      dismiss()
    }
  }
}
