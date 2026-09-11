import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/store/key_value_store.dart';
import 'package:flutter_app/src/store/settings_store.dart';
import 'package:flutter_app/ui/pages/other/page/setting/setting_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 讓 readString 卡在一個 Completer 上，用來模擬 FileStore.findLocalPath
/// 停在系統儲存權限對話框的那段「長度不可控」的時間。
class _GatedStore extends KeyValueStore {
  _GatedStore(this._inner, this._gate);

  final KeyValueStore _inner;
  final Future<String?> _gate;

  @override
  Future<String?> readString(String key) => _gate;

  @override
  Future<void> writeString(String key, String value) =>
      _inner.writeString(key, value);

  @override
  Future<int?> readInt(String key) => _inner.readInt(key);

  @override
  Future<void> writeInt(String key, int value) => _inner.writeInt(key, value);

  @override
  Future<bool?> readBool(String key) => _inner.readBool(key);

  @override
  Future<void> writeBool(String key, bool value) =>
      _inner.writeBool(key, value);

  @override
  Future<List<String>?> readStringList(String key) =>
      _inner.readStringList(key);

  @override
  Future<void> writeStringList(String key, List<String> value) =>
      _inner.writeStringList(key, value);

  @override
  Future<void> remove(String key) => _inner.remove(key);

  @override
  Future<Set<String>> keys() => _inner.keys();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadTestL10n();
  });

  setUp(resetAppStatics);

  /// iOS 讓 PermissionsUtils.isStoragePermission 直接回 true，不必接
  /// device_info_plus / permission_handler 兩個 MethodChannel。
  ///
  /// 必須在 test body 裡面設定並還原：flutter_test 在 body 結束時（早於
  /// tearDown）就會檢查 debugDefaultTargetPlatformOverride 已經歸零。
  Future<void> withIosPlatform(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  testWidgets('取得下載路徑期間使用者離開設定頁，不會對已 dispose 的 State 呼叫 setState',
      (tester) async {
    // _getDownloadPath 在 await FileStore.findLocalPath 之後一定要檢查 mounted：
    // 那個 await 可能停在系統權限對話框上（時間不可控），使用者這時退出設定頁，
    // setState 就會打在已經 dispose 的 State 上並丟出
    // 「setState() called after dispose()」。
    await withIosPlatform(() async {
      final gate = Completer<String?>();
      SettingsStore.instance =
          SettingsStore(_GatedStore(InMemoryKeyValueStore(), gate.future));

      await tester.pumpWidget(const MaterialApp(home: SettingPage()));

      // 換掉整棵樹＝使用者離開設定頁，_SettingPageState 被 dispose。
      await tester.pumpWidget(const SizedBox());

      // 對話框這時才關掉，路徑姍姍來遲。
      gate.complete('/tmp/tat_download_path');
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('留在設定頁時仍會把下載路徑寫進畫面', (tester) async {
    // 確認 mounted 檢查沒有把正常情況一起擋掉。
    await withIosPlatform(() async {
      final gate = Completer<String?>();
      SettingsStore.instance =
          SettingsStore(_GatedStore(InMemoryKeyValueStore(), gate.future));

      await tester.pumpWidget(const MaterialApp(home: SettingPage()));

      gate.complete('/tmp/tat_download_path');
      await tester.pump();

      expect(find.text('/tmp/tat_download_path'), findsOneWidget);

      await tester.pumpAndSettle();
    });
  });
}
