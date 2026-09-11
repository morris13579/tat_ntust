import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// key 齊不代表有翻譯：intl_en.arb 的值可以整串照抄中文，而沒有任何工具會
/// 抱怨。英文語系的使用者就會在畫面上看到中文，所以由這個檔案守著。
void main() {
  Map<String, dynamic> loadArb(String fileName) {
    final raw = File('lib/l10n/$fileName').readAsStringSync();
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  late Map<String, dynamic> en;
  late Map<String, dynamic> zh;

  setUpAll(() {
    en = loadArb('intl_en.arb');
    zh = loadArb('intl_zh_TW.arb');
  });

  test('兩個 arb 檔的 key 完全一致', () {
    expect(en.keys.toSet(), zh.keys.toSet());
  });

  test('intl_en.arb 裡沒有任何中日韓字元', () {
    // 涵蓋 CJK 統一漢字、擴充 A 區、CJK 標點與全形符號（含「：」「（）」）。
    final cjk = RegExp(r'[　-〿㐀-䶿一-鿿＀-￯]');

    final untranslated = <String>[
      for (final entry in en.entries)
        if (entry.value is String && cjk.hasMatch(entry.value as String))
          entry.key,
    ];

    expect(untranslated, isEmpty, reason: '這些 key 的英文值還是中文，英文語系使用者會直接看到中文');
  });

  test('沿用 sprintf 的 key，中英文的 %s 數量要一樣', () {
    // choosePeopleString 是用 sprintf 帶三個參數，翻譯時漏掉一個 %s
    // 會在執行期才炸；course_info_page 把它包在 try/catch 裡，
    // 使用者只會看到那一欄整格消失。
    final placeholder = RegExp(r'%[sd]');
    for (final key in en.keys) {
      final enValue = en[key];
      final zhValue = zh[key];
      if (enValue is! String || zhValue is! String) continue;
      expect(
        placeholder.allMatches(enValue).length,
        placeholder.allMatches(zhValue).length,
        reason: '$key 的 %s 數量在兩個語系不一致',
      );
    }
  });

  test('產生出來的 messages_en.dart 也沒有中日韓字元', () {
    // arb 只是來源，App 實際讀的是 lib/generated/intl/messages_en.dart，
    // 兩者由 IDE 的 flutter_intl 外掛同步、不在 build 流程裡。改了 arb 卻忘記
    // 重新產生時上面那條會綠燈，所以這一條直接盯著真正被讀取的檔案。
    final generated =
        File('lib/generated/intl/messages_en.dart').readAsStringSync();
    // 只看 MessageLookupByLibrary.simpleMessage("...") 與 MessageLookupByLibrary
    // 之外的字串常值會誤判註解，所以逐行只取雙引號內的內容。
    final cjk = RegExp(r'[　-〿㐀-䶿一-鿿＀-￯]');
    final literal = RegExp(r'"((?:[^"\\]|\\.)*)"');
    final offenders = <String>[];
    for (final line in generated.split('\n')) {
      if (line.trimLeft().startsWith('//')) continue;
      for (final m in literal.allMatches(line)) {
        if (cjk.hasMatch(m.group(1)!)) {
          offenders.add(line.trim());
          break;
        }
      }
    }
    expect(offenders, isEmpty, reason: '英文語系的產生檔裡還有中文字串，代表 arb 改過但沒有重新產生');
  });
}
