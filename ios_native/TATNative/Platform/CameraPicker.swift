import AVFoundation
import SwiftUI
import UIKit

/// 系統相機拍一張照片。
struct CameraPicker: UIViewControllerRepresentable {
  let onPicked: (UIImage) -> Void
  @Environment(\.dismiss) private var dismiss

  static var isAvailable: Bool {
    UIImagePickerController.isSourceTypeAvailable(.camera)
  }

  /// 還沒問過就先問；拒絕過或被限制時回 false，呼叫端照 Flutter 版提示去設定打開。
  static func requestAccess() async -> Bool {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized: return true
    case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
    default: return false
    }
  }

  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.delegate = context.coordinator
    return picker
  }

  func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let parent: CameraPicker

    init(_ parent: CameraPicker) {
      self.parent = parent
    }

    func imagePickerController(
      _ picker: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
      if let image = info[.originalImage] as? UIImage { parent.onPicked(image) }
      parent.dismiss()
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      parent.dismiss()
    }
  }
}

extension UIImage {
  /// 長邊縮到 [maxEdge] 以內再壓成 JPEG。
  func jpegData(maxEdge: CGFloat, quality: CGFloat) -> Data? {
    let longest = max(size.width, size.height)
    let scale = longest > maxEdge ? maxEdge / longest : 1
    let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
      draw(in: CGRect(origin: .zero, size: target))
    }
    return resized.jpegData(compressionQuality: quality)
  }
}
