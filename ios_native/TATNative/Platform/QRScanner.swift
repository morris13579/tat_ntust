import AVFoundation
import SwiftUI
import Vision

/// 相機掃 QR，自己開 `AVCaptureSession`：手電筒得開在預覽正在用的那顆鏡頭上。VisionKit 的掃描器不交出它用的鏡頭，
/// 另外去鎖系統預設鏡頭會讓預覽停住。模擬器、沒有相機或拒絕權限時 `isAvailable` 是 false，呼叫端要改給相簿與貼上代碼。
struct QRScannerView: UIViewRepresentable {
  var torch = false
  var onDenied: () -> Void = {}
  var onScan: (String) -> Void

  static var isAvailable: Bool {
    guard QRCapture.device() != nil else { return false }
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .denied, .restricted: return false
    default: return true
    }
  }

  func makeUIView(context: Context) -> PreviewView {
    let view = PreviewView()
    view.previewLayer.videoGravity = .resizeAspectFill
    view.previewLayer.session = context.coordinator.capture.session
    context.coordinator.capture.start(preview: view.previewLayer) { granted in
      if !granted { onDenied() }
    }
    return view
  }

  func updateUIView(_ view: PreviewView, context: Context) {
    context.coordinator.capture.onScan = onScan
    context.coordinator.capture.setTorch(torch)
  }

  static func dismantleUIView(_ view: PreviewView, coordinator: Coordinator) {
    coordinator.capture.stop()
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  @MainActor
  final class Coordinator {
    let capture = QRCapture()
  }

  final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
  }
}

/// 鏡頭的設定、開關與手電筒都排在同一條佇列：`startRunning` 會卡住呼叫它的執行緒。
final class QRCapture: NSObject, AVCaptureMetadataOutputObjectsDelegate, @unchecked Sendable {
  let session = AVCaptureSession()
  @MainActor var onScan: (String) -> Void = { _ in }
  private let queue = DispatchQueue(label: "club.ntust.tat.qr-capture")
  private var device: AVCaptureDevice?
  private var torchOn = false
  private var stopped = false

  /// 有超廣角的機型用虛擬鏡頭：拿近看的時候系統會自己換到對得到焦的那顆，跟內建相機一樣。
  static func device() -> AVCaptureDevice? {
    AVCaptureDevice.DiscoverySession(
      deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInWideAngleCamera],
      mediaType: .video,
      position: .back
    ).devices.first
  }

  @MainActor
  func start(preview: AVCaptureVideoPreviewLayer, onAccess: @escaping @MainActor (Bool) -> Void) {
    Task {
      let granted = await AVCaptureDevice.requestAccess(for: .video)
      onAccess(granted)
      guard granted else { return }
      queue.async { [self, weak preview] in
        guard !stopped else { return }
        if device == nil { configure() }
        session.startRunning()
        applyTorch()
        DispatchQueue.main.async {
          // App 只有直式；後鏡頭的原始方向是橫的。
          guard let connection = preview?.connection, connection.isVideoRotationAngleSupported(90) else { return }
          connection.videoRotationAngle = 90
        }
      }
    }
  }

  func setTorch(_ on: Bool) {
    queue.async { [self] in
      torchOn = on
      applyTorch()
    }
  }

  func stop() {
    queue.async { [self] in
      stopped = true
      torchOn = false
      applyTorch()
      session.stopRunning()
      // 輸出端若握著 delegate，session 與這個物件會互相留住。
      for case let output as AVCaptureMetadataOutput in session.outputs {
        output.setMetadataObjectsDelegate(nil, queue: nil)
      }
    }
  }

  private func configure() {
    guard let device = Self.device(), let input = try? AVCaptureDeviceInput(device: device) else { return }
    session.beginConfiguration()
    if session.canSetSessionPreset(.high) { session.sessionPreset = .high }
    if session.canAddInput(input) { session.addInput(input) }
    let output = AVCaptureMetadataOutput()
    if session.canAddOutput(output) {
      session.addOutput(output)
      output.setMetadataObjectsDelegate(self, queue: .main)
      output.metadataObjectTypes = output.availableMetadataObjectTypes.contains(.qr) ? [.qr] : []
    }
    session.commitConfiguration()
    if (try? device.lockForConfiguration()) != nil {
      // 虛擬鏡頭的 1 倍是超廣角，放大到切換點才是一般相機的畫面。
      if let wide = device.virtualDeviceSwitchOverVideoZoomFactors.first {
        device.videoZoomFactor = CGFloat(truncating: wide)
      }
      if device.isAutoFocusRangeRestrictionSupported { device.autoFocusRangeRestriction = .near }
      device.unlockForConfiguration()
    }
    self.device = device
  }

  /// 手電筒要等畫面跑起來才開得了；還沒跑就先記著，開始時補開。
  private func applyTorch() {
    guard session.isRunning, let device, device.hasTorch, device.isTorchModeSupported(.on) else { return }
    let mode: AVCaptureDevice.TorchMode = torchOn ? .on : .off
    guard device.torchMode != mode, (try? device.lockForConfiguration()) != nil else { return }
    device.torchMode = mode
    device.unlockForConfiguration()
  }

  func metadataOutput(
    _ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection
  ) {
    guard let value = metadataObjects.compactMap({ ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }).first
    else { return }
    MainActor.assumeIsolated { onScan(value) }
  }
}

enum QRImageReader {
  /// 從一張圖裡讀 QR，讀不到回 nil。
  static func read(_ data: Data) async -> String? {
    await Task.detached(priority: .userInitiated) {
      guard let image = CIImage(data: data) else { return nil }
      let request = VNDetectBarcodesRequest()
      request.symbologies = [.qr]
      try? VNImageRequestHandler(ciImage: image).perform([request])
      return request.results?.compactMap(\.payloadStringValue).first
    }.value
  }
}
