import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 憑證儲存的抽象層。
///
/// 與 [KeyValueStore] 分開是刻意的：這一層的失敗語意完全不同。
/// 讀不到不代表「沒有」，可能是 Android 備份還原後 Keystore 解不開、
/// 或 iOS 在鎖定狀態下被背景推播喚醒而 Keychain 不可讀。
/// 呼叫端必須分辨「沒有憑證」與「讀取失敗」，絕不能把後者當成前者去清除資料。
abstract class SecureStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class FlutterSecureStore extends SecureStore {
  static const _options = AndroidOptions(encryptedSharedPreferences: true);

  /// first_unlock_this_device：裝置解鎖過一次之後才可讀，且不隨 iCloud
  /// 備份離開這台裝置。背景推播在鎖定狀態下喚醒 App 時會讀不到，
  /// 那正是呼叫端必須把「讀取失敗」與「沒有憑證」分開處理的原因。
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  final _storage = const FlutterSecureStorage(
    aOptions: _options,
    iOptions: _iosOptions,
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// 測試用。可以指定讓讀取拋例外，模擬 Keystore 解不開的情況。
class InMemorySecureStore extends SecureStore {
  final Map<String, String> data = {};
  bool throwOnRead = false;

  @override
  Future<String?> read(String key) async {
    if (throwOnRead) throw Exception('keystore unavailable');
    return data[key];
  }

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> delete(String key) async => data.remove(key);
}
