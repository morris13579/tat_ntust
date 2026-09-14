import 'package:flutter_app/src/native/developer_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/reset_statics.dart';

/// 原生版開發者選單的設定編輯。憑證不可以回顯，型別不對的值不可以寫進去。
void main() {
  setUp(resetAppStatics);

  test('快取排最後、憑證不回顯、只有字串與整數改得了', () async {
    SharedPreferences.setMockInitialValues({
      'cache_course': '{"a":1}',
      'user_data': 'secret',
      'lang': 'TW_zh',
      'count': 3,
      'flag': true,
    });
    const bridge = DeveloperBridge();

    final entries = await bridge.storeEntries();

    expect(entries.last.key, 'cache_course');
    expect(entries.last.value, contains('"a": 1'));
    final user = entries.firstWhere((e) => e.key == 'user_data');
    expect(user.value, isEmpty);
    expect(user.sensitive, isTrue);
    expect(entries.firstWhere((e) => e.key == 'flag').editable, isFalse);

    await bridge.setStoreValue('count', 'abc');
    await bridge.setStoreValue('lang', 'en');
    await bridge.removeStoreKey('cache_course');
    final pref = await SharedPreferences.getInstance();
    expect(pref.getInt('count'), 3);
    expect(pref.getString('lang'), 'en');
    expect(pref.containsKey('cache_course'), isFalse);
  });
}
