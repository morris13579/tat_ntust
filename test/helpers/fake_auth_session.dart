import 'package:flutter_app/src/auth/auth_session.dart';

/// [AuthSession] 的測試替身。每個系統的登入結果可以逐一設定，並記錄呼叫序列。
///
/// 只給測試用，所以住在 test/：放進 lib/ 會被編進正式版 binary。
class FakeAuthSession implements AuthSession {
  /// 依序回傳給每一次 [ensure] 的結果。用完之後一律回 null（成功）。
  final List<AuthFailure?> ensureResults;

  final List<Set<SystemId>> ensureCalls = [];

  /// 每一次 [ensure] 的 interactive 旗標，順序與 [ensureCalls] 對齊。
  /// 背景預載必須是 false——那是「不要把登入頁蓋在使用者畫面上」的保證。
  final List<bool> ensureInteractive = [];
  final List<Set<SystemId>> invalidateCalls = [];
  final List<SystemId> tryEnsureCalls = [];

  /// 每一次 [tryEnsure] 的 interactive 旗標，順序與 [tryEnsureCalls] 對齊。
  final List<bool> tryEnsureInteractive = [];

  /// 指定一個完整的 [AuthError]（含 message）。null 時由 [ensureResults]
  /// 組一個沒有訊息的。
  AuthError? ensureError;

  @override
  bool isSignedIn;

  FakeAuthSession({
    List<AuthFailure?>? ensureResults,
    this.isSignedIn = true,
  }) : ensureResults = ensureResults ?? [];

  @override
  Future<AuthError?> ensure(Set<SystemId> requires,
      {bool interactive = true}) async {
    ensureCalls.add(requires);
    ensureInteractive.add(interactive);
    if (ensureCalls.length <= ensureResults.length) {
      final failure = ensureResults[ensureCalls.length - 1];
      if (failure == null) return null;
      return ensureError ?? AuthError(failure);
    }
    return null;
  }

  @override
  Future<void> tryEnsure(SystemId id, {bool interactive = true}) async {
    tryEnsureCalls.add(id);
    tryEnsureInteractive.add(interactive);
  }

  @override
  Future<void> invalidate(Set<SystemId> requires) async =>
      invalidateCalls.add(requires);
}
