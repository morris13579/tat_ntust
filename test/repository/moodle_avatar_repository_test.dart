import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_user_picture.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/util/file_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprintf/sprintf.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 不打網路的 [MoodleRepository]：只換掉兩個真的會送出去的步驟。
class _FakeRepo extends MoodleRepository {
  int? nextDraftId = 777;
  MoodleUpdatePictureResult? nextResult;

  /// 非 null 時，[writeDraftFile] 改成丟這個。
  MoodleApiException? draftError;

  /// 非 null 時，[writeProfilePicture] 改成丟這個。
  MoodleApiException? pictureError;

  int draftCalls = 0;
  int pictureCalls = 0;
  int? lastDraftItemId;
  bool? lastDelete;
  String? lastFilename;

  @override
  Future<int?> writeDraftFile(
    File file, {
    required String filename,
    int? draftItemId,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    draftCalls++;
    lastFilename = filename;
    final error = draftError;
    if (error != null) throw error;
    onProgress?.call(50, 100);
    return nextDraftId;
  }

  @override
  Future<MoodleUpdatePictureResult?> writeProfilePicture({
    required int draftItemId,
    bool delete = false,
  }) async {
    pictureCalls++;
    lastDraftItemId = draftItemId;
    lastDelete = delete;
    final error = pictureError;
    if (error != null) throw error;
    return nextResult;
  }
}

/// [MoodleRepository.changeProfilePicture] 的行為：站台前置檢查、
/// success 的兩種語意、errorcode 對訊息。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRepo repo;
  late FakeAuthSession auth;
  late RecordingUi ui;
  late FakeConnectivityProbe net;
  late Directory tempDir;

  setUpAll(() async {
    await loadTestL10n();
  });

  setUp(() {
    resetAppStatics();
    repo = _FakeRepo();
    auth = FakeAuthSession();
    ui = RecordingUi(decisions: const [RetryDecision.retry]);
    net = FakeConnectivityProbe();
    MoodleRepository.instance = repo;
    AuthSession.instance = auth;
    TaskUiDelegate.instance = ui;
    ConnectivityProbe.instance = net;
    tempDir = Directory.systemTemp.createTempSync('avatar_repo_test');
  });

  tearDown(() {
    MoodleRepository.instance = MoodleRepository();
    AuthSession.instance = const UninstalledAuthSession();
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  File makeFile({int bytes = 128, String name = 'pic.jpg'}) {
    final file = File('${tempDir.path}/$name');
    file.writeAsBytesSync(List<int>.filled(bytes, 1));
    return file;
  }

  void siteInfo({int uploadfiles = 1, int maxUpload = -1}) {
    MoodleWebApiConnector.siteInfo = MoodleProfileEntity(
      uploadfiles: uploadfiles,
      usermaxuploadfilesize: maxUpload,
    );
  }

  MoodleUpdatePictureResult ok(String url) =>
      MoodleUpdatePictureResult(success: true, profileimageurl: url);

  test('上傳成功回 Ok，第一段的 itemid 就是第二段送出去的那個', () async {
    siteInfo();
    repo.nextDraftId = 614509342;
    repo.nextResult = ok('https://moodle2.ntust.edu.tw/pluginfile.php/1/user/'
        'icon/boost/f1?rev=99');

    final result =
        await MoodleRepository.instance.changeProfilePicture(file: makeFile());

    expect(result, isA<Ok<MoodleAvatarChange>>());
    expect(result.dataOrNull!.url, contains('rev=99'));
    expect(repo.lastDraftItemId, 614509342);
    expect(repo.lastDelete, isFalse);
  });

  test('移除不上傳檔案，draftitemid 送 0、delete 送 true', () async {
    siteInfo();
    repo.nextResult = ok('https://moodle2.ntust.edu.tw/theme/image.php/x/u/f1');

    final result = await MoodleRepository.instance.changeProfilePicture();

    expect(result, isA<Ok<MoodleAvatarChange>>());
    expect(repo.draftCalls, 0);
    expect(repo.lastDraftItemId, 0);
    expect(repo.lastDelete, isTrue);
  });

  test('站台關掉檔案上傳時連傳都不傳', () async {
    siteInfo(uploadfiles: 0);

    final result =
        await MoodleRepository.instance.changeProfilePicture(file: makeFile());

    expect(result, isA<Failed<MoodleAvatarChange>>());
    expect((result as Failed).reason.message, R.current.avatarUploadDisabled);
    expect(repo.draftCalls, 0);
  });

  test('超過站台上限時本地就擋下來，不做注定失敗的上傳', () async {
    siteInfo(maxUpload: 64);

    final result = await MoodleRepository.instance
        .changeProfilePicture(file: makeFile(bytes: 128));

    expect(result, isA<Failed<MoodleAvatarChange>>());
    expect(
      (result as Failed).reason.message,
      sprintf(R.current.avatarTooLarge, [FileUtils.formatBytes(64, 1)]),
    );
    expect(repo.draftCalls, 0);
  });

  test('usermaxuploadfilesize 是 -1 時完全不做大小檢查', () async {
    siteInfo(maxUpload: -1);
    repo.nextResult = ok('https://moodle2.ntust.edu.tw/x');

    final result = await MoodleRepository.instance
        .changeProfilePicture(file: makeFile(bytes: 1024));

    expect(result, isA<Ok<MoodleAvatarChange>>());
    expect(repo.draftCalls, 1);
  });

  test('上傳路徑的 success:false 是「Moodle 解不開這張圖」', () async {
    siteInfo();
    repo.nextResult = MoodleUpdatePictureResult(success: false);

    final result =
        await MoodleRepository.instance.changeProfilePicture(file: makeFile());

    expect((result as Failed).reason.message, R.current.avatarInvalidImage);
  });

  test('刪除路徑的 success:false 不是錯誤——本來就沒有頭貼', () async {
    siteInfo();
    repo.nextResult = MoodleUpdatePictureResult(success: false);

    final result = await MoodleRepository.instance.changeProfilePicture();

    expect(result, isA<Ok<MoodleAvatarChange>>());
    expect(result.dataOrNull!.url, isEmpty);
  });

  test('沒有網路時兩段都不跑', () async {
    siteInfo();
    net.online = false;

    final result =
        await MoodleRepository.instance.changeProfilePicture(file: makeFile());

    expect((result as Failed).reason, isA<Offline>());
    expect(repo.draftCalls, 0);
    expect(repo.pictureCalls, 0);
  });

  test('retry: none——失敗不會問使用者，也就不會再上傳一次', () async {
    siteInfo();
    repo.pictureError = MoodleApiException(
        wsFunction: 'core_user_update_picture', errorcode: 'noprofileedit');

    final result =
        await MoodleRepository.instance.changeProfilePicture(file: makeFile());

    expect(result, isA<Failed<MoodleAvatarChange>>());
    // RecordingUi 準備好要回「重試」了，但這條路根本不該問。
    expect(ui.confirmCalls, 0);
    expect(repo.draftCalls, 1);
  });

  test('送出進度會傳到呼叫端', () async {
    siteInfo();
    repo.nextResult = ok('https://moodle2.ntust.edu.tw/x');
    final seen = <double>[];

    await MoodleRepository.instance.changeProfilePicture(
        file: makeFile(), onProgress: (s, t) => seen.add(s / t));

    expect(seen, [0.5]);
  });

  test('檔名一律正規化，副檔名只看是不是 png', () async {
    siteInfo();
    repo.nextResult = ok('https://moodle2.ntust.edu.tw/x');

    await MoodleRepository.instance
        .changeProfilePicture(file: makeFile(name: 'scaled_foo.WEBP'));
    expect(repo.lastFilename, 'profile_picture.jpg');

    await MoodleRepository.instance
        .changeProfilePicture(file: makeFile(name: 'shot.PNG'));
    expect(repo.lastFilename, 'profile_picture.png');
  });

  group('avatarFailureMessage', () {
    String messageFor(String code) => avatarFailureMessage(
        MoodleApiException(wsFunction: 'x', errorcode: code));

    test('每一個認得的 errorcode 都有自己的一句話', () {
      expect(messageFor('accessexception'), R.current.avatarNotSupported);
      expect(messageFor('userimagesdisabled'), R.current.avatarDisabledOnSite);
      expect(messageFor('noprofileedit'), R.current.avatarProfileLocked);
      expect(messageFor('nopermissions'), R.current.avatarNoPermission);
      expect(messageFor('userquotalimit'), R.current.avatarTooLargeUnknown);
      expect(messageFor('fileoversized'), R.current.avatarTooLargeUnknown);
    });

    test('認不得的一律退回通用訊息，不把 Moodle 的英文原文丟到畫面上', () {
      expect(messageFor('somethingnewin2030'), R.current.avatarUpdateError);
      expect(avatarFailureMessage(MoodleApiException(wsFunction: 'x')),
          R.current.avatarUpdateError);
    });
  });

  test('上傳那一段的 errorcode 也走同一張對照表', () async {
    siteInfo();
    repo.draftError = MoodleApiException(
        wsFunction: MoodleWebApiConnector.uploadEndpoint,
        errorcode: 'userquotalimit');

    final result =
        await MoodleRepository.instance.changeProfilePicture(file: makeFile());

    expect((result as Failed).reason.message, R.current.avatarTooLargeUnknown);
    expect(repo.pictureCalls, 0);
  });
}
