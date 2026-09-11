import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 隱私政策的離線備援必須真的被打包。
///
/// 這一頁沒有退路：載入失敗時 BasePage 會用錯誤頁換掉整個 child，同意鈕不會
/// 被畫出來。而 asset 沒有編譯期檢查，pubspec 少一行只會在執行期才失敗。
void main() {
  const assetPath = 'privacy-policy.md';

  test('privacy-policy.md 確實存在於 repo 根目錄', () {
    final file = File(assetPath);
    expect(file.existsSync(), isTrue);
    // 不驗內容，只驗它不是被清空的殘骸。
    expect(file.readAsStringSync().trim().length, greaterThan(200));
  });

  test('pubspec.yaml 有把它宣告成 asset', () {
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final declared = pubspec
        .map((l) => l.trim())
        .any((l) => l == '- $assetPath' || l == '- ./$assetPath');

    expect(declared, isTrue, reason: '少了這一行，rootBundle.loadString 會在執行期才失敗');
  });

  test('controller 讀的路徑與 pubspec 宣告的一致', () {
    // 兩邊是兩份字面值，不會互相檢查。
    final controller =
        File('lib/ui/screen/privacy_policy/privacy_policy_controller.dart')
            .readAsStringSync();

    expect(controller, contains('"$assetPath"'));
    expect(controller, contains('rootBundle.loadString'),
        reason: '網路失敗時要退回打包的那一份，不能直接進錯誤狀態');
  });

  test('唯讀那一頁走的是同一份備援', () {
    // 登入頁「隱私權條款」那一行連到的是 PrivacyPolicyPage。它以前自己打一次
    // 網路、失敗就畫一個沒有字的驚嘆號——第一次開 App 沒網路的人會卡在那裡。
    final page = File('lib/ui/pages/other/page/privacy_policy_page.dart')
        .readAsStringSync();

    expect(page, contains('PrivacyPolicyController.fetchPolicy'),
        reason: '兩個入口要共用同一份離線備援，不能只有同意閘門有');
    expect(page, isNot(contains('AppLink.privacyPolicyUrl')),
        reason: '直接打網路等於繞過備援');
  });
}
