import SwiftUI

/// 信箱分頁，照 `MailPage`：還沒設定信箱密碼先畫設定頁，設定好了才是信件清單。
struct MailView: View {
  @Environment(AppEnvironment.self) private var app
  @State private var model: MailListModel
  @Binding var openMail: MailArrival?
  @State private var path: [MailRoute] = []
  @State private var composing: MailComposeRequest?

  init(model: MailListModel, openMail: Binding<MailArrival?>) {
    _model = State(initialValue: model)
    _openMail = openMail
  }

  var body: some View {
    NavigationStack(path: $path) {
      content
        .navigationDestination(for: MailRoute.self) { route in
          switch route {
          case .message(let ref):
            MailDetailView(model: MailDetailModel(client: app.mail, ref: ref)) {
              Task { await model.reload() }
            }
          }
        }
    }
    .sheet(item: $composing) { request in
      MailComposeView(model: MailComposeModel(client: app.mail, kind: request.kind, ref: request.ref)) {
        Task { await model.reload() }
      }
    }
    .task { await model.begin() }
    .onChange(of: openMail, initial: true) { consumeOpenMail() }
    .onChange(of: model.configured) { consumeOpenMail() }
    .onChange(of: model.state?.needsSetup) { _, needs in
      if needs == true { model.lostSetup() }
    }
  }

  @ViewBuilder private var content: some View {
    if let status = model.status {
      if model.configured {
        MailListView(model: model) { row in
          model.markSeen(row)
          path.append(.message(ref: row.ref))
        } onCompose: {
          composing = MailComposeRequest(kind: .blank, ref: "")
        }
      } else {
        MailSetupView(address: status.address, client: app.mail) {
          Task { await model.setupDone() }
        }
      }
    } else {
      ProgressView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
  }

  /// 和從清單點進去一樣標成已讀，照 `MainScreen._openMail`。
  private func consumeOpenMail() {
    guard let arrival = openMail, model.configured else { return }
    openMail = nil
    Task { try? await app.mail.markMessageSeen(ref: arrival.ref) }
    path = [.message(ref: arrival.ref)]
  }
}

enum MailRoute: Hashable {
  case message(ref: String)
}

struct MailComposeRequest: Identifiable {
  let id = UUID()
  let kind: MailComposeKind
  let ref: String
}
