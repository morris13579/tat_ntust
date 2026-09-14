import PhotosUI
import SwiftUI

/// 個人資訊，照 `profile_page.dart`：除了頭貼都是學校端的資料，所以沒有輸入框、也沒有「儲存」。
struct ProfileView: View {
  @Environment(AppEnvironment.self) private var app
  let model: MoreModel
  let openStudentRecord: () -> Void

  @State private var account = ""
  @State private var choosingFrom: AvatarSource?
  @State private var showPhotos = false
  @State private var showCamera = false
  @State private var confirmRemove = false
  @State private var photo: PhotosPickerItem?

  var body: some View {
    List {
      Section {
        VStack(spacing: 12) {
          avatar
          if case .loaded(let profile) = model.profile {
            VStack(spacing: 4) {
              Text(profile.name).font(.title3.weight(.semibold))
              Text(profile.account)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            }
          }
          // 頭貼是唯一可改的東西，所以給它兩個入口：頭貼本身與這顆按鈕。
          Button(L10n.avatarChange) { choosingFrom = .button }
            .buttonStyle(.bordered)
            .disabled(model.changingAvatar)
            .modifier(avatarChoices(.button))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
      }

      if !account.isEmpty {
        // 校內信箱從學號推得出來，不需要另一支 API。
        Section(L10n.contactInfo) {
          LabeledContent(L10n.campusEmail, value: "\(account)@mail.ntust.edu.tw")
        }
      }

      Section {
        HStack(alignment: .top, spacing: 10) {
          LucideImage(Lucide.info, size: 18)
            .foregroundStyle(.secondary)
            .padding(.top, 2)
          VStack(alignment: .leading, spacing: 8) {
            Text(L10n.profileReadOnlyNote)
              .font(.subheadline)
              .foregroundStyle(.secondary)
            Button(L10n.goToStudentRecord, action: openStudentRecord)
              .font(.subheadline.weight(.medium))
          }
        }
      }
    }
    .navigationTitle(L10n.person_info)
    .analyticsScreen("/ProfilePage")
    .navigationBarTitleDisplayMode(.inline)
    .photosPicker(isPresented: $showPhotos, selection: $photo, matching: .images)
    .fullScreenCover(isPresented: $showCamera) {
      CameraPicker { upload($0) }
        .ignoresSafeArea()
    }
    // 移除要確認：它是唯一破壞性的分支，伺服器端直接刪掉舊圖、沒有復原。
    .alert(L10n.avatarRemove, isPresented: $confirmRemove) {
      Button(L10n.cancel, role: .cancel) {}
      Button(L10n.sure, role: .destructive) {
        Task { await change(nil, success: L10n.avatarRemoved) }
      }
    } message: {
      Text(L10n.avatarRemoveConfirm)
    }
    .onChange(of: photo) {
      guard let photo else { return }
      self.photo = nil
      Task {
        guard let data = try? await photo.loadTransferable(type: Data.self),
          let image = UIImage(data: data)
        else {
          app.presenter.toast(L10n.avatarPickerUnavailable, kind: .error)
          return
        }
        upload(image)
      }
    }
    .task { account = (try? await app.core.credentials())?.account ?? "" }
  }

  private var avatar: some View {
    let url: String? = if case .loaded(let profile) = model.profile { profile.avatarUrl } else { nil }
    return ZStack {
      AvatarView(url: url, size: 96)
        .opacity(model.changingAvatar ? 0.5 : 1)
      if model.changingAvatar {
        AvatarProgressRing(value: app.transfers.progress[Self.avatarTransfer]?.progress)
      }
    }
    .overlay(alignment: .bottomTrailing) {
      if !model.changingAvatar {
        // 照 Flutter 版的角標：外圈塗成它站著的那一列的底色，看起來是和頭貼之間的一圈縫，不是框線。
        LucideImage(Lucide.camera, size: 18)
          .foregroundStyle(Color.white)
          .frame(width: 36, height: 36)
          .background(Color.tatBrand, in: Circle())
          .overlay(Circle().strokeBorder(Color(.secondarySystemGroupedBackground), lineWidth: 3))
      }
    }
    .contentShape(Circle())
    .onTapGesture {
      if !model.changingAvatar { choosingFrom = .avatar }
    }
    .accessibilityAddTraits(.isButton)
    .accessibilityLabel(L10n.avatarChange)
    .modifier(avatarChoices(.avatar))
  }

  /// 頭貼本身與「更換頭貼」兩個入口。
  private enum AvatarSource {
    case avatar, button
  }

  /// 選項掛在按下去的那個東西上：iOS 26 的詢問框從掛的地方跳出來，掛在整頁會指到別處。
  private func avatarChoices(_ source: AvatarSource) -> AvatarChoices {
    let canRemove = if case .loaded(let profile) = model.profile { profile.customAvatar } else { false }
    return AvatarChoices(
      isPresented: Binding(get: { choosingFrom == source }, set: { if !$0 { choosingFrom = nil } }),
      canRemove: canRemove,
      takePhoto: { Task { await openCamera() } },
      pickPhoto: { showPhotos = true },
      remove: { confirmRemove = true }
    )
  }

  /// Dart 報頭貼上傳進度用的 key，同 `MoreBridge.changeAvatar`。
  private static let avatarTransfer = "avatar"

  private func openCamera() async {
    if await CameraPicker.requestAccess() {
      showCamera = true
    } else {
      app.presenter.toastPermissionDenied(L10n.avatarCameraDenied)
    }
  }

  /// 頭貼縮到長邊 1024、JPEG 品質 90，同 Flutter 版的 `kAvatarImageMaxEdge`／`kAvatarImageQuality`。
  private func upload(_ image: UIImage) {
    guard let jpeg = image.jpegData(maxEdge: 1024, quality: 0.9) else { return }
    Task { await change(jpeg, success: L10n.avatarUpdated) }
  }

  private func change(_ jpeg: Data?, success: String) async {
    app.transfers.clear(Self.avatarTransfer)
    let message = await model.changeAvatar(jpeg)
    app.transfers.clear(Self.avatarTransfer)
    if let message {
      app.presenter.toast(message, kind: .error)
    } else {
      app.presenter.toast(success, kind: .success)
    }
  }
}

private struct AvatarChoices: ViewModifier {
  @Binding var isPresented: Bool
  let canRemove: Bool
  let takePhoto: () -> Void
  let pickPhoto: () -> Void
  let remove: () -> Void

  func body(content: Content) -> some View {
    content.confirmationDialog(L10n.avatarChange, isPresented: $isPresented, titleVisibility: .hidden) {
      if CameraPicker.isAvailable {
        Button(L10n.avatarTakePhoto, action: takePhoto)
      }
      Button(L10n.avatarFromGallery, action: pickPhoto)
      // 對著預設圖按移除，伺服器會回失敗，看起來像壞掉。
      if canRemove {
        Button(L10n.avatarRemove, role: .destructive, action: remove)
      }
    }
  }
}

/// 頭貼外圈的上傳進度，照 Flutter 版 `UserProfile` 的 `CircularProgressIndicator`：
/// 量得到就照比例畫一圈，還量不到時一段弧繞著轉。
private struct AvatarProgressRing: View {
  let value: Double?

  var body: some View {
    TimelineView(.animation(paused: value != nil)) { context in
      let turn = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1)
      Circle()
        .inset(by: 1.5)
        .trim(from: 0, to: value.map { max(0.02, min($0, 1)) } ?? 0.25)
        .stroke(Color.tatBrand, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .rotationEffect(.degrees((value == nil ? turn * 360 : 0) - 90))
        .animation(.linear(duration: 0.15), value: value)
    }
    .accessibilityHidden(true)
  }
}
