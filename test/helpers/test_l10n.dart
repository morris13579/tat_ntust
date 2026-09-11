import 'package:flutter/material.dart';
import 'package:flutter_app/generated/l10n.dart';

/// 讓 `R.current` 在沒有 widget tree 的測試裡也有東西可讀。
///
/// `R.current` 是 `S.current` 的轉發，而 `S.current` 在 `S.load` 跑過之前
/// 會 assert 失敗。正式環境由 `Localizations` 在建子樹之前載入 delegate，
/// 測試裡沒有那一段，所以要自己載一次。
///
/// 任何會走到 `R.current.xxx` 的測試都要在 setUpAll 呼叫它。
Future<void> loadTestL10n([Locale locale = const Locale('zh', 'TW')]) async {
  await S.load(locale);
}
