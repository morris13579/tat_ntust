import SwiftUI
import UIKit

/// 進主畫面時要做的三件事，照 `main.dart` 的 `onReady` 與 `UpdatePrompt`：要通知權限、跳 TAT 公告、問要不要更新。
/// 一件接一件，畫面上不會同時疊兩個。
struct LaunchNotices: ViewModifier {
  @Environment(AppEnvironment.self) private var app
  @State private var announcement: LaunchAnnouncement?
  @State private var update: UpdateOffer?
  @State private var started = false

  func body(content: Content) -> some View {
    content
      .task {
        guard !started else { return }
        started = true
        await app.push.requestAuthorization()
        if let launch = try? await app.appNotice.launchAnnouncement(test: false) {
          announcement = launch
        } else {
          await offerUpdate()
        }
      }
      .sheet(
        isPresented: Binding(get: { announcement != nil }, set: { if !$0 { announcement = nil } }),
        onDismiss: { Task { await offerUpdate() } }
      ) {
        if let launch = announcement {
          NavigationStack {
            AnnouncementView(notices: launch.notices, countDown: Int(launch.countDown), showClose: true)
          }
        }
      }
      .updateAlert($update) { Task { try? await app.appNotice.ignoreUpdate() } }
  }

  private func offerUpdate() async {
    update = try? await app.appNotice.updateOffer(manual: false)
  }
}
