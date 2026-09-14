import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// 附件從哪裡來。
enum AttachmentSource {
  case camera, photos, files
}

extension View {
  /// 問附件從哪裡來，照 `pickForumAttachments`。只留檔案挑選器的話，剛拍的白板照片在「檔案」裡看不到，
  /// 相機更是完全沒有入口。掛在迴紋針按鈕上：iOS 26 的詢問框從掛的地方跳出來。
  func attachmentSourceDialog(isPresented: Binding<Bool>, onChoose: @escaping (AttachmentSource) -> Void) -> some View {
    modifier(AttachmentSourceDialog(isPresented: isPresented, onChoose: onChoose))
  }

  /// 選好來源之後的挑選器，掛在整頁上。
  func forumAttachmentPicker(
    source: Binding<AttachmentSource?>, remaining: Int, onPicked: @escaping ([String]) -> Void
  ) -> some View {
    modifier(ForumAttachmentPicker(source: source, remaining: remaining, onPicked: onPicked))
  }
}

/// 選相機時先問權限：拒絕過就照 Flutter 版提示去設定打開，不開一個黑畫面的相機。
private struct AttachmentSourceDialog: ViewModifier {
  @Environment(AppEnvironment.self) private var app
  @Binding var isPresented: Bool
  let onChoose: (AttachmentSource) -> Void

  func body(content: Content) -> some View {
    content.confirmationDialog(L10n.forumAddAttachment, isPresented: $isPresented, titleVisibility: .visible) {
      if CameraPicker.isAvailable {
        Button(L10n.forumAttachFromCamera) {
          Task {
            if await CameraPicker.requestAccess() {
              onChoose(.camera)
            } else {
              app.presenter.toastPermissionDenied(L10n.avatarCameraDenied)
            }
          }
        }
      }
      Button(L10n.forumAttachFromGallery) { onChoose(.photos) }
      Button(L10n.forumAttachFromFiles) { onChoose(.files) }
      Button(L10n.cancel, role: .cancel) {}
    }
  }
}

private struct ForumAttachmentPicker: ViewModifier {
  @Environment(AppEnvironment.self) private var app
  @Binding var source: AttachmentSource?
  let remaining: Int
  let onPicked: ([String]) -> Void
  @State private var photoItems: [PhotosPickerItem] = []

  func body(content: Content) -> some View {
    content
      .fullScreenCover(isPresented: showing(.camera)) {
        CameraPicker { image in
          if let path = PickedFiles.save(image, name: "camera-\(Self.stamp()).jpg") { onPicked([path]) }
        }
        .ignoresSafeArea()
      }
      .photosPicker(
        isPresented: showing(.photos), selection: $photoItems, maxSelectionCount: max(1, remaining), matching: .images
      )
      .onChange(of: photoItems) {
        Task { await loadPhotos() }
      }
      .fileImporter(isPresented: showing(.files), allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
        // iOS 的相簿與檔案選擇器不必授權；打不開或讀不進來時照 Flutter 版說「現在無法開啟」。
        guard case .success(let urls) = result else {
          app.presenter.toast(L10n.assignFilePickerUnavailable, kind: .error)
          return
        }
        let paths = PickedFiles.copy(urls)
        if paths.count < urls.count { app.presenter.toast(L10n.assignFilePickerUnavailable, kind: .error) }
        if !paths.isEmpty { onPicked(paths) }
      }
  }

  private func showing(_ kind: AttachmentSource) -> Binding<Bool> {
    Binding(get: { source == kind }, set: { if !$0 { source = nil } })
  }

  /// 刻意不縮圖：白板照片縮到長邊 1024 就讀不出字了。
  private func loadPhotos() async {
    let items = photoItems
    guard !items.isEmpty else { return }
    photoItems = []
    let stamp = Self.stamp()
    var paths: [String] = []
    for (index, item) in items.enumerated() {
      guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
      let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.9) ?? data
      if let path = PickedFiles.save(jpeg, name: "photo-\(stamp)-\(index + 1).jpg") { paths.append(path) }
    }
    if paths.count < items.count { app.presenter.toast(L10n.avatarPickerUnavailable, kind: .error) }
    if !paths.isEmpty { onPicked(paths) }
  }

  private static func stamp() -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    return formatter.string(from: Date())
  }
}
