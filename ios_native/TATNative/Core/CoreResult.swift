import Foundation

/// Pigeon 的 sealed class 在 Swift 產生成「空的 protocol + 一堆 struct」，
/// 所以 `switch` 只能用 `case let x as Foo` 加 `default`——**沒有編譯器強制的
/// 窮盡比對**。Dart 那一側是 sealed class，少一個分支編譯不過；Swift 這一側
/// 少一個分支只會在執行期安靜地走進 default。
///
/// 這個檔案的用途就是把那個落差收斂成**唯一一處**：邊界一拿到結果就換成真正的
/// Swift enum，之後所有畫面都在 enum 上 switch，重新拿回窮盡檢查。
enum CoreResult<T> {
  case ok(T)
  /// 沒抓到新資料，但快取讀得回來。**畫面必須標示這是舊資料。**
  case stale(T, CoreFailureKind)
  case failed(CoreFailureKind)

  var data: T? {
    switch self {
    case .ok(let d): return d
    case .stale(let d, _): return d
    case .failed: return nil
    }
  }
}

/// 對應 Dart 的 `FailureReason`。
enum CoreFailureKind {
  case offline
  case notSignedIn
  case loginFailed(String?)
  case fetchFailed(String?)
  case unsupportedCourse

  /// 重試有沒有意義。false 時畫面不該給「重試」。
  ///
  /// 不從邊界送過來：這是各原因的固有性質，多一個欄位只是多一個會不同步的地方。
  var retryable: Bool {
    switch self {
    case .notSignedIn, .unsupportedCourse: return false
    case .offline, .loginFailed, .fetchFailed: return true
    }
  }

  init(_ failure: CoreFailure) {
    switch failure {
    case is CoreFailureOffline: self = .offline
    case is CoreFailureNotSignedIn: self = .notSignedIn
    case let f as CoreFailureLoginFailed: self = .loginFailed(f.detail)
    case let f as CoreFailureFetchFailed: self = .fetchFailed(f.detail)
    case is CoreFailureUnsupportedCourse: self = .unsupportedCourse
    default:
      // 這裡是整個 App 唯一一個「Dart 加了新的失敗原因、Swift 沒跟上」會露出來
      // 的地方。當成 fetchFailed 而不是 crash：使用者看到一個可重試的錯誤，
      // 比閃退好。
      assertionFailure("未知的 CoreFailure: \(failure)")
      self = .fetchFailed(String(describing: failure))
    }
  }
}

extension CoreResult where T == CourseTable {
  init(_ result: CourseTableResult) {
    switch result {
    case let r as CourseTableOk: self = .ok(r.data)
    case let r as CourseTableStale: self = .stale(r.data, CoreFailureKind(r.reason))
    case let r as CourseTableFailed: self = .failed(CoreFailureKind(r.reason))
    default:
      assertionFailure("未知的 CourseTableResult: \(result)")
      self = .failed(.fetchFailed(String(describing: result)))
    }
  }
}

extension CoreResult where T == ScoreSummary {
  init(_ result: ScoreResult) {
    switch result {
    case let r as ScoreOk: self = .ok(r.data)
    case let r as ScoreStale: self = .stale(r.data, CoreFailureKind(r.reason))
    case let r as ScoreFailed: self = .failed(CoreFailureKind(r.reason))
    default:
      assertionFailure("未知的 ScoreResult: \(result)")
      self = .failed(.fetchFailed(String(describing: result)))
    }
  }
}
