import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/ui/pages/other/page/store_edit_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// StoreEditPage 每一列右邊的編輯／刪除按鈕。
///
/// 同一列連著兩顆純圖示按鈕，沒有 tooltip 的話螢幕閱讀器只會連唸兩次
/// 「按鈕」，使用者分不出哪顆是刪除——而這頁的刪除直接寫回 SharedPreferences，
/// 按錯沒有確認也沒有復原。
///
/// 這頁只有 debug build 進得來（about_page 的 kDebugMode 閘門），但它是掛在
/// App 的 widget tree 上、拿得到 localizations 的，所以照常走 R.current。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => loadTestL10n());

  setUp(() {
    // dispose 會呼叫 Model.instance.getInstance()，它會摸到憑證儲存層；
    // resetAppStatics 把那一層換成 InMemorySecureStore，測試才不會打到
    // 真的 platform channel。
    resetAppStatics();
    SharedPreferences.setMockInitialValues({
      'user_data': '{"account":"x"}',
      'some_setting': 'value',
    });
  });

  testWidgets('每一列的編輯與刪除按鈕都有名字，而且兩個名字不一樣', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StoreEditPage()));
    await tester.pumpAndSettle();

    // 只看清單裡的按鈕：baseAppbar 的返回鍵也是一顆 IconButton，它有自己的
    // tooltip，不屬於這一則要守的東西。
    final rowButtons = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(IconButton),
    );
    final tooltips = tester
        .widgetList<IconButton>(rowButtons)
        .map((b) => b.tooltip)
        .toList();

    // 兩個 key、每列兩顆。
    expect(tooltips, hasLength(4));
    expect(tooltips.any((t) => t == null || t.isEmpty), isFalse);
    expect(tooltips.toSet(), {R.current.edit, R.current.delete});

    expect(find.byTooltip(R.current.edit), findsNWidgets(2));
    expect(find.byTooltip(R.current.delete), findsNWidgets(2));
    // 返回鍵沒有搶走列上按鈕的名字。
    expect(rowButtons, findsNWidgets(4));
  });

  test('edit 與 delete 兩個 l10n key 有值且互不相同', () {
    expect(R.current.edit, isNotEmpty);
    expect(R.current.delete, isNotEmpty);
    expect(R.current.edit, isNot(R.current.delete));
  });
}
