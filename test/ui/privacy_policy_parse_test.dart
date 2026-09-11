import 'package:flutter_app/ui/pages/other/page/privacy_policy_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('## 是文件大標不是一節，### 才是', () {
    final sections = PolicySection.parse('''## 隱私權條款

引言一段。

### 一、範圍

內容一。

### 二、蒐集

內容二。
''');
    expect(sections.where((s) => s.title == null).length, 1);
    expect(sections.where((s) => s.title != null).map((s) => s.title),
        ['一、範圍', '二、蒐集']);
    expect(sections.first.body, contains('引言一段'));
  });

  test('沒有 ## 的新版本文：開頭是引言，### 各自成節', () {
    final sections = PolicySection.parse('''TAT 是開源 App。

### 一、會碰到哪些資料

清單。
''');
    expect(sections.first.title, isNull);
    expect(sections.where((s) => s.title != null).length, 1);
  });
}
