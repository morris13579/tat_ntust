import CoreImage.CIFilterBuiltins
import UIKit

enum QRCode {
  /// 黑白、糾錯等級 M，和 Flutter 版一樣。放大時要配 `.interpolation(.none)`，否則邊緣會糊。
  static func image(for text: String) -> UIImage? {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(text.utf8)
    filter.correctionLevel = "M"
    guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
      let cgImage = CIContext().createCGImage(output, from: output.extent)
    else { return nil }
    return UIImage(cgImage: cgImage)
  }
}
