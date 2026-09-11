import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 每一個 l10n key 都要有人讀。
///
/// 翻譯檔沒有編譯器把關，功能移除時留下的死 key 會一直累積，每加一個語系就
/// 多一份要翻的垃圾。這道守衛不驗翻譯品質（那是 arb_translation_test 的事），
/// 只驗「有沒有人讀」。刻意保留但暫時沒用的 key 請寫進 [allowUnused] 並附理由。
void main() {
  /// 允許暫時沒有讀取點的 key，加進來時要一起寫明理由。
  ///
  /// 目前是空的，維持這樣：UI 改版補進來的字串已經全部接上，接不上的那些
  /// （3h 的學籍欄位等）連同 key 一起刪掉了，沒有留成永久豁免。
  const Set<String> allowUnused = <String>{};

  test('lib/l10n 的每個 key 都有讀取點', () {
    final arb = json.decode(File('lib/l10n/intl_zh_TW.arb').readAsStringSync())
        as Map<String, dynamic>;
    final keys = arb.keys.where((k) => !k.startsWith('@')).toSet();
    expect(keys, isNotEmpty, reason: '掃描器壞掉時這裡會空，導致整個測試假綠');

    // 只看程式碼不看註解：註解裡提到某個 key（通常是在說明它為什麼被改掉）
    // 不算讀取點。
    final used = <String>{};
    for (final dir in ['lib', 'test']) {
      for (final file in Directory(dir).listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        if (file.path.contains('/generated/') || file.path.contains('/l10n/')) {
          continue;
        }
        final code = file
            .readAsLinesSync()
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        for (final k in keys) {
          if (used.contains(k)) continue;
          if (RegExp('\\b${RegExp.escape(k)}\\b').hasMatch(code)) used.add(k);
        }
      }
    }

    final unused = keys.difference(used).difference(allowUnused).toList()
      ..sort();
    expect(unused, isEmpty,
        reason: '這些 key 沒有任何讀取點。刪掉它們（arb 兩份、l10n.dart、'
            'messages_*.dart 各一處），或加進 allowUnused 並寫明理由。');
  });
}
