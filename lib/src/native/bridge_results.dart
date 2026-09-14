import 'package:flutter_app/src/repository/result.dart';

/// 三態結果翻成原生畫面要的兩句話：失敗的原因，與「這是舊資料」的原因。
class BridgeResults {
  BridgeResults._();

  static String? errorOf<T>(Result<T> result) => switch (result) {
        Failed<T>(:final reason) => reason.message,
        _ => null,
      };

  static String? noticeOf<T>(Result<T> result) => switch (result) {
        Stale<T>(:final reason) => reason.message,
        _ => null,
      };
}
