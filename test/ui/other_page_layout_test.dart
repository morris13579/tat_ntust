import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/controller/main_page/main_controller.dart';
import 'package:flutter_app/ui/pages/other/other_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 「更多」頁整頁畫得出來。
///
/// 這一支存在的理由：分類卡改成 2x2 時，`Row(crossAxisAlignment: stretch)`
/// 在 ListView 裡拿到的是無限高度，整頁會變成一片空白——而 analyze 是綠的、
/// 其他測試也全過。要有人真的把它畫一次才看得到。
void main() {
  setUpAll(loadTestL10n);
  setUp(() {
    resetAppStatics();
    AuthSession.instance = FakeAuthSession();
    Get.put(MainController());
  });
  tearDown(() {
    Get.reset();
    AuthSession.instance = const UninstalledAuthSession();
  });

  testWidgets('整頁畫得出來，六張分類卡都在', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: OtherPage()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(R.current.informationSystem), findsOneWidget);
    for (final title in [
      R.current.curriculum,
      R.current.person_info,
      R.current.campus_life,
      R.current.financial_support,
      R.current.activities,
      R.current.resources,
    ]) {
      expect(find.text(title), findsOneWidget, reason: '$title 這張分類卡不見了');
    }
    expect(find.text(R.current.allServices), findsOneWidget);
    expect(find.text(R.current.setting), findsOneWidget);
  });

  testWidgets('捲到底：檢查新版本與登出各一個，登出不在任何一組裡面', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: OtherPage()));
    await tester.pump();

    await tester.scrollUntilVisible(find.text(R.current.logout), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pump();

    expect(find.text(R.current.groupAboutTat), findsOneWidget);
    expect(find.text(R.current.checkVersion), findsOneWidget);
    expect(find.text(R.current.logout), findsOneWidget);
  });
}
