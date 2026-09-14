import SwiftUI

/// 一封信，照 `mail_detail_page.dart`：主旨當大標、寄件者一張卡，附件與遠端圖片的提示在內文上面，內文滿版。
/// 回覆在底部當主鈕，全部回覆與轉寄縮在旁邊——誤按「全部回覆」是寄給整個投遞群組；封存與刪除放頂部，離拇指遠一點。
struct MailDetailView: View {
  @Environment(AppEnvironment.self) private var app
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  @State private var model: MailDetailModel
  @State private var composing: MailComposeRequest?
  let onMoved: () -> Void

  init(model: MailDetailModel, onMoved: @escaping () -> Void) {
    _model = State(initialValue: model)
    self.onMoved = onMoved
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        if let header = model.header {
          // 不截斷：這是整頁唯一說明「這是哪一封信」的東西。
          Text(header.subject)
            .font(.title2.weight(.bold))
            .textSelection(.enabled)
            .padding(.top, 10)
            .padding(.bottom, 14)
          senderCard(header)
        }
        content
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 24)
    }
    .background(Color(.systemGroupedBackground))
    .pinnedBottomBar { actionBar }
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        Button {
          Task { await move(archive: true) }
        } label: {
          LucideImage(Lucide.archive, size: 20)
        }
        .accessibilityLabel(L10n.mailFolderArchive)
        .toolbarButtonTint()

        Button {
          Task { await move(archive: false) }
        } label: {
          LucideImage(Lucide.trash2, size: 20)
        }
        .accessibilityLabel(L10n.delete)
        .toolbarButtonTint()
      }
    }
    .disabled(model.moving)
    .sheet(item: $composing) { request in
      MailComposeView(model: MailComposeModel(client: app.mail, kind: request.kind, ref: request.ref)) {}
    }
    .task {
      if model.content == nil { await model.load() }
    }
    .analyticsScreen("/MailDetailPage")
  }

  @ViewBuilder private var content: some View {
    if let body = model.content {
      if let error = body.error {
        InlineErrorView(message: error, signedIn: true, presenter: app.presenter) { await model.load() }
      } else {
        if !body.attachments.isEmpty { attachments(body.attachments) }
        if body.remoteImages && !model.showRemoteImages { remoteImagesCard }
        if let html = body.html {
          MailBodyView(html: html, allowRemote: model.showRemoteImages, height: $model.bodyHeight) { url in
            openURL(url)
          }
          .frame(height: model.bodyHeight)
          .padding(.top, 16)
        }
      }
    } else {
      ProgressView()
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
  }

  private func senderCard(_ header: MailHeader) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 2) {
        Text(header.from)
          .font(.body.weight(.semibold))
        if let email = header.fromEmail {
          Text(email)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        Text(header.date)
          .font(.subheadline.monospacedDigit())
          .foregroundStyle(.secondary)
      }
      .textSelection(.enabled)
      .padding(14)

      if let count = header.recipientCount {
        Divider()
        Button {
          withAnimation(.easeOut(duration: 0.2)) { model.showRecipients.toggle() }
        } label: {
          HStack {
            Text(count)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
            LucideImage(model.showRecipients ? Lucide.chevronUp : Lucide.chevronDown, size: 18)
              .foregroundStyle(.secondary)
          }
          .padding(14)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        // 收件者與副本分開列：「這封是不是只寄給我」正是展開這一列想知道的事。
        if model.showRecipients {
          VStack(alignment: .leading, spacing: 10) {
            if !header.to.isEmpty { recipientGroup(L10n.mailRecipientTo, header.to) }
            if !header.cc.isEmpty { recipientGroup(L10n.mailCc, header.cc) }
          }
          .padding(.horizontal, 14)
          .padding(.bottom, 13)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      Color(.secondarySystemGroupedBackground), in: ListGroupShape.card)
  }

  private func recipientGroup(_ label: String, _ lines: [MailAddressLine]) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Text(label)
        .foregroundStyle(.secondary)
        .frame(width: 68, alignment: .leading)
      VStack(alignment: .leading, spacing: 3) {
        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
          HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(line.address)
              .fontWeight(line.mine ? .semibold : .regular)
              .foregroundStyle(line.mine ? Color.primary : Color.secondary)
            if line.mine {
              Text(L10n.mailSelfMarker)
                .foregroundStyle(Color.tatBrand)
            }
          }
        }
      }
      .textSelection(.enabled)
    }
    .font(.footnote)
  }

  private func attachments(_ rows: [MailAttachmentRow]) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      IconSectionHeader(icon: Lucide.paperclip, title: L10n.mailAttachments) {
        Text(verbatim: "\(rows.count)")
          .font(.footnote.monospacedDigit())
      }
      VStack(spacing: 0) {
        ForEach(Array(rows.enumerated()), id: \.offset) { index, attachment in
          if index > 0 { Divider().padding(.leading, 46) }
          attachmentRow(attachment)
        }
      }
      .background(
        Color(.secondarySystemGroupedBackground), in: ListGroupShape.card)
    }
  }

  private func attachmentRow(_ attachment: MailAttachmentRow) -> some View {
    Button {
      Task { await model.download(attachment, presenter: app.presenter) }
    } label: {
      HStack(spacing: 12) {
        LucideImage(Lucide.paperclip, size: 20)
          .foregroundStyle(.secondary)
        VStack(alignment: .leading, spacing: 2) {
          Text(attachment.name)
            .foregroundStyle(Color.primary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
          if let meta = attachment.meta {
            Text(meta)
              .font(.footnote.monospacedDigit())
              .foregroundStyle(.secondary)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        Group {
          if model.downloading.contains(attachment.fetchId) {
            ProgressView()
          } else {
            LucideImage(Lucide.download, size: 20)
              .foregroundStyle(Color.tatBrand)
          }
        }
        .frame(width: 44, height: 44)
      }
      .padding(.leading, 14)
      .padding(.trailing, 6)
      .padding(.vertical, 4)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(L10n.mailDownload) \(attachment.name)")
  }

  /// 它講的是 App 做了什麼，不是信的內容，所以自己一張卡、不混進信裡面。
  private var remoteImagesCard: some View {
    HStack(alignment: .top, spacing: 11) {
      LucideImage(Lucide.imageOff, size: 18)
        .foregroundStyle(.secondary)
      VStack(alignment: .leading, spacing: 8) {
        Text(L10n.mailRemoteImagesBlocked)
          .font(.footnote)
        Button(L10n.mailShowImages) { model.showRemoteImages = true }
          .font(.subheadline.weight(.medium))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(14)
    .background(
      Color(.secondarySystemGroupedBackground), in: ListGroupShape.card)
    .padding(.top, 14)
  }

  private var actionBar: some View {
    HStack(spacing: 8) {
      Button {
        compose(.reply)
      } label: {
        Label {
          Text(L10n.mailReply)
        } icon: {
          LucideImage(Lucide.reply, size: 19)
        }
        .frame(maxWidth: .infinity)
      }
      .prominentButtonStyle()
      .controlSize(.large)

      secondary(L10n.mailReplyAll, Lucide.replyAll) { compose(.replyAll) }
      secondary(L10n.mailForward, Lucide.forward) { compose(.forward) }
    }
    .disabled(model.header == nil)
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
  }

  private func secondary(_ label: String, _ icon: LucideIcon, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      LucideImage(icon, size: 20)
        .frame(width: 28, height: 22)
    }
    .buttonStyle(.bordered)
    .controlSize(.large)
    .accessibilityLabel(label)
  }

  private func compose(_ kind: MailComposeKind) {
    composing = MailComposeRequest(kind: kind, ref: model.ref)
  }

  /// 先離開再提示，清單那一頁會重抓。
  private func move(archive: Bool) async {
    guard await model.move(archive: archive, presenter: app.presenter) else { return }
    onMoved()
    dismiss()
    app.presenter.toast(archive ? L10n.mailArchived : L10n.mailMovedToTrash)
  }
}
