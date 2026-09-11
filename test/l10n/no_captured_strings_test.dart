import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 翻譯字串不可以被「捕捉一次」。
///
/// 切換語言走的是 `Get.updateLocale` → `forceAppUpdate()`，它重跑 `build()`
/// 但**不重建 State**，所以在欄位初始化式或 `initState` 裡讀到的 `R.current`
/// 會凍在建立時的語言。回報過的症狀是同一頁兩種語言。
void main() {
  /// 已知安全的例外，連同理由一起寫在這裡。目前是空的。
  const Set<String> allow = {};

  List<File> libDartFiles() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  /// 第一個「指派用」的 `=` 的位置（排掉 `==` `!=` `<=` `>=` `=>`），
  /// 找不到回 -1。
  int assignIndex(String line) {
    for (var i = 0; i < line.length; i++) {
      if (line[i] != '=') continue;
      final prev = i > 0 ? line[i - 1] : '';
      final next = i + 1 < line.length ? line[i + 1] : '';
      if (prev == '=' || prev == '!' || prev == '<' || prev == '>') continue;
      if (next == '=' || next == '>') continue;
      return i;
    }
    return -1;
  }

  /// 這一行是不是 class 成員的欄位宣告。
  ///
  /// 刻意不用單一個大正則：型別要允許內部空白，而「字元類含 `\s`」後面再接
  /// `\s+` 會造成 catastrophic backtracking。切 token 逐個檢查沒有回溯。
  bool isFieldDecl(String line) {
    // 恰好兩格縮排：class 成員在這一層，方法內的區域變數在四格以上。
    if (!line.startsWith('  ') || line.startsWith('   ')) return false;
    if (line.contains(' get ')) return false;
    final eq = assignIndex(line);
    if (eq < 0) return false;
    final head = line.substring(2, eq).trim();
    if (head.isEmpty) return false;
    // 參數預設值裡的 `=` 會讓「有參數的方法」看起來像欄位宣告，例如
    // `List<Widget> _f({bool refresh = false}) => [...]`。方法每次呼叫都重新
    // 求值，不會凍住語言。用「括號沒閉合」判定：函式型別的欄位
    // （`void Function(int) cb = ...`）括號是閉合的，不會被這一條誤殺。
    var depth = 0;
    for (final c in head.split('')) {
      if (c == '(') depth++;
      if (c == ')') depth--;
    }
    if (depth > 0) return false;
    final parts = head.split(RegExp(r'\s+'));
    // 至少要「型別或修飾詞 + 名稱」兩段，而且名稱得是識別字。
    if (parts.length < 2) return false;
    return RegExp(r'^_?[a-zA-Z]\w*$').hasMatch(parts.last);
  }

  /// 頂層型別宣告。要追蹤這個邊界，是因為頂層函式的 body 同樣是兩格縮排，
  /// 它的區域變數與 class 欄位在行的長相上完全一樣。
  final typeDecl = RegExp(
    r'^(?:abstract\s+|sealed\s+|base\s+|interface\s+|final\s+)*'
    r'(?:class|mixin|enum|extension)\s',
  );

  final lifecycle = RegExp(r'\bvoid\s+(initState|didChangeDependencies)\s*\(');

  test('R.current 不可以出現在 class 欄位初始化式裡', () {
    final offenders = <String>[];

    for (final file in libDartFiles()) {
      final lines = file.readAsLinesSync();
      var inClass = false;
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (typeDecl.hasMatch(line)) inClass = true;
        if (line == '}') inClass = false;
        if (!inClass) continue;
        if (line.trimLeft().startsWith('//')) continue;
        if (!isFieldDecl(line)) continue;

        // 收集到分號為止，跨行的 list / map literal 才抓得到。
        final buffer = StringBuffer(line);
        var j = i;
        var text = line;
        while (!text.contains(';') && j + 1 < lines.length && j - i < 30) {
          buffer.write('\n${lines[++j]}');
          text = buffer.toString();
        }
        if (text.contains('R.current')) {
          final at = '${file.path}:${i + 1}';
          if (!allow.contains(at)) offenders.add('$at  ${line.trim()}');
        }
        i = j;
      }
    }

    expect(offenders, isEmpty,
        reason: '欄位初始化式只跑一次，切換語言後 forceAppUpdate 不會重建 State，'
            '這些字串會永遠停在舊語言。改成 getter，或搬進 build()。\n'
            '${offenders.join('\n')}');
  });

  test('R.current 不可以出現在 initState / didChangeDependencies 裡', () {
    final offenders = <String>[];

    for (final file in libDartFiles()) {
      final lines = file.readAsLinesSync();
      var inLifecycle = false;
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (lifecycle.hasMatch(line)) inLifecycle = true;
        // 方法結尾：兩格縮排的右大括號。
        if (inLifecycle && RegExp(r'^  \}').hasMatch(line)) inLifecycle = false;
        if (!inLifecycle) continue;
        if (line.trimLeft().startsWith('//')) continue;
        if (!line.contains('R.current')) continue;

        final at = '${file.path}:${i + 1}';
        if (!allow.contains(at)) offenders.add('$at  ${line.trim()}');
      }
    }

    expect(offenders, isEmpty,
        reason: 'initState 同樣只跑一次，語言切換不會重跑它。\n'
            '${offenders.join('\n')}');
  });
}
