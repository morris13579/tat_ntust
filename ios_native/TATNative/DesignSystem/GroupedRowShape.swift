import SwiftUI

/// 一組相連的列：頭尾收成分組的圓角、中間只留小圓角，列與列之間留 2pt 的縫，照 Flutter 版的 `UIUtils.getBorderRadius`。
struct GroupedRowShape: Shape {
  let index: Int
  let count: Int

  func path(in rect: CGRect) -> Path {
    let outer = ListGroupShape.cornerRadius
    let inner: CGFloat = 4
    let top = index == 0 ? outer : inner
    let bottom = index == count - 1 ? outer : inner
    return UnevenRoundedRectangle(
      topLeadingRadius: top, bottomLeadingRadius: bottom,
      bottomTrailingRadius: bottom, topTrailingRadius: top, style: .continuous
    )
    .path(in: rect)
  }
}

/// 分組的圓角。系統分組清單、自製的分組列、卡片與內容裡裁成卡片的通知條都用這一個，整個 App 是同一種圓；
/// 排在清單裡的自製卡片更要一樣：貼著分組邊緣的那幾個角會被清單裁成它的弧度，不一樣就會一張卡兩種角。
enum ListGroupShape {
  static var cornerRadius: CGFloat {
    if #available(iOS 26, *) { return 26 }
    return 10
  }

  static var card: RoundedRectangle {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
  }
}
