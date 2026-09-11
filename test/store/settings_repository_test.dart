import 'package:flutter_app/src/store/key_value_store.dart';
import 'package:flutter_app/src/store/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// 這一組測試的重點是 **key 名與預設值的相容性**。
///
/// 只要有一個 key 名打錯，已安裝的使用者升級後對應的設定就會靜默消失。
/// 這裡逐字釘住每一個 key，以及讀不到時的預設值。
void main() {
  late InMemoryKeyValueStore store;
  late SettingsStore repo;

  setUp(() {
    store = InMemoryKeyValueStore();
    repo = SettingsStore(store);
  });

  group('key 名逐字不變（升級相容性契約）', () {
    test('五個 key 的字面值', () {
      expect(SettingsStore.themeModeKey, 'isThemeMode');
      expect(SettingsStore.showHiddenFilesKey, 'hidden');
      expect(SettingsStore.fileSortKey, 'sort');
      expect(SettingsStore.downloadPathKey, 'download_path');
      expect(
          SettingsStore.announcementLastReadKey, 'announcement_last_read_time');
    });

    test('寫入後底層存的就是那些 key', () async {
      await repo.setThemeModeIndex(2);
      await repo.setShowHiddenFiles(true);
      await repo.setFileSort(3);
      await repo.setDownloadPath('/tmp/x');
      await repo.markAnnouncementRead();

      expect(
        store.raw.keys.toSet(),
        {
          'isThemeMode',
          'hidden',
          'sort',
          'download_path',
          'announcement_last_read_time',
        },
      );
    });

    test('讀得回舊版本已經寫在那些 key 上的值', () async {
      store.raw
        ..['isThemeMode'] = 1
        ..['hidden'] = true
        ..['sort'] = 2
        ..['download_path'] = '/storage/emulated/0/TAT';

      expect(await repo.themeModeIndex, 1);
      expect(await repo.showHiddenFiles, isTrue);
      expect(await repo.fileSort, 2);
      expect(await repo.downloadPath, '/storage/emulated/0/TAT');
    });
  });

  group('預設值', () {
    test('沒存過時各自回原本的預設', () async {
      expect(await repo.themeModeIndex, 0);
      expect(await repo.showHiddenFiles, isFalse);
      expect(await repo.fileSort, 0);
      expect(await repo.downloadPath, isNull);
    });

    test('公告已讀時間沒存過時退回 2000 年，維持原本行為', () async {
      expect(await repo.announcementLastRead, DateTime.utc(2000));
    });

    test('公告已讀時間存了壞字串時也退回 2000 年而不是拋例外', () async {
      store.raw['announcement_last_read_time'] = '不是日期';
      expect(await repo.announcementLastRead, DateTime.utc(2000));
    });
  });

  group('公告已讀時間的格式', () {
    test('沿用原本 UTC 加 8 小時的寫法', () async {
      final before = DateTime.now().toUtc().add(const Duration(hours: 8));
      await repo.markAnnouncementRead();
      final stored =
          DateTime.parse(store.raw['announcement_last_read_time'] as String);

      // 允許幾秒誤差，重點是它存的是 UTC+8 而不是本地時間或純 UTC。
      expect(stored.difference(before).abs().inSeconds, lessThan(5));
    });

    test('寫入後讀得回來', () async {
      await repo.markAnnouncementRead();
      final read = await repo.announcementLastRead;
      expect(read.isAfter(DateTime.utc(2000)), isTrue);
    });
  });

  group('themeModeOf', () {
    test('index 對映到 ThemeMode 的宣告順序', () {
      expect(repo.themeModeOf(0).index, 0);
      expect(repo.themeModeOf(1).index, 1);
      expect(repo.themeModeOf(2).index, 2);
    });
  });
}
