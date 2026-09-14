import SwiftUI

/// 主題顏色：幾個預設色加上自訂。點了馬上套用，存進核心的設定。
struct ThemeColorSheet: View {
  let model: MoreModel

  private struct Preset {
    let name: String
    let seed: Int64?
  }

  private static var presets: [Preset] {
    [
      Preset(name: L10n.themeColorBlue, seed: nil),
      Preset(name: L10n.themeColorPurple, seed: 0xFF7E_57C2),
      Preset(name: L10n.themeColorPink, seed: 0xFFD8_1B60),
      Preset(name: L10n.themeColorRed, seed: 0xFFE5_3935),
      Preset(name: L10n.themeColorOrange, seed: 0xFFF4_511E),
      Preset(name: L10n.themeColorGreen, seed: 0xFF43_A047),
      Preset(name: L10n.themeColorTeal, seed: 0xFF00_897B),
      Preset(name: L10n.themeColorGraphite, seed: 0xFF60_7D8B),
    ]
  }

  var body: some View {
    SheetStack(title: L10n.themeColor) {
      List {
        Section {
          LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 16) {
            ForEach(Self.presets, id: \.name) { swatch($0) }
          }
          .padding(.vertical, 8)
        }
        Section {
          ColorPicker(L10n.themeColorCustom, selection: custom, supportsOpacity: false)
        } footer: {
          Text(L10n.themeColorNote)
        }
      }
    }
  }

  private func swatch(_ preset: Preset) -> some View {
    let selected = BrandPalette.shared.seed == preset.seed
    return Button {
      model.setThemeColor(preset.seed)
    } label: {
      VStack(spacing: 6) {
        Circle()
          .fill(BrandPalette.color(for: preset.seed))
          .frame(width: 44, height: 44)
          .overlay {
            if selected {
              LucideImage(Lucide.check, size: 22).foregroundStyle(.white)
            }
          }
        Text(preset.name)
          .font(.caption)
          .foregroundStyle(selected ? Color.primary : Color.secondary)
      }
      .frame(maxWidth: .infinity)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(preset.name)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  /// 拖選擇器時一路套用；寫進設定由 `MoreModel` 等停下來才寫。
  private var custom: Binding<Color> {
    Binding(
      get: { BrandPalette.shared.seedColor ?? Color.tatBrand },
      set: { model.setThemeColor(BrandPalette.argb(of: $0)) }
    )
  }
}
