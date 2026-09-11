import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/ui/pages/password/check_password_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_l10n.dart';

/// 密碼對話框右邊的眼睛按鈕。
///
/// 圖示是這顆按鈕唯一的狀態指示，所以 tooltip 必須跟著 passwordShow 走，
/// 講「按下去會發生什麼」。tooltip 會被 IconButton 轉成 semantics label，
/// 看不到圖示的人才聽得出名字與目前狀態。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => loadTestL10n());

  /// 找到密碼欄旁邊那顆眼睛 IconButton。
  IconButton eyeButton(WidgetTester tester) =>
      tester.widget<IconButton>(find.byType(IconButton));

  Future<void> expectTooltipFollowsState(WidgetTester tester) async {
    // 一開始 passwordShow == false，密碼是遮住的，按下去會「顯示密碼」。
    expect(eyeButton(tester).tooltip, R.current.showPassword);
    expect(find.byTooltip(R.current.showPassword), findsOneWidget);

    await tester.tap(find.byType(IconButton));
    await tester.pump();

    // 切換之後文案要跟著換，否則螢幕閱讀器會一直唸同一句。
    expect(eyeButton(tester).tooltip, R.current.hidePassword);
    expect(find.byTooltip(R.current.hidePassword), findsOneWidget);
  }

  test('showPassword／hidePassword 兩個 l10n key 有值且互不相同', () {
    // 兩句唸起來一樣的話，狀態切換對螢幕閱讀器就等於沒切換。
    expect(R.current.showPassword, isNotEmpty);
    expect(R.current.hidePassword, isNotEmpty);
    expect(R.current.showPassword, isNot(R.current.hidePassword));
  });

  group('CheckPasswordDialog', () {
    // 同 password_dialog_dispose_test：initState 會打 local_auth 的
    // MethodChannel，測試環境沒人接。回 false 代表生物辨識沒過，對話框
    // 留在畫面上，正是要測的情境。
    const channel = MethodChannel('plugins.flutter.io/local_auth');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => false);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    testWidgets('眼睛按鈕有名字，而且名字跟著顯示／隱藏狀態切換', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Material(child: CheckPasswordDialog())),
      );
      await tester.pump();

      await expectTooltipFollowsState(tester);
    });
  });
}
