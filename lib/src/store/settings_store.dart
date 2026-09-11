import 'package:flutter/material.dart';
import 'package:flutter_app/src/store/key_value_store.dart';

/// 使用者偏好的單一出口。
///
/// **所有 key 名不可更動**，改名會讓已安裝的使用者升級後設定消失。
class SettingsStore {
  static SettingsStore instance = SettingsStore(SharedPrefsKeyValueStore());

  final KeyValueStore _store;

  SettingsStore(this._store);

  // ---- 主題 ----------------------------------------------------------------
  static const themeModeKey = 'isThemeMode';

  Future<int> get themeModeIndex async =>
      await _store.readInt(themeModeKey) ?? 0;

  Future<void> setThemeModeIndex(int index) =>
      _store.writeInt(themeModeKey, index);

  ThemeMode themeModeOf(int index) => ThemeMode.values[index];

  // ---- 檔案總管 ------------------------------------------------------------
  static const showHiddenFilesKey = 'hidden';
  static const fileSortKey = 'sort';

  Future<bool> get showHiddenFiles async =>
      await _store.readBool(showHiddenFilesKey) ?? false;

  Future<void> setShowHiddenFiles(bool value) =>
      _store.writeBool(showHiddenFilesKey, value);

  Future<int> get fileSort async => await _store.readInt(fileSortKey) ?? 0;

  Future<void> setFileSort(int value) => _store.writeInt(fileSortKey, value);

  // ---- 下載路徑 ------------------------------------------------------------
  static const downloadPathKey = 'download_path';

  Future<String?> get downloadPath async => _store.readString(downloadPathKey);

  Future<void> setDownloadPath(String value) =>
      _store.writeString(downloadPathKey, value);

  // ---- 公告已讀時間 --------------------------------------------------------
  static const announcementLastReadKey = 'announcement_last_read_time';

  /// 已讀時間。格式是「UTC 加 8 小時再 toString」，讀不到時退回 2000 年。
  Future<DateTime> get announcementLastRead async {
    final raw = await _store.readString(announcementLastReadKey);
    if (raw == null) return DateTime.utc(2000);
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return DateTime.utc(2000);
    }
  }

  Future<void> markAnnouncementRead() => markAnnouncementReadUpTo(
      DateTime.now().toUtc().add(const Duration(hours: 8)));

  /// 已讀時間寫到指定的一刻。[moment] 必須跟 [announcementLastRead] 同一個
  /// 座標系（UTC 欄位裝台北的牆上時間），公告的 `startTime` 正是這個格式。
  Future<void> markAnnouncementReadUpTo(DateTime moment) =>
      _store.writeString(announcementLastReadKey, moment.toString());
}
