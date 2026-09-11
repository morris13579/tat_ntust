import 'package:flutter_app/src/R.dart';

/// 一次資料取得的結果。
///
/// 三態而不是一顆 bool：「抓到新資料」與「沒抓到但讀得回快取」必須在型別上
/// 分得開，否則離線時的畫面跟成功時一模一樣，使用者不知道自己看的是舊資料。
sealed class Result<T> {
  const Result();

  /// 有資料可以顯示（[Ok] 或 [Stale]）。
  bool get hasData => this is Ok<T> || this is Stale<T>;

  /// 取得資料，[Failed] 時回 null。
  T? get dataOrNull => switch (this) {
        Ok<T>(:final data) => data,
        Stale<T>(:final data) => data,
        Failed<T>() => null,
      };
}

/// 這次真的抓到新資料。
final class Ok<T> extends Result<T> {
  final T data;

  const Ok(this.data);
}

/// 沒抓到新資料，但快取讀得回來。畫面應該標示這是舊資料。
final class Stale<T> extends Result<T> {
  final T data;
  final FailureReason reason;

  const Stale(this.data, this.reason);
}

/// 沒抓到新資料，也沒有快取。
final class Failed<T> extends Result<T> {
  final FailureReason reason;

  const Failed(this.reason);
}

/// 失敗的原因。決定 UI 要畫什麼、以及要不要給「重試」。
sealed class FailureReason {
  const FailureReason();

  String get message;

  /// 重試有沒有意義。false 時 `run()` 不會彈重試對話框。
  bool get retryable => true;
}

/// 探測不到網路。重試有意義：會重新探線。
final class Offline extends FailureReason {
  const Offline();

  @override
  String get message => R.current.networkError;
}

/// 沒有登入，或是登入狀態已經失效且沒有憑證可以自動重登。
///
/// 不可重試：UI 應該畫登入按鈕而不是「重試」。
final class NotSignedIn extends FailureReason {
  const NotSignedIn();

  @override
  String get message => R.current.pleaseLogin;

  @override
  bool get retryable => false;
}

/// 有憑證但登入失敗（密碼錯、驗證碼、學校端擋住）。可重試。
final class LoginFailed extends FailureReason {
  final String? detail;

  const LoginFailed([this.detail]);

  @override
  String get message => detail ?? R.current.pleaseLogin;
}

/// 登入沒問題，但取資料這一步失敗。
final class FetchFailed extends FailureReason {
  final String? detail;

  const FetchFailed([this.detail]);

  @override
  String get message => detail ?? R.current.unknownError;
}

/// 這門課在 Moodle 上找不到對應。
///
/// 不可重試：UI 只給一顆「確定」。
final class UnsupportedCourse extends FailureReason {
  const UnsupportedCourse();

  @override
  String get message => R.current.noSupport;

  @override
  bool get retryable => false;
}

/// 在 `fetch` 內丟出它可以指定自訂的 [reason]；`run()` 會原樣取出。
///
/// 不丟這個而丟一般例外時，`run()` 會依當下的連線狀態分類成
/// [Offline] 或 [FetchFailed]。
final class TaskFailure implements Exception {
  final FailureReason reason;

  const TaskFailure(this.reason);

  @override
  String toString() => 'TaskFailure(${reason.message})';
}
