import SwiftUI

/// 核心要求的對話框，用系統的 `.alert`、`.confirmationDialog` 與 sheet 畫。
/// 掛在 root view 上：`run()` 在任何一頁都可能問重試。
struct CoreDialogs: ViewModifier {
  @Bindable var presenter: UiPresenter

  func body(content: Content) -> some View {
    content
      .alert(
        item: $presenter.dialog,
        title: { $0.request.title ?? L10n.alertError },
        actions: { dialog in
          let request = dialog.request
          if !request.hideOk {
            if request.offerLoginScreen {
              // 和 Flutter 版一樣把主鈕換成登入頁的入口；登入頁關掉後回報 retry，
              // 使用者剛修正了讓它失敗的原因。
              Button(L10n.setting) {
                presenter.requestLogin { dialog.completion(.retry) }
              }
            } else {
              Button(request.okText ?? L10n.restart, role: request.destructive ? .destructive : nil) {
                dialog.completion(.retry)
              }
            }
          }
          if !request.hideCancel {
            Button(request.cancelText ?? L10n.cancel, role: .cancel) {
              dialog.completion(.giveUp)
            }
          }
        },
        message: { dialog in
          Text(dialog.request.offerLoginScreen ? L10n.credentialRejectedDesc : dialog.request.desc)
        }
      )
      .confirmationDialog(
        item: $presenter.chooser,
        title: { $0.title },
        actions: { chooser in
          ForEach(chooser.options, id: \.value) { option in
            Button(option.label) { chooser.completion(option.value) }
          }
          // 取消一定要回 nil，不可以自己挑一個頂替。
          Button(L10n.cancel, role: .cancel) { chooser.completion(nil) }
        }
      )
      .sheet(item: $presenter.semesterRequest) { request in
        SemesterPicker(request: request)
      }
      .sheet(item: $presenter.webSession) { session in
        WebLoginSheet(session: session, presenter: presenter)
      }
  }
}

private extension View {
  func alert<Item: Identifiable, A: View, M: View>(
    item: Binding<Item?>,
    title: @escaping (Item) -> String,
    @ViewBuilder actions: @escaping (Item) -> A,
    @ViewBuilder message: @escaping (Item) -> M
  ) -> some View {
    alert(
      item.wrappedValue.map(title) ?? "",
      isPresented: Binding(
        get: { item.wrappedValue != nil },
        set: { if !$0 { item.wrappedValue = nil } }
      ),
      presenting: item.wrappedValue,
      actions: actions,
      message: message
    )
  }

  func confirmationDialog<Item: Identifiable, A: View>(
    item: Binding<Item?>,
    title: @escaping (Item) -> String,
    @ViewBuilder actions: @escaping (Item) -> A
  ) -> some View {
    confirmationDialog(
      item.wrappedValue.map(title) ?? "",
      isPresented: Binding(
        get: { item.wrappedValue != nil },
        set: { if !$0 { item.wrappedValue = nil } }
      ),
      titleVisibility: .visible,
      presenting: item.wrappedValue,
      actions: actions
    )
  }
}

extension View {
  /// 掛上核心要求的對話框與提示。
  func coreUi(_ presenter: UiPresenter) -> some View {
    modifier(CoreDialogs(presenter: presenter))
      .overlay(ToastOverlay(presenter: presenter))
      .overlay(alignment: .top) { BannerOverlay(presenter: presenter) }
  }
}
