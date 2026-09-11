import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/controller/main_page/main_controller.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

const String _customUrl =
    'https://moodle2.ntust.edu.tw/pluginfile.php/110/user/icon/boost/f1?rev=1';
const String _newUrl =
    'https://moodle2.ntust.edu.tw/pluginfile.php/110/user/icon/boost/f1?rev=2';
const String _defaultUrl =
    'https://moodle2.ntust.edu.tw/theme/image.php/boost/core/1/u/f1';

/// 把「真的去換頭貼」那一步換掉，順便讓測試決定進度回報的節奏。
class _FakeRepo extends MoodleRepository {
  Result<MoodleAvatarChange> next = const Ok(MoodleAvatarChange(url: _newUrl));

  /// 每次呼叫要回報的進度（sent, total）。
  List<(int, int)> progress = const [(30, 100), (100, 100)];

  int calls = 0;
  CancelToken? lastToken;
  File? lastFile;

  /// 非 null 時，在回結果之前先跑這個（用來在「進行中」時再點一次）。
  Future<void> Function()? whileRunning;

  @override
  Future<Result<MoodleAvatarChange>> changeProfilePicture({
    File? file,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    calls++;
    lastFile = file;
    lastToken = cancelToken;
    for (final (sent, total) in progress) {
      onProgress?.call(sent, total);
    }
    await whileRunning?.call();
    return next;
  }
}

/// [MainController] 的換頭貼狀態機。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRepo repo;
  late MainController controller;

  setUpAll(() async {
    await loadTestL10n();
  });

  setUp(() {
    resetAppStatics();
    repo = _FakeRepo();
    MoodleRepository.instance = repo;
    AuthSession.instance = FakeAuthSession();
    ConnectivityProbe.instance = FakeConnectivityProbe();
    controller = MainController();
    PaintingBinding.instance.imageCache.clear();
  });

  tearDown(() {
    MoodleRepository.instance = MoodleRepository();
    AuthSession.instance = const UninstalledAuthSession();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
    MoodleWebApiConnector.wsPost = _throwingWsPost;
  });

  /// 讓 reloadProfile 拿到這一份 site_info。
  void stubProfile(String pictureUrl) {
    MoodleWebApiConnector.wsToken = 'token';
    MoodleWebApiConnector.wsPost = (parameter) async => {
          'username': 'b11234567',
          'firstname': '小明',
          'userpictureurl': pictureUrl,
        };
  }

  void givenProfile(String pictureUrl) {
    controller.profile.value =
        MoodleProfileEntity(username: 'b11234567', userpictureurl: pictureUrl);
  }

  test('進度從 null 走到有值再回 null', () async {
    givenProfile(_customUrl);
    stubProfile(_newUrl);
    final seen = <double?>[controller.avatarProgress.value];
    controller.avatarProgress.listen(seen.add);

    final error = await controller.changeAvatar(file: File('x.jpg'));

    expect(error, isNull);
    expect(seen.first, isNull);
    expect(seen, contains(0.3));
    expect(seen.last, isNull);
    expect(controller.isChangingAvatar, isFalse);
  });

  test('失敗時進度照樣清乾淨（finally）', () async {
    givenProfile(_customUrl);
    repo.next = Failed(FetchFailed(R.current.avatarProfileLocked));

    final error = await controller.changeAvatar(file: File('x.jpg'));

    expect(error, R.current.avatarProfileLocked);
    expect(controller.avatarProgress.value, isNull);
  });

  test('進行中再點一次是 no-op，repository 只會被叫一次', () async {
    givenProfile(_customUrl);
    stubProfile(_newUrl);
    String? second;
    repo.whileRunning = () async {
      second = await controller.changeAvatar(file: File('y.jpg'));
    };

    await controller.changeAvatar(file: File('x.jpg'));

    expect(repo.calls, 1);
    expect(second, isNull);
  });

  test('成功後換的是新實例，Obx 才會重畫', () async {
    givenProfile(_customUrl);
    stubProfile(_newUrl);
    final before = controller.profile.value;

    await controller.changeAvatar(file: File('x.jpg'));

    expect(identical(before, controller.profile.value), isFalse);
    expect(controller.profile.value!.userpictureurl, _newUrl);
  });

  test('舊網址一定會從 ImageCache 移掉', () async {
    givenProfile(_customUrl);
    stubProfile(_newUrl);
    final cache = PaintingBinding.instance.imageCache;
    const key = NetworkImage(_customUrl);
    cache.putIfAbsent(
        key, () => OneFrameImageStreamCompleter(Completer<ImageInfo>().future));
    expect(cache.containsKey(key), isTrue);

    await controller.changeAvatar(file: File('x.jpg'));

    expect(cache.containsKey(key), isFalse);
  });

  test('site_info 還回著舊網址時，用 update_picture 自己回的那一個補上', () async {
    givenProfile(_customUrl);
    // 伺服器端還在快取舊的 site_info。
    stubProfile(_customUrl);
    final before = controller.profile.value;

    await controller.changeAvatar(file: File('x.jpg'));

    expect(controller.profile.value!.userpictureurl, _newUrl);
    expect(identical(before, controller.profile.value), isFalse);
  });

  test('移除時把 file 留成 null', () async {
    givenProfile(_customUrl);
    stubProfile(_defaultUrl);
    repo.next = const Ok(MoodleAvatarChange(url: _defaultUrl));

    final error = await controller.changeAvatar();

    expect(error, isNull);
    expect(repo.lastFile, isNull);
  });

  group('hasCustomAvatar', () {
    test('自訂頭貼是 true', () {
      givenProfile(_customUrl);
      expect(controller.hasCustomAvatar, isTrue);
    });

    test('主題預設圖與沒有 profile 都是 false', () {
      givenProfile(_defaultUrl);
      expect(controller.hasCustomAvatar, isFalse);
      controller.profile.value = null;
      expect(controller.hasCustomAvatar, isFalse);
    });
  });

  test('cancelAvatarChange 取消進行中的上傳並清掉進度', () async {
    givenProfile(_customUrl);
    stubProfile(_newUrl);
    CancelToken? token;
    repo.whileRunning = () async {
      token = repo.lastToken;
      expect(controller.avatarProgress.value, isNotNull);
      controller.cancelAvatarChange();
    };

    await controller.changeAvatar(file: File('x.jpg'));

    expect(token!.isCancelled, isTrue);
    expect(controller.avatarProgress.value, isNull);
  });
}

Future<dynamic> _throwingWsPost(parameter) async =>
    throw StateError('測試沒有裝 wsPost');
