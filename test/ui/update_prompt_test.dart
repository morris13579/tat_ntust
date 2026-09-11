import 'package:flutter/material.dart';
import 'package:flutter_app/ui/components/update_prompt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrader/upgrader.dart';
import 'package:version/version.dart';

import '../helpers/test_l10n.dart';

void main() {
  setUpAll(loadTestL10n);

  testWidgets('包住整個 App；測試主機上沒有商店，畫面不多不少', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      builder: (context, child) => UpdatePrompt(
        navigatorKey: navigatorKey,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const Scaffold(body: Text('the app')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('the app'), findsOneWidget);
    expect(find.text('有新版本可以更新'), findsNothing);
  });

  test('對話框文案用 App 自己的字串，版本號填進 updateBody', () {
    final state = Upgrader().state.copyWith(
          versionInfo: UpgraderVersionInfo(
            installedVersion: Version(1, 6, 6),
            appStoreVersion: Version(1, 7, 0),
          ),
        );
    final messages = UpdateMessages(() => state);

    expect(messages.title, '有新版本可以更新');
    expect(messages.body, 'TAT 有新的版本！目前是 1.6.6 版，可以更新到 1.7.0 版。');
    expect(messages.prompt, '現在要更新嗎？');
    expect(messages.buttonTitleUpdate, '更新');
    expect(messages.buttonTitleLater, '稍後再說');
    expect(messages.buttonTitleIgnore, '略過');
  });

  test('商店還沒回答時 body 不會拋，退回安裝版本或空字串', () {
    final messages = UpdateMessages(() => Upgrader().state);

    expect(messages.body, 'TAT 有新的版本！目前是  版，可以更新到  版。');
  });
}
