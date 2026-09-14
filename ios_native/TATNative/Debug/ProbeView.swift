import SwiftUI

/// E4 的判準畫面。正式主畫面做出來之後連同 ProbeModel 一起刪掉，所以字串不走 l10n。
struct ProbeView: View {
  @Environment(AppEnvironment.self) private var app
  @State private var model: ProbeModel

  init(model: ProbeModel) {
    _model = State(initialValue: model)
  }

  var body: some View {
    NavigationStack {
      List {
        Section("核心狀態") {
          switch model.status {
          case .idle: Text(verbatim: "尚未讀取").foregroundStyle(.secondary)
          case .running: ProgressView()
          case .failed(let message): Text(verbatim: message).foregroundStyle(.red)
          case .ok(let s):
            row("憑證狀態", s.credentials)
            row("帳號", s.account.isEmpty ? "（空字串）" : s.account)
            row("Moodle token", s.hasMoodleToken ? "有" : "沒有")
            row("課表筆數", "\(s.courseTableCount)")
            row("語系設定", s.locale)
          }
        }

        Section("課表") {
          switch model.courseTable {
          case .idle: Text(verbatim: "尚未載入").foregroundStyle(.secondary)
          case .running: ProgressView()
          case .failed(let message): Text(verbatim: "邊界錯誤：\(message)").foregroundStyle(.red)
          case .ok(.ok(let table)): courseTable(table, staleReason: nil)
          case .ok(.stale(let table, let reason)): courseTable(table, staleReason: reason)
          case .ok(.failed(let reason)): failure(reason)
          }
        }

        Section("成績") {
          switch model.score {
          case .idle: Text(verbatim: "尚未載入").foregroundStyle(.secondary)
          case .running: ProgressView()
          case .failed(let message): Text(verbatim: "邊界錯誤：\(message)").foregroundStyle(.red)
          case .ok(.ok(let summary)): scoreSummary(summary, staleReason: nil)
          case .ok(.stale(let summary, let reason)): scoreSummary(summary, staleReason: reason)
          case .ok(.failed(let reason)): failure(reason)
          }
        }

        Section("WebHost（不經過 Dart、不需登入）") {
          switch model.webHostProbe {
          case .idle: Text(verbatim: "尚未測試").foregroundStyle(.secondary)
          case .running: ProgressView()
          case .failed(let message): Text(verbatim: message).foregroundStyle(.red)
          case .ok(let message): Text(verbatim: message).font(.footnote)
          }
        }

        Section("互動式登入（可見的 WebView）") {
          switch model.interactiveSignIn {
          case .idle: Text(verbatim: "尚未測試").foregroundStyle(.secondary)
          case .running: ProgressView()
          case .failed(let message): Text(verbatim: message).foregroundStyle(.red)
          case .ok(let message): Text(verbatim: message)
          }
          Button("SSO 登入頁") { Task { await model.signIn(moodle: false) } }
          Button("Moodle 登入頁") { Task { await model.signIn(moodle: true) } }
        }

        Section {
          Button("讀取核心狀態") { Task { await model.loadStatus() } }
          Button("載入課表") { Task { await model.loadCourseTable() } }
          Button("載入成績") { Task { await model.loadScore() } }
          Button("直接測 WebHost") { model.probeWebHost() }
        }

        Section("UI 層（不繞網路）") {
          let presenter = app.presenter
          Button("登入頁") { presenter.requestLogin() }
          Button("提示") { presenter.toast("已複製課表代碼") }
          Button("錯誤提示") { presenter.toast("連不上學校的伺服器", kind: .error) }
          Button("進度框三秒") {
            let handle = presenter.beginProgress("取得課表中…")
            Task {
              try? await Task.sleep(for: .seconds(3))
              presenter.dismissProgress(handle)
            }
          }
          Button("重試對話框") {
            presenter.ask(ErrorDialogRequest(
              desc: "取得課表失敗，要再試一次嗎？",
              title: "課表",
              destructive: false,
              hideOk: false,
              hideCancel: false,
              offerLoginScreen: false
            )) { NSLog("[probe] 使用者選了 \($0)") }
          }
          Button("帳密被拒對話框") {
            presenter.ask(ErrorDialogRequest(
              desc: "",
              destructive: false,
              hideOk: false,
              hideCancel: false,
              offerLoginScreen: true
            )) { NSLog("[probe] 使用者選了 \($0)") }
          }
          Button("手動選學期") {
            presenter.chooseSemester(allowNull: false) { NSLog("[probe] 學期 \(String(describing: $0))") }
          }
          Button("單選") {
            presenter.choose(
              title: "選一個學期",
              options: [
                ChooseOption(label: "115 學年第 1 學期", value: "115-1"),
                ChooseOption(label: "114 學年第 2 學期", value: "114-2"),
              ]
            ) { NSLog("[probe] 選了 \(String(describing: $0))") }
          }
        }
      }
      .navigationTitle(Text(verbatim: "TAT Core"))
    }
  }

  @ViewBuilder
  private func courseTable(_ table: CourseTable, staleReason: CoreFailureKind?) -> some View {
    if let reason = staleReason {
      Text(verbatim: "這是舊資料（\(describe(reason))）").foregroundStyle(.orange)
    }
    row("學號", table.studentId)
    row("學期", table.semester)
    row("課程格數", "\(table.cells.count)")
    ForEach(table.cells.prefix(8), id: \.courseId) { cell in
      row("\(cell.day) \(cell.section)", cell.courseName)
    }
  }

  @ViewBuilder
  private func scoreSummary(_ s: ScoreSummary, staleReason: CoreFailureKind?) -> some View {
    if let reason = staleReason {
      Text(verbatim: "這是舊資料（\(describe(reason))）").foregroundStyle(.orange)
    }
    row("學期數", "\(s.semesterCount)")
    row("科目數", "\(s.itemCount)")
    row("最近學期", s.latestSemester ?? "—")
  }

  @ViewBuilder
  private func failure(_ reason: CoreFailureKind) -> some View {
    Text(verbatim: describe(reason)).foregroundStyle(.red)
    Text(verbatim: reason.retryable ? "可以重試" : "重試沒有意義").font(.caption).foregroundStyle(.secondary)
  }

  private func describe(_ reason: CoreFailureKind) -> String {
    switch reason {
    case .offline: "連不上網路"
    case .notSignedIn: "尚未登入"
    case .loginFailed(let detail): detail ?? "登入失敗"
    case .fetchFailed(let detail): detail ?? "取得資料失敗"
    case .unsupportedCourse: "這門課沒有對應"
    }
  }

  private func row(_ label: String, _ value: String) -> some View {
    HStack(alignment: .top) {
      Text(verbatim: label).foregroundStyle(.secondary)
      Spacer(minLength: 12)
      Text(verbatim: value).multilineTextAlignment(.trailing)
    }
  }
}
