import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/ui/pages/password/check_password_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_l10n.dart';

/// 這個對話框的 TextEditingController 裡放的是使用者剛打進去的明文密碼，
/// State 關閉時一定要連同 FocusNode 一起 dispose。
///
/// 測試沒辦法直接摸到 private 欄位，所以改從 EditableText 拿到同一個物件，
/// 等對話框被移除後再 dispose 一次：ChangeNotifier 在 debug mode 下重複
/// dispose 會丟 FlutterError，這就是「第一次已經被 dispose 過」的證據。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => loadTestL10n());

  Future<void> expectDisposedAfterRemoval(WidgetTester tester) async {
    final editableText = tester.widget<EditableText>(find.byType(EditableText));
    final controller = editableText.controller;
    final focusNode = editableText.focusNode;

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();

    expect(() => controller.dispose(), throwsA(isA<FlutterError>()),
        reason: 'TextEditingController 仍持有明文密碼，關閉時一定要 dispose');
    expect(() => focusNode.dispose(), throwsA(isA<FlutterError>()));
  }

  group('CheckPasswordDialog', () {
    // initState 會呼叫 local_auth。沒有 mock 的話 pigeon 之外的預設實作會走
    // plugins.flutter.io/local_auth 這個 MethodChannel，在測試裡沒人接。
    // 回 false 代表「生物辨識沒過」，對話框留在畫面上，正是要測的情境。
    const channel = MethodChannel('plugins.flutter.io/local_auth');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => false);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    testWidgets('關閉後 controller 與 focusNode 都已被 dispose', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Material(child: CheckPasswordDialog())),
      );
      await tester.pump();

      await expectDisposedAfterRemoval(tester);
    });
  });
}
