import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_app/src/file/file_store.dart';
import 'package:flutter_app/src/store/key_value_store.dart';
import 'package:flutter_app/src/store/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_l10n.dart';

/// findLocalPath / getDownloadDir 的簽章都要一個 BuildContext，但兩者都沒有
/// 真的用到它（權限提示走 TaskUiDelegate，不吃 context）。
/// 用 noSuchMethod 擋掉所有成員：萬一哪天真的被用到，測試會直接炸而不是靜默通過。
class _UnusedContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// getDownloadDir 的舊行為有三個問題，這組測試把修正後的保證釘住：
/// 1. `savedDir.create()` 沒有 await，回傳路徑時目錄可能還沒建好，
///    FileDownload 會拿它直接開始寫檔。
/// 2. create() 沒有 recursive，使用者自選的下載路徑若上層不存在就會拋例外，
///    而且因為 Future 被丟掉，變成沒人接的非同步錯誤。
/// 3. 沒有權限時 findLocalPath 回 ""，舊寫法照樣接成 '/$dirName'，
///    也就是檔案系統根目錄下的資料夾。
///
/// 注意這裡刻意用 `test` 而不是 `testWidgets`：getDownloadDir 會做真正的
/// 檔案系統 I/O，在 testWidgets 的 fake async 底下那些 Future 永遠不會完成。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  final context = _UnusedContext();
  TargetPlatform? originalPlatform;

  setUpAll(() async {
    await loadTestL10n();
  });

  setUp(() async {
    SettingsStore.instance = SettingsStore(InMemoryKeyValueStore());
    originalPlatform = debugDefaultTargetPlatformOverride;
    // 沒有 GetMaterialApp 時 Get.theme 回 ThemeData.fallback()，platform 取自
    // defaultTargetPlatform。設成 iOS 可以讓 PermissionsUtils 直接回 true，
    // 不必去接 device_info_plus / permission_handler 兩個 MethodChannel。
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tempRoot = await Directory.systemTemp.createTemp('tat_file_store_test');
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = originalPlatform;
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('getDownloadDir 回傳時目錄一定已經建好', () async {
    await SettingsStore.instance.setDownloadPath(tempRoot.path);

    final path = await FileStore.getDownloadDir(context, 'course');

    expect(path, '${tempRoot.path}/course');
    // 舊行為：create() 的 Future 被丟掉，這行有機會是 false。
    expect(Directory(path).existsSync(), isTrue);
  });

  test('上層目錄不存在時會一併建起來（舊行為：create() 沒有 recursive 會拋例外）', () async {
    final missingParent = '${tempRoot.path}/not/created/yet';
    await SettingsStore.instance.setDownloadPath(missingParent);

    final path = await FileStore.getDownloadDir(context, 'course');

    expect(path, '$missingParent/course');
    expect(Directory(path).existsSync(), isTrue);
  });

  test('目錄已存在時不會失敗，直接回同一個路徑', () async {
    await SettingsStore.instance.setDownloadPath(tempRoot.path);
    await Directory('${tempRoot.path}/course').create();

    final path = await FileStore.getDownloadDir(context, 'course');

    expect(path, '${tempRoot.path}/course');
    expect(Directory(path).existsSync(), isTrue);
  });

  test('沒有儲存權限時回傳空字串，不會去建根目錄下的資料夾', () async {
    // android / iOS 以外的平台在 PermissionsUtils.isStoragePermission 直接回
    // false，用它模擬「權限被拒」而不必 mock permission_handler。
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await SettingsStore.instance.setDownloadPath(tempRoot.path);

    final path = await FileStore.getDownloadDir(context, 'tat_root_dir_probe');

    // 舊行為：回 '/tat_root_dir_probe'，接著對根目錄呼叫 create()。
    expect(path, '');
    expect(Directory('/tat_root_dir_probe').existsSync(), isFalse);
  });
}
