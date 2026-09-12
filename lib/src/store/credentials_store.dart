import 'dart:convert';

import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/model/userdata/user_data_json.dart';
import 'package:flutter_app/src/store/key_value_store.dart';
import 'package:flutter_app/src/store/secure_store.dart';

/// 憑證的載入結果。
///
/// 「沒有憑證」與「讀取失敗」必須分得開：後者代表 Keystore 暫時不可用
/// （Android 備份還原、iOS 鎖定狀態下被背景推播喚醒），這時**絕對不能**
/// 清掉任何東西，也不能把使用者當成已登出而觸發資料清除。
enum CredentialsLoadResult { loaded, absent, unavailable }

/// 帳號與密碼的持久化。
///
/// 底層是 [SecureStore]（Android Keystore / iOS Keychain）。
///
/// **已知取捨**：secure storage 的內容綁定裝置金鑰，換手機從備份還原後
/// 解不開，使用者需要重新登入一次。見 docs/ARCHITECTURE.md 的〈已接受的風險〉。
class CredentialsStore {
  static CredentialsStore instance = CredentialsStore(
    FlutterSecureStore(),
    SharedPrefsKeyValueStore(),
  );

  /// secure storage 內的 key。
  static const secureKey = 'user_data';

  /// SharedPreferences 內的舊 key（明文），與 secure 的同名。
  ///
  /// 只有在確認 secure storage 真的有可用副本之後才刪，條件只有兩種：
  /// 1. [load] 從 secure storage 讀到了資料——那份副本已經證明讀得出來。
  /// 2. [_migrateFromPlainStore] 寫入之後**讀回比對成功**。
  ///
  /// 寫入失敗、驗證不符、或 Keystore 拋例外時一律不刪：那時 secure storage
  /// 沒有可用的副本，刪掉等於把使用者的帳密弄丟。
  static const legacyKey = 'user_data';

  /// 帳號（非機密）在 SharedPreferences 的鏡像。
  ///
  /// UI 有 40 幾處以「帳號非空」當作已登入的謂詞，而那些地方多半是同步的。
  /// 把帳號另外鏡像一份可以避免為了一個非機密欄位去讀 Keychain。
  static const accountMirrorKey = 'account_mirror';

  final SecureStore _secure;
  final KeyValueStore _plain;

  UserDataJson _data = UserDataJson();
  CredentialsLoadResult _lastResult = CredentialsLoadResult.absent;

  CredentialsStore(this._secure, this._plain);

  /// 上一次 [load] 的結果。
  ///
  /// `main.dart` 的 `getInitialRoute` 要靠它分辨「沒有憑證」與「這次讀不到」：
  /// 兩者的 [hasCredentials] 都是 false，但該去的地方相反。
  CredentialsLoadResult get lastResult => _lastResult;

  String get account => _data.account;

  String get password => _data.password;

  String get mailPassword => _data.mailPassword;

  /// 刻意**不**把 [mailPassword] 算進來：這個判準代表「登入 TAT」，而信箱是
  /// 選用功能。沒設定信箱密碼的人仍然是已登入使用者。
  bool get hasCredentials =>
      _data.account.isNotEmpty && _data.password.isNotEmpty;

  /// 讀取憑證，必要時從舊的 SharedPreferences 位置遷移過來。
  ///
  /// [skipMigration] 供背景啟動使用：iOS 在鎖定狀態下被推播喚醒時
  /// Keychain 不可寫，這時不要嘗試遷移，以免把舊資料刪掉卻寫不進新位置。
  Future<CredentialsLoadResult> load({bool skipMigration = false}) async {
    String? raw;
    try {
      raw = await _secure.read(secureKey);
    } catch (e, stack) {
      // 讀取失敗不等於沒有憑證。維持記憶體內的現況，讓呼叫端看到
      // unavailable 而不是把使用者當成已登出。
      Log.eWithStack('secure storage unavailable: $e', stack);
      _lastResult = CredentialsLoadResult.unavailable;
      return _lastResult;
    }

    if (raw != null) {
      _data = _decode(raw);
      _lastResult = CredentialsLoadResult.loaded;
      await _mirrorAccount();
      // secure storage 這一份剛讀出來，明文那一份沒有存在的理由了。
      // 已遷移過的裝置永遠走不到 _migrateFromPlainStore，少了這一行就
      // 清不掉它們殘留的明文密碼。
      await _plain.remove(legacyKey);
      return _lastResult;
    }

    if (!skipMigration) {
      final migrated = await _migrateFromPlainStore();
      if (migrated) {
        _lastResult = CredentialsLoadResult.loaded;
        return _lastResult;
      }
    }

    _data = UserDataJson();
    _lastResult = CredentialsLoadResult.absent;
    return _lastResult;
  }

  Future<void> save() async {
    await _secure.write(secureKey, json.encode(_data));
    await _mirrorAccount();
  }

  Future<void> clear() async {
    _data = UserDataJson();
    _lastResult = CredentialsLoadResult.absent;
    await _secure.delete(secureKey);
    await _plain.remove(legacyKey);
    await _plain.remove(accountMirrorKey);
  }

  void setAccount(String value) => _data.account = value;

  void setPassword(String value) => _data.password = value;

  void setMailPassword(String value) => _data.mailPassword = value;

  /// 一次性遷移：舊位置有資料就搬過去，讀回比對一致才算成功。
  ///
  /// 只有比對成功才刪舊 key。兩條失敗路徑（驗證不符、寫入拋例外）都會
  /// 改用明文那一份繼續跑並回 true，那時**不能**刪——secure storage 沒有
  /// 可用的副本，刪掉就沒有第二份了。
  Future<bool> _migrateFromPlainStore() async {
    final legacy = await _plain.readString(legacyKey);
    if (legacy == null) return false;

    final parsed = _decode(legacy);
    if (parsed.account.isEmpty && parsed.password.isEmpty) return false;

    try {
      await _secure.write(secureKey, json.encode(parsed));
      final verify = await _secure.read(secureKey);
      if (verify == null || _decode(verify).password != parsed.password) {
        Log.e('credentials migration verify failed');
        // 寫不進去就照舊用 SharedPreferences 的內容，不要把使用者登出。
        _data = parsed;
        return true;
      }
    } catch (e, stack) {
      Log.eWithStack('credentials migration failed: $e', stack);
      _data = parsed;
      return true;
    }

    _data = parsed;
    await _mirrorAccount();
    // 寫入 + 讀回比對都過了才刪。上面兩條 early return 刻意不刪。
    await _plain.remove(legacyKey);
    return true;
  }

  Future<void> _mirrorAccount() =>
      _plain.writeString(accountMirrorKey, _data.account);

  UserDataJson _decode(String raw) {
    try {
      return UserDataJson.fromJson(json.decode(raw));
    } catch (e) {
      return UserDataJson();
    }
  }
}
