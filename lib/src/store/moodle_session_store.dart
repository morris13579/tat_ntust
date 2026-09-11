import 'dart:convert';

import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/model/moodle_token_entity.dart';
import 'package:flutter_app/src/store/key_value_store.dart';
import 'package:flutter_app/src/store/secure_store.dart';

/// Moodle 的 wstoken 與 privateToken。
///
/// 放在 [SecureStore]：這個 token 是長效的，拿到它就能透過 Moodle Web API
/// 讀取該學生的全部課程與個資，等同帳號接管，不該以明文存放。
///
/// 記憶體狀態也收在這裡；換帳號時一定要設回 null，否則會沿用前一位使用者的資料。
class MoodleSessionStore {
  static MoodleSessionStore instance =
      MoodleSessionStore(FlutterSecureStore(), SharedPrefsKeyValueStore());

  static const secureKey = 'moodle_token';

  /// SharedPreferences 內的舊 key。
  ///
  /// 只有在 secure storage 確認有可用副本之後才刪，理由同
  /// [CredentialsStore.legacyKey]。
  static const legacyKey = 'moodle_token';

  final SecureStore _secure;

  /// 只為了刪掉遷移前留在 SharedPreferences 的舊 token。
  final KeyValueStore _plain;

  MoodleTokenEntity? _token;

  MoodleSessionStore(this._secure, this._plain);

  MoodleTokenEntity? get token => _token;

  Future<MoodleTokenEntity?> load() async {
    try {
      final raw = await _secure.read(secureKey);
      if (raw == null) return null;
      _token = MoodleTokenEntity.fromJson(json.decode(raw));
      // 解析成功才刪明文那一份——解析失敗會落到下面的 catch，那時 secure
      // 這一份是壞的，明文那份是唯一還可能有用的副本。
      await _plain.remove(legacyKey);
      return _token;
    } catch (e, stack) {
      // 解不開就當作沒有 token，讓下一次 ensure 重新登入。
      // 不要清除：Keystore 暫時不可用時清掉會讓使用者白白重登。
      Log.eWithStack('moodle token unavailable: $e', stack);
      return null;
    }
  }

  Future<void> save(MoodleTokenEntity token) async {
    _token = token;
    await _secure.write(secureKey, json.encode(token));
  }

  Future<void> clear() async {
    _token = null;
    await _secure.delete(secureKey);
    // **舊 key 一定要一起刪。**
    //
    // 不刪的話：Model.logout() 先呼叫這裡，下一行就 getInstance()，而
    // getInstance() 看到 token 是 null 就會從 SharedPreferences 的 legacyKey
    // 把**前一位使用者的 token 遷移回 secure storage**。當下看不出來——
    // 下一次冷啟動 main.dart 的 restoreToken 才會把它撈回來，那時已經是
    // 另一個帳號了。
    await _plain.remove(legacyKey);
  }

  /// 從舊的 SharedPreferences 位置遷移。回傳是否有搬到東西。
  ///
  /// 讀回比對成功才刪舊 key。寫不進去或讀回來對不上時保留明文那一份——
  /// 那時它是唯一的副本，刪掉使用者就要重登 Moodle。
  Future<bool> migrateFrom(String? legacyRaw) async {
    if (legacyRaw == null) return false;
    try {
      final token = MoodleTokenEntity.fromJson(json.decode(legacyRaw));
      await save(token);
      final verify = await _secure.read(secureKey);
      if (verify != null &&
          MoodleTokenEntity.fromJson(json.decode(verify)).token ==
              token.token) {
        await _plain.remove(legacyKey);
      } else {
        Log.e('moodle token migration verify failed');
      }
      return true;
    } catch (e, stack) {
      Log.eWithStack('moodle token migration failed: $e', stack);
      return false;
    }
  }
}
