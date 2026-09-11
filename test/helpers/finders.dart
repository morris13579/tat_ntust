import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 依文字找按鈕，容忍工廠建出來的子類別。
///
/// `find.byType` 比對的是精確型別：Flutter 3.38 的 `TextButton.icon` 回的是
/// `_TextButtonWithIcon`，`byType(TextButton)` 一個都抓不到（3.41 才改成回
/// `TextButton` 本身）。用 `is ButtonStyleButton` 就不會被這種差異絆倒，
/// 同時也涵蓋 Filled / Elevated / Outlined。
Finder buttonWithText(String text) => find.ancestor(
      of: find.text(text),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
