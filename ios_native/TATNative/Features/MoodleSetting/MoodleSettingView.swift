import SwiftUI

@MainActor
@Observable
final class MoodleSettingModel {
  private(set) var settings: MoodleSettings?
  private(set) var failed = false
  private(set) var toggling = false
  /// 目前看的通知方式。
  var processor: String?
  private let client: MoodleSettingClient

  init(client: MoodleSettingClient) {
    self.client = client
  }

  func load() async {
    failed = false
    settings = try? await client.load()
    failed = settings == nil
    if let settings, !settings.processors.contains(where: { $0.name == processor }) {
      processor = settings.processors.first?.name
    }
  }

  /// 回傳 false 代表寫入失敗。
  func toggle(_ setting: MoodleNotifySetting, on: Bool) async -> Bool {
    guard let processor, !toggling else { return true }
    toggling = true
    defer { toggling = false }
    guard let updated = try? await client.toggle(key: setting.key, processor: processor, enabled: on) else {
      return false
    }
    settings = updated
    return true
  }
}

/// Moodle 通知設定，照 `moodle_setting_page.dart`：上面切通知方式，底下每一項一個開關。
/// 寫入期間所有開關停用：寫入是送出整份清單再重抓，兩個請求交錯的話後送的會蓋掉前一個。
struct MoodleSettingView: View {
  @Environment(AppEnvironment.self) private var app
  @State private var model: MoodleSettingModel

  init(model: MoodleSettingModel) {
    _model = State(initialValue: model)
  }

  var body: some View {
    content
      // 載入與失敗時不是清單，底色補上清單的灰，載完才不會從白閃成灰。
      .background(Color(.systemGroupedBackground))
      .navigationTitle(L10n.moodle_setting)
      .analyticsScreen("/MoodleSettingPage")
      .navigationBarTitleDisplayMode(.inline)
      .task {
        if model.settings == nil { await model.load() }
      }
  }

  @ViewBuilder private var content: some View {
    if let settings = model.settings {
      List {
        if settings.processors.count > 1 {
          Picker(L10n.moodle_setting, selection: $model.processor) {
            ForEach(settings.processors, id: \.name) { processor in
              Text(processor.displayName).tag(Optional(processor.name))
            }
          }
          .pickerStyle(.segmented)
          .listRowInsets(EdgeInsets())
          .listRowBackground(Color.clear)
        }
        ForEach(Array(settings.groups.enumerated()), id: \.offset) { _, group in
          Section(group.name) {
            ForEach(group.settings, id: \.key) { setting in
              Toggle(setting.name, isOn: binding(setting))
                .disabled(model.toggling)
            }
          }
        }
      }
      .contentMargins(.top, 16, for: .scrollContent)
    } else if model.failed {
      ContentUnavailableView {
        Label {
          Text(L10n.somethingError)
        } icon: {
          LucideImage(Lucide.triangleAlert, size: 44)
        }
      } actions: {
        Button(L10n.restart) { Task { await model.load() } }
          .prominentButtonStyle()
      }
    } else {
      ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func binding(_ setting: MoodleNotifySetting) -> Binding<Bool> {
    Binding(
      get: { model.processor.map(setting.enabled.contains) ?? false },
      set: { on in
        Task {
          let ok = await model.toggle(setting, on: on)
          if !ok { app.presenter.toast(L10n.somethingError, kind: .error) }
        }
      })
  }
}
