import PhotosUI
import SwiftUI

/// 掃描他人課表，照 `scan_table_page.dart`：相機、從相簿選、貼上代碼三條路。
/// 掃到的字串交給呼叫端判斷——認不得就留在這一頁繼續掃。
struct ScanTableView: View {
  let onCode: (String) -> Void

  @State private var torchOn = false
  @State private var cameraAllowed = QRScannerView.isAvailable
  @State private var photo: PhotosPickerItem?
  @State private var pasting = false
  @State private var pasted = ""
  @State private var lastCode: String?

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        camera
        if !cameraAllowed {
          Text(L10n.scanTableHint)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        HStack(spacing: 10) {
          PhotosPicker(selection: $photo, matching: .images) {
            action(Lucide.image, L10n.scanTableGallery)
          }
          Button { pasting = true } label: {
            action(Lucide.clipboard, L10n.scanTablePaste)
          }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)

        if cameraAllowed {
          Button {
            torchOn.toggle()
          } label: {
            action(Lucide.flashlight, L10n.scanTableTorch)
          }
          .buttonStyle(.bordered)
          .controlSize(.large)
          .tint(torchOn ? Color.tatBrand : Color.secondary)
        }

        HStack(alignment: .firstTextBaseline, spacing: 8) {
          LucideImage(Lucide.info, size: 14)
            .alignedToFirstTextLine(.footnote)
          Text(L10n.scanTableNote).frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
      }
      .padding(20)
    }
    .navigationTitle(L10n.scanTableTitle)
    .analyticsScreen("/ScanTablePage")
    .navigationBarTitleDisplayMode(.inline)
    .onChange(of: photo) {
      guard let photo else { return }
      Task {
        let data = try? await photo.loadTransferable(type: Data.self)
        let code = if let data { await QRImageReader.read(data) } else { String?.none }
        deliver(code ?? "")
        self.photo = nil
      }
    }
    .alert(L10n.scanTablePaste, isPresented: $pasting) {
      TextField(L10n.scanTablePasteHint, text: $pasted)
      Button(L10n.cancel, role: .cancel) { pasted = "" }
      Button(L10n.sure) {
        deliver(pasted)
        pasted = ""
      }
    }
  }

  @ViewBuilder private var camera: some View {
    Group {
      if cameraAllowed {
        // 同一張 QR 會一直被認到，同一個字串只交一次。
        QRScannerView(torch: torchOn, onDenied: { cameraAllowed = false }) { code in
          guard code != lastCode else { return }
          lastCode = code
          onCode(code)
        }
        .overlay { ScanFrameOverlay(hint: L10n.scanTableHint) }
      } else {
        ContentUnavailableView {
          Label {
            Text(L10n.scanTablePermission)
          } icon: {
            LucideImage(Lucide.cameraOff, size: 40)
          }
        }
        .background(Color(.secondarySystemBackground))
      }
    }
    .aspectRatio(1, contentMode: .fit)
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
  }

  private func action(_ icon: LucideIcon, _ title: String) -> some View {
    Label {
      Text(title)
    } icon: {
      LucideImage(icon, size: 18)
    }
    .frame(maxWidth: .infinity)
  }

  private func deliver(_ code: String) {
    lastCode = code
    onCode(code)
  }
}

/// 取景框，照 Flutter 版 `_ScanFramePainter`：外面壓一層暗色、中間挖出圓角方框、四角畫括號，框下面放提示。
private struct ScanFrameOverlay: View {
  let hint: String

  private static let radius: CGFloat = 20
  private static let arm: CGFloat = 26

  var body: some View {
    GeometryReader { proxy in
      let side = min(min(proxy.size.width, proxy.size.height) * 0.62, 280)
      let frame = CGRect(
        x: (proxy.size.width - side) / 2, y: (proxy.size.height - side) / 2, width: side, height: side)
      ZStack(alignment: .topLeading) {
        Canvas { context, size in
          var scrim = Path(CGRect(origin: .zero, size: size))
          scrim.addRoundedRect(in: frame, cornerSize: CGSize(width: Self.radius, height: Self.radius))
          context.fill(scrim, with: .color(.black.opacity(0.45)), style: FillStyle(eoFill: true))
          context.stroke(
            Self.brackets(frame), with: .color(Self.bright), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        Text(hint)
          .font(.subheadline)
          .foregroundStyle(Self.bright)
          .multilineTextAlignment(.center)
          .frame(width: max(proxy.size.width - 48, 0))
          .offset(x: 24, y: frame.maxY + 16)
      }
    }
    .allowsHitTesting(false)
  }

  /// 相機畫面不是 App 的底色：框線取品牌色的色相、拉到很亮，壓在深色影像上才看得見。
  private static var bright: Color {
    var hue: CGFloat = 0
    var saturation: CGFloat = 0
    var brightness: CGFloat = 0
    var alpha: CGFloat = 0
    UIColor(Color.tatBrand).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
    return Color(hue: hue, saturation: 0.15, brightness: 0.97)
  }

  private static func brackets(_ f: CGRect) -> Path {
    let r = radius
    let a = arm
    var path = Path()
    path.move(to: CGPoint(x: f.minX, y: f.minY + r + a))
    path.addLine(to: CGPoint(x: f.minX, y: f.minY + r))
    path.addArc(
      center: CGPoint(x: f.minX + r, y: f.minY + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270),
      clockwise: false)
    path.addLine(to: CGPoint(x: f.minX + r + a, y: f.minY))
    path.move(to: CGPoint(x: f.maxX - r - a, y: f.minY))
    path.addLine(to: CGPoint(x: f.maxX - r, y: f.minY))
    path.addArc(
      center: CGPoint(x: f.maxX - r, y: f.minY + r), radius: r, startAngle: .degrees(270), endAngle: .degrees(360),
      clockwise: false)
    path.addLine(to: CGPoint(x: f.maxX, y: f.minY + r + a))
    path.move(to: CGPoint(x: f.maxX, y: f.maxY - r - a))
    path.addLine(to: CGPoint(x: f.maxX, y: f.maxY - r))
    path.addArc(
      center: CGPoint(x: f.maxX - r, y: f.maxY - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90),
      clockwise: false)
    path.addLine(to: CGPoint(x: f.maxX - r - a, y: f.maxY))
    path.move(to: CGPoint(x: f.minX + r + a, y: f.maxY))
    path.addLine(to: CGPoint(x: f.minX + r, y: f.maxY))
    path.addArc(
      center: CGPoint(x: f.minX + r, y: f.maxY - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180),
      clockwise: false)
    path.addLine(to: CGPoint(x: f.minX, y: f.maxY - r - a))
    return path
  }
}
