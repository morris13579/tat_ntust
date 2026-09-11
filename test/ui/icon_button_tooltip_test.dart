import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 純圖示按鈕（IconButton / FloatingActionButton）沒有 tooltip 時，
/// TalkBack 與 VoiceOver 只會唸出「按鈕」，使用者完全不知道那顆在做什麼。
///
/// 這裡刻意用「掃原始碼」而不是 widget test：按鈕散在十幾個頁面上，其中好幾個
/// （webview、log console、debug 專用頁）要拉起平台 channel 才渲染得出來，
/// 一顆一顆寫 widget test 的成本遠高於收益，而且新加的按鈕不會自動被涵蓋。
/// 掃原始碼可以保證「未來新增的每一顆也要有名字」。
///
/// 對應的行為測試（tooltip 內容會不會跟著狀態變）寫在
/// password_dialog_tooltip_test.dart 與 log_console_tooltip_test.dart。
void main() {
  /// 從 [start]（字串或字元常值的起始引號）跳到該常值結束的下一個位置。
  /// 會處理三引號、跳脫字元與 `${}` 內插。
  int skipStringLiteral(String src, int start) {
    final quote = src[start];
    final delimiter = src.startsWith(quote * 3, start) ? quote * 3 : quote;
    var i = start + delimiter.length;
    while (i < src.length) {
      if (src[i] == r'\') {
        i += 2;
        continue;
      }
      if (src.startsWith(r'${', i)) {
        // 內插區塊本身是運算式，可能再包字串，要平衡地跳過。
        var depth = 0;
        i += 1;
        while (i < src.length) {
          final c = src[i];
          if (c == "'" || c == '"') {
            i = skipStringLiteral(src, i);
            continue;
          }
          if (c == '{') depth++;
          if (c == '}') {
            depth--;
            if (depth == 0) {
              i++;
              break;
            }
          }
          i++;
        }
        continue;
      }
      if (src.startsWith(delimiter, i)) return i + delimiter.length;
      i++;
    }
    return src.length;
  }

  /// [openParen] 指向建構式的 `(`。回傳它的具名引數裡有沒有 `tooltip:`。
  ///
  /// 只認深度 1 的 `tooltip:`——包在 `icon:` 裡的別的 widget、或包在
  /// onPressed 閉包裡的 tooltip 都不算數，那些不會變成這顆按鈕的名字。
  bool hasTooltipArgument(String src, int openParen) {
    var depth = 0;
    var i = openParen;
    while (i < src.length) {
      final c = src[i];
      if (c == '/' && i + 1 < src.length) {
        if (src[i + 1] == '/') {
          while (i < src.length && src[i] != '\n') {
            i++;
          }
          continue;
        }
        if (src[i + 1] == '*') {
          i += 2;
          while (i + 1 < src.length && !(src[i] == '*' && src[i + 1] == '/')) {
            i++;
          }
          i += 2;
          continue;
        }
      }
      if (c == "'" || c == '"') {
        i = skipStringLiteral(src, i);
        continue;
      }
      if (c == '(' || c == '[' || c == '{') {
        depth++;
        i++;
        continue;
      }
      if (c == ')' || c == ']' || c == '}') {
        depth--;
        if (depth == 0) return false;
        i++;
        continue;
      }
      if (depth == 1 && src.startsWith('tooltip:', i)) return true;
      i++;
    }
    return false;
  }

  /// 回傳 [src] 裡所有 `<widget>(` 的位置。前一個字元是識別字的一部分時
  /// 不算（避免把 `MyIconButton(` 當成 `IconButton(`）。
  List<int> findConstructorCalls(String src, String widget) {
    final identifier = RegExp(r'[A-Za-z0-9_$.]');
    final result = <int>[];
    var from = 0;
    while (true) {
      final at = src.indexOf('$widget(', from);
      if (at < 0) return result;
      from = at + 1;
      if (at > 0 && identifier.hasMatch(src[at - 1])) continue;
      result.add(at + widget.length);
    }
  }

  List<File> dartFilesUnder(String path) => Directory(path)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  /// 回傳 `檔案:行號` 形式的缺 tooltip 清單。
  List<String> offendersFor(String widget) {
    final offenders = <String>[];
    for (final file in dartFilesUnder('lib')) {
      final src = file.readAsStringSync();
      for (final openParen in findConstructorCalls(src, widget)) {
        if (hasTooltipArgument(src, openParen)) continue;
        final line = '\n'.allMatches(src.substring(0, openParen)).length + 1;
        offenders.add('${file.path}:$line');
      }
    }
    return offenders;
  }

  test('lib 底下每一顆 IconButton 都有 tooltip', () {
    expect(
      offendersFor('IconButton'),
      isEmpty,
      reason: '純圖示按鈕沒有 tooltip，螢幕閱讀器只會唸「按鈕」',
    );
  });

  test('lib 底下每一顆 FloatingActionButton 都有 tooltip', () {
    expect(
      offendersFor('FloatingActionButton'),
      isEmpty,
      reason: 'FAB 同樣是純圖示，沒有 tooltip 就沒有名字',
    );
  });

  test('掃描器真的掃得到東西，而且抓得出沒有 tooltip 的按鈕', () {
    // 上面兩條在「掃描器壞掉、一顆都沒掃到」時也會綠燈，所以這裡釘住
    // 掃描器本身：現有的 IconButton 顆數要對得上，而且對著一段刻意
    // 缺 tooltip 的原始碼要抓得出來。
    var total = 0;
    for (final file in dartFilesUnder('lib')) {
      total +=
          findConstructorCalls(file.readAsStringSync(), 'IconButton').length;
    }
    // 這個下限只用來擋「掃描器壞掉、一顆都沒掃到」的假綠燈，
    // 真的刪掉按鈕時往下調即可。
    expect(total, greaterThanOrEqualTo(18));

    const sample = '''
      IconButton(
        // tooltip: '註解裡的不算',
        icon: const Icon(LucideIcons.plus),
        onPressed: () => show(tooltip: 'x'),
      )
    ''';
    final at = findConstructorCalls(sample, 'IconButton').single;
    expect(hasTooltipArgument(sample, at), isFalse);

    const withTooltip = '''
      IconButton(
        tooltip: R.current.refresh,
        icon: const Icon(LucideIcons.plus),
        onPressed: null,
      )
    ''';
    expect(
      hasTooltipArgument(
          withTooltip, findConstructorCalls(withTooltip, 'IconButton').single),
      isTrue,
    );

    // MyIconButton 這種前面接著識別字的不該被誤判成 IconButton。
    expect(findConstructorCalls('MyIconButton(x)', 'IconButton'), isEmpty);
  });
}
