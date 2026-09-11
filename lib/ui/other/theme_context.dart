import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_tokens.dart';

/// 讓 `Get.theme` 的呼叫端可以一行換成訂閱得到主題變化的寫法。
extension TatThemeContext on BuildContext {
  ColorScheme get scheme => Theme.of(this).colorScheme;

  TextTheme get text => Theme.of(this).textTheme;

  /// 沒掛 extension 的主題（測試裡常見的裸 MaterialApp）就地推一組，
  /// 免得元件在測試環境炸掉。
  TatTokens get tokens {
    final theme = Theme.of(this);
    return theme.extension<TatTokens>() ?? TatTokens.from(theme.colorScheme);
  }
}
