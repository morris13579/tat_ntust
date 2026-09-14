import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_setting_entity.dart';
import 'package:flutter_app/src/model/ntust/ap_tree_json.dart';
import 'package:flutter_app/src/native/moodle_setting_bridge.dart';
import 'package:flutter_app/src/native/more_bridge.dart';
import 'package:flutter_app/src/native/sub_system_bridge.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/ntust_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/store/settings_store.dart';
import 'package:flutter_app/src/util/moodle_setting_utils.dart';
import 'package:flutter_app/src/util/sub_system_pins.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

class _FakeNtust extends NtustRepository {
  Result<List<APTreeJson>> next = const Ok([]);

  @override
  Future<Result<List<APTreeJson>>> getSubSystemTree() async => next;
}

/// 上傳一半報一次、傳完報一次；第一次量不出總量。
class _FakeMoodle extends MoodleRepository {
  @override
  Future<Result<MoodleAvatarChange>> changeProfilePicture({
    File? file,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    onProgress?.call(0, 0);
    onProgress?.call(512, 1024);
    onProgress?.call(1024, 1024);
    return const Failed(FetchFailed('上傳失敗'));
  }
}

MoodleSettingEntity settings({bool emailOn = false}) => MoodleSettingEntity(
      preferences: MoodleSettingPreferences(
        processors: [
          MoodleSettingPreferencesProcessors(name: 'popup', displayname: 'Web'),
          MoodleSettingPreferencesProcessors(
              name: 'airnotifier', displayname: 'Mobile'),
          MoodleSettingPreferencesProcessors(
              name: 'email', displayname: 'Email'),
        ],
        components: [
          MoodleSettingPreferencesComponents(
            displayname: '作業',
            notifications: [
              MoodleSettingPreferencesComponentsNotifications(
                displayname: '作業通知',
                preferencekey: 'assign_notification',
                processors: [
                  MoodleSettingPreferencesComponentsNotificationsProcessors(
                      name: 'popup', enabled: true),
                  MoodleSettingPreferencesComponentsNotificationsProcessors(
                      name: 'email', enabled: emailOn),
                ],
              ),
            ],
          ),
        ],
      ),
    );

/// 原生版「更多」底下幾頁拿到的東西：Moodle 通知設定怎麼寫、資訊系統的分類、外觀。
void main() {
  setUpAll(() async => loadTestL10n());

  setUp(() {
    resetAppStatics();
    AuthSession.instance = FakeAuthSession();
  });

  group('Moodle 通知設定', () {
    test('分頁拿掉行動裝置、照名稱排', () {
      expect(
          MoodleSettingUtils.visibleProcessors(
                  settings().preferences.processors)
              .map((p) => p.name),
          ['email', 'popup']);
    });

    test('開關一種方式時送出這一項開著的整份清單；找不到那一項回 null', () {
      final components = settings().preferences.components;

      expect(
          MoodleSettingUtils.valuesAfterToggle(
              components, 'assign_notification', 'email', true),
          ['popup', 'email']);
      expect(
          MoodleSettingUtils.valuesAfterToggle(
              components, 'assign_notification', 'popup', false),
          isEmpty);
      expect(
          MoodleSettingUtils.valuesAfterToggle(
              components, 'missing', 'email', true),
          isNull);
    });

    test('寫入之後重抓，畫面拿到的是伺服器上的狀態', () async {
      var emailOn = false;
      final writes = <String>[];
      final bridge = MoodleSettingBridge(
        fetch: () async => settings(emailOn: emailOn),
        write: (key, values) async {
          writes.add('$key=${values.join(',')}');
          emailOn = values.contains('email');
          return true;
        },
      );

      final loaded = (await bridge.load())!;
      final updated =
          (await bridge.toggle('assign_notification', 'email', true))!;

      expect(loaded.processors.map((p) => p.name), ['email', 'popup']);
      expect(loaded.groups.single.settings.single.enabled, ['popup']);
      expect(writes, ['assign_notification=popup,email']);
      expect(updated.groups.single.settings.single.enabled, ['popup', 'email']);
    });

    test('還沒載入或寫入失敗時回 null', () async {
      final bridge = MoodleSettingBridge(
        fetch: () async => settings(),
        write: (key, values) async => false,
      );

      expect(await bridge.toggle('assign_notification', 'email', true), isNull);
      await bridge.load();
      expect(await bridge.toggle('assign_notification', 'email', true), isNull);
    });
  });

  group('資訊系統', () {
    late _FakeNtust ntust;

    setUp(() {
      ntust = _FakeNtust();
      NtustRepository.instance = ntust;
    });

    tearDown(() => NtustRepository.instance = NtustRepository());

    test('分類與服務原樣帶過去', () async {
      ntust.next = Ok([
        APTreeJson('service-1', [
          APListJson(
              name: '選課系統', url: 'https://courseselection.ntust.edu.tw/'),
        ]),
      ]);

      final tree = await SubSystemBridge().tree();

      final service = tree.categories.single.services.single;
      expect(tree.categories.single.serviceId, 'service-1');
      expect((service.name, service.url),
          ('選課系統', 'https://courseselection.ntust.edu.tw/'));
      expect((tree.error, tree.notice), (null, null));
    });

    test('空教室只釘在「校園資訊」，那一類沒有服務時也照樣帶過去', () async {
      ntust.next = Ok([
        APTreeJson('service-1', [
          APListJson(
              name: '選課系統', url: 'https://courseselection.ntust.edu.tw/'),
        ]),
        APTreeJson(classroomPinnedCategory, []),
      ]);

      final tree = await SubSystemBridge().tree();

      expect(tree.categories.map((c) => (c.serviceId, c.pinsClassroom)),
          [('service-1', false), (classroomPinnedCategory, true)]);
    });

    test('失敗時帶訊息與登入狀態；拿到快取時帶上原因', () async {
      AuthSession.instance = FakeAuthSession(isSignedIn: false);
      ntust.next = const Failed(NotSignedIn());

      final failed = await SubSystemBridge().tree();
      ntust.next =
          Stale([APTreeJson('service-6', [])], const FetchFailed('離線'));
      final stale = await SubSystemBridge().tree();

      expect(failed.categories, isEmpty);
      expect(failed.error, isNotNull);
      expect(failed.signedIn, isFalse);
      expect((stale.categories.length, stale.notice, stale.error),
          (1, '離線', null));
    });
  });

  group('更多', () {
    test('換頭貼的上傳進度照比例報給原生端，量不出總量的那一次不報', () async {
      final progress = <TransferProgress>[];
      MoodleRepository.instance = _FakeMoodle();
      addTearDown(() => MoodleRepository.instance = MoodleRepository());

      final message =
          await MoreBridge(onProgress: progress.add).changeAvatar(null);

      expect(message, '上傳失敗');
      expect(progress.map((p) => (p.key, p.progress, p.phase)), [
        ('avatar', 0.5, TransferPhase.upload),
        ('avatar', 1.0, TransferPhase.upload),
      ]);
    });

    test('登入狀態跟著 AuthSession；沒登入時不抓個人資料', () async {
      expect(MoreBridge().isSignedIn(), isTrue);

      AuthSession.instance = FakeAuthSession(isSignedIn: false);

      expect(MoreBridge().isSignedIn(), isFalse);
      expect(await MoreBridge().profile(false), isNull);
    });

    test('外觀跟 Flutter 版的 ThemeMode 存在同一個索引', () async {
      final bridge = MoreBridge();

      expect(await bridge.theme(), ThemeChoice.system);
      await bridge.setTheme(ThemeChoice.dark);

      expect(await bridge.theme(), ThemeChoice.dark);
      expect(await SettingsStore.instance.themeModeIndex, 2);
    });
  });
}
