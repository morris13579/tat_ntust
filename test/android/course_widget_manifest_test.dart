import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AndroidManifest 裡桌面小工具 receiver 的 intent-filter 守門測試。
///
/// CourseWidgetProvider 用顯示意圖（`new Intent(context, ...class)`）廣播，
/// 系統直接派送到指定元件、不查 intent-filter，所以 manifest 上任何對不到
/// ACTION_ONCLICK 的自訂 action 都是死設定：它會讓人誤以為隱式廣播是通的、
/// 把 PendingIntent 改成隱式意圖後在真機上壞掉，也等於在 exported 的 receiver
/// 上開了一個沒有程式碼接的入口。
///
/// 這裡直接讀 repo 內的原始檔（`flutter test` 的工作目錄就是套件根目錄），
/// 因為要驗的正是這兩個檔案彼此的一致性，不是任何 Dart 端的行為。
void main() {
  const manifestPath = 'android/app/src/main/AndroidManifest.xml';
  const providerPath =
      'android/app/src/main/java/widget/CourseWidgetProvider.java';

  /// AppWidget 框架自己會送的 action，不受「必須等於 ACTION_ONCLICK」這條約束。
  const frameworkActions = <String>{
    'android.appwidget.action.APPWIDGET_UPDATE',
    'android.appwidget.action.APPWIDGET_DELETED',
    'android.appwidget.action.APPWIDGET_ENABLED',
    'android.appwidget.action.APPWIDGET_DISABLED',
    'android.appwidget.action.APPWIDGET_OPTIONS_CHANGED',
    'android.appwidget.action.APPWIDGET_RESTORED',
  };

  late String manifest;
  late String actionOnClick;
  late List<String> receiverActions;

  setUp(() {
    // 先把 XML 註解剝掉：manifest 的說明文字引用了廢棄的 action 字串當反例，
    // 不剝掉的話下面的 action 抽取會把註解裡的字串當成真的宣告。
    manifest = File(manifestPath)
        .readAsStringSync()
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

    final provider = File(providerPath).readAsStringSync();
    final constantMatch =
        RegExp(r'ACTION_ONCLICK\s*=\s*"([^"]+)"').firstMatch(provider);
    expect(constantMatch, isNotNull,
        reason: '在 $providerPath 找不到 ACTION_ONCLICK 常數，'
            '常數被改名的話這個測試也要跟著改');
    actionOnClick = constantMatch!.group(1)!;

    final receiverMatch = RegExp(
      r'<receiver[^>]*CourseWidgetProvider.*?</receiver>',
      dotAll: true,
    ).firstMatch(manifest);
    expect(receiverMatch, isNotNull,
        reason: '在 $manifestPath 找不到 CourseWidgetProvider 的 receiver 宣告');
    receiverActions = RegExp(r'<action\s+android:name="([^"]+)"')
        .allMatches(receiverMatch!.group(0)!)
        .map((m) => m.group(1)!)
        .toList();
  });

  test('小工具 receiver 不宣告任何對不上 ACTION_ONCLICK 的自訂 action', () {
    final custom =
        receiverActions.where((a) => !frameworkActions.contains(a)).toList();
    for (final action in custom) {
      expect(
        action,
        actionOnClick,
        reason: '自訂 action 必須等於 CourseWidgetProvider.ACTION_ONCLICK；'
            '「$action」對不上，多半又是舊的 club.ntut.npc 字串',
      );
    }
  });

  test('AppWidget 框架需要的 APPWIDGET_UPDATE 仍然保留', () {
    // CourseWidgetProvider.onReceive 靠它更新課表圖片，
    // 別在清理 intent-filter 時連它一起刪掉。
    expect(
      receiverActions,
      contains('android.appwidget.action.APPWIDGET_UPDATE'),
    );
  });

  test('ACTION_ONCLICK 帶的是現在的 package 名而不是舊的 ntut.npc', () {
    final packageMatch = RegExp(r'package="([^"]+)"').firstMatch(manifest);
    expect(packageMatch, isNotNull);
    final package = packageMatch!.group(1)!;
    expect(package, 'club.ntust.tat');
    expect(actionOnClick, startsWith('$package.'));
  });
}
