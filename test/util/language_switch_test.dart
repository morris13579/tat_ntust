import 'package:flutter/widgets.dart';
import 'package:flutter_app/generated/l10n.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

/// 「切換語言之後有些地方沒換」的迴歸測試。只涵蓋不需要 widget tree 的那半，
/// 另一半（Get.updateLocale 重建整棵樹）測不到。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDownAll(() async {
    // Intl.defaultLocale 是 process 級的，別汙染同批次的其他測試。
    await S.load(const Locale('zh', 'TW'));
  });

  test('R.load 回傳的 Future 等得到——await 完訊息表就換好了', () async {
    await S.load(const Locale('zh', 'TW'));

    await R.load(const Locale('en'));

    // 舊寫法的 `static load(...)` 沒有 return，回的是 null；`await R.load(...)`
    // 等於 `await null`，initializeMessages 還在跑就回去重畫 UI，畫出來的是
    // 舊語言。這一行在那個版本會拿到 'zh_TW'。
    expect(Intl.defaultLocale, 'en');
  });

  test('R.current 跟著切換走，不是第一次讀到的那一份', () async {
    await R.load(const Locale('zh', 'TW'));
    final zh = R.current;
    final zhText = R.current.login;

    await R.load(const Locale('en'));

    expect(R.current, isNot(same(zh)),
        reason: 'R.current 是 static 欄位時一輩子只初始化一次，換語言拿到的還是舊實例');
    expect(R.current.login, isNot(zhText));
  });
}
