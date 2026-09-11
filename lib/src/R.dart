// ignore_for_file: file_names
// R 是這個專案沿用已久的字串資源命名慣例（同 Android 的 R）。
// 改成 r.dart 要一併改一百多處 import，收益不足以抵銷風險。

import 'package:flutter/material.dart';
import 'package:flutter_app/generated/l10n.dart';

class R {
  /// getter 而不是 static 欄位：欄位只初始化一次，切換語言後拿到的是舊實例。
  static S get current => S.current;

  /// 一定要回傳 Future，否則呼叫端 await 不到訊息表載入完成。
  static Future<S> load(Locale locale) => S.delegate.load(locale);
}
