import 'dart:convert';

import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_token_entity.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/score/score_json.dart';
import 'package:flutter_app/src/model/setting/setting_json.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/store/credentials_store.dart';
import 'package:flutter_app/src/store/moodle_session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 特徵化測試：凍結 `lib/src/store/model.dart`（Model 單例）目前的持久化行為，
/// 包含已知的 bug 與怪異之處。
///
/// 注意：這裡刻意不呼叫 `getInstance()` 與 `logout()`，它們會走到
/// `DioConnector.init()` / `deleteCookies()`，在 `flutter test` 裡需要
/// path_provider 與尚未初始化的 cookie jar。改為直接呼叫各個 load*/save*。
void main() {
  late TestStores stores;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestL10n();
  });

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    stores = resetAppStatics();
  });

  Future<SharedPreferences> pref() => SharedPreferences.getInstance();

  CourseTableJson makeTable(String studentId, String year, String semester) =>
      CourseTableJson(
        studentId: studentId,
        studentName: 'name_$studentId',
        courseSemester: SemesterJson(year: year, semester: semester),
      );

  group('user_data：帳號密碼的讀寫', () {
    test('setAccount / setPassword 經 saveUserData 與 loadUserData 可以來回',
        () async {
      await Model.instance.loadUserData();
      Model.instance.setAccount('B10902000');
      Model.instance.setPassword('p@ssw0rd');
      await Model.instance.saveUserData();

      // 先把記憶體狀態洗掉，確認真的是從 SharedPreferences 讀回來的
      Model.instance.setAccount('');
      Model.instance.setPassword('');
      await Model.instance.loadUserData();

      expect(Model.instance.getAccount(), 'B10902000');
      expect(Model.instance.getPassword(), 'p@ssw0rd');
    });

    test('帳密存在 secure storage，不再出現在 SharedPreferences', () async {
      await Model.instance.loadUserData();
      Model.instance.setAccount('B10902000');
      Model.instance.setPassword('p@ssw0rd');
      await Model.instance.saveUserData();

      // 密碼不能落在 SharedPreferences：那是明文 JSON，拿得到檔案就讀得出來。
      expect((await pref()).getString(Model.userDataJsonKey), isNull);

      // 它在 secure storage（Android Keystore / iOS Keychain）。
      expect(
          stores.secure.data[CredentialsStore.secureKey], contains('p@ssw0rd'));

      // 帳號另外鏡像一份非機密副本，供 UI 的「已登入」謂詞使用。
      expect((await pref()).getString(CredentialsStore.accountMirrorKey),
          'B10902000');
    });

    test('沒有存過時 loadUserData 會得到全空的 UserDataJson', () async {
      await Model.instance.loadUserData();
      expect(Model.instance.getAccount(), '');
      expect(Model.instance.getPassword(), '');
    });
  });

  group('course_table_list：課表清單', () {
    test('saveCourseTableList / loadCourseTableList 來回，且以 StringList 存放',
        () async {
      await Model.instance.loadCourseTableList();
      Model.instance.addCourseTable(makeTable('B10902000', '112', '1'));
      Model.instance.addCourseTable(makeTable('B10902000', '112', '2'));
      await Model.instance.saveCourseTableList();

      // _save 先試 _saveJsonList，List 可迭代所以成功 -> 存成 StringList 而非單一字串
      final rawList = (await pref()).getStringList(Model.courseTableJsonKey);
      expect(rawList, isNotNull);
      expect(rawList!.length, 2);
      expect(json.decode(rawList.first)['studentId'], 'B10902000');

      await Model.instance.loadCourseTableList();
      final loaded = Model.instance.getCourseTableList();
      expect(loaded.length, 2);
      // getCourseTableList 會就地排序：同學號時學期字串大的在前
      expect(loaded.first.courseSemester.semester, '2');
      expect(
        Model.instance
            .getCourseTable(
                'B10902000', SemesterJson(year: '112', semester: '1'))
            ?.studentName,
        'name_B10902000',
      );
    });

    test('addCourseTable 以 (studentId, semester) 去重，後寫的覆蓋前一筆', () async {
      await Model.instance.loadCourseTableList();
      Model.instance.addCourseTable(makeTable('B10902000', '112', '1'));

      final replacement = makeTable('B10902000', '112', '1');
      replacement.studentName = '改過的名字';
      Model.instance.addCourseTable(replacement);

      final list = Model.instance.getCourseTableList();
      expect(list.length, 1);
      expect(list.first.studentName, '改過的名字');

      // 學號不同就不算重複
      Model.instance.addCourseTable(makeTable('B10902001', '112', '1'));
      expect(Model.instance.getCourseTableList().length, 2);
    });

    test('removeCourseTable 以 removeWhere 移除，重複項會一次清乾淨', () async {
      // 直接在 SharedPreferences 埋兩筆完全相同的課表，模擬舊版寫入或
      // 存檔損毀留下的重複資料（addCourseTable 自己不會產生重複）。
      final dup = json.encode(makeTable('B10902000', '112', '1'));
      SharedPreferences.setMockInitialValues({
        Model.courseTableJsonKey: <String>[dup, dup],
      });
      await Model.instance.loadCourseTableList();
      expect(Model.instance.getCourseTableList().length, 2);

      Model.instance.removeCourseTable(makeTable('B10902000', '112', '1'));

      // 必須用 removeWhere：正向迴圈裡 removeAt 會跳過緊接著的那一筆
      // （移除後 i++ 越界結束），重複資料只會清掉一半。
      expect(Model.instance.getCourseTableList().length, 0);
    });

    test('承上：清單已有重複時 addCourseTable 會把重複一併去掉', () async {
      final dup = json.encode(makeTable('B10902000', '112', '1'));
      SharedPreferences.setMockInitialValues({
        Model.courseTableJsonKey: <String>[dup, dup],
      });
      await Model.instance.loadCourseTableList();

      final replacement = makeTable('B10902000', '112', '1');
      replacement.studentName = '改過的名字';
      Model.instance.addCourseTable(replacement);

      // 漏刪會留下舊資料，而 getCourseTable 回傳排序後先命中的那一筆，
      // 可能就是舊的那份。
      final list = Model.instance.getCourseTableList();
      expect(list.length, 1);
      expect(list.single.studentName, '改過的名字');
    });
  });

  group('setting：設定', () {
    test('saveSetting / loadSetting 來回，且以單一 JSON 字串存在 setting', () async {
      await Model.instance.loadSetting();
      Model.instance.setOtherSetting(OtherSettingJson(
        lang: 'zh',
        useExternalVideoPlayer: true,
        useMoodleWebApi: false,
      ));
      await Model.instance.saveSetting();

      // SettingJson 不可迭代，_saveJsonList 會丟例外並 fallback 到 _saveJson
      final raw = (await pref()).getString(Model.settingJsonKey);
      expect(raw, isNotNull);
      final decoded = json.decode(raw!) as Map<String, dynamic>;
      expect(decoded.keys, containsAll(<String>['course', 'other']));
      expect(decoded['other']['lang'], 'zh');

      await Model.instance.loadSetting();
      expect(Model.instance.getOtherSetting().lang, 'zh');
      expect(Model.instance.getOtherSetting().useExternalVideoPlayer, isTrue);
      expect(Model.instance.getOtherSetting().useMoodleWebApi, isFalse);
    });
  });

  group('score_credit：成績', () {
    test('saveScore / loadScore 來回', () async {
      await Model.instance.loadScore();
      final semester = SemesterJson(year: '112', semester: '1');
      final score = ScoreRankJson();
      score.addScoreBySemester(
        semester,
        ScoreItemJson(
          courseId: 'CS101',
          name: '計算機概論',
          credit: '3',
          score: 'A+',
          generalDimension: '',
          remark: '',
        ),
      );
      Model.instance.setScore(score);
      await Model.instance.saveScore();

      final raw = (await pref()).getString(Model.scoreCreditJsonKey);
      expect(raw, isNotNull);
      expect(json.decode(raw!)['info'], hasLength(1));

      Model.instance.setScore(ScoreRankJson());
      await Model.instance.loadScore();
      final loaded = Model.instance.getScore();
      expect(loaded.info.length, 1);
      expect(loaded.info.first.item.first.courseId, 'CS101');
      expect(loaded.info.first.item.first.score, 'A+');
    });
  });

  group('moodle_token：Moodle 權杖', () {
    test('setMoodleToken / getMoodleToken 來回，key 是 private_token（與欄位名不同）',
        () async {
      await Model.instance
          .setMoodleToken(MoodleTokenEntity('sig', 'ws-token', 'pv-token'));

      // token 存在 secure storage，不是 SharedPreferences。
      expect((await pref()).getString('moodle_token'), isNull);

      // MoodleTokenEntity 手寫的 toJson 把 privateToken 序列化成 private_token
      expect(
        stores.secure.data[MoodleSessionStore.secureKey],
        '{"signature":"sig","token":"ws-token","private_token":"pv-token"}',
      );

      final token = await Model.instance.getMoodleToken();
      expect(token, isNotNull);
      expect(token!.signature, 'sig');
      expect(token.token, 'ws-token');
      expect(token.privateToken, 'pv-token');
    });

    test('沒有存過時 getMoodleToken 回傳 null', () async {
      expect(await Model.instance.getMoodleToken(), isNull);
    });

    test('Model 讀寫 token 不再有副作用（store 不再反向相依 connector）', () async {
      expect(MoodleWebApiConnector.wsToken, isNull);

      await Model.instance
          .setMoodleToken(MoodleTokenEntity('sig', 'ws-token', 'pv-token'));
      final token = await Model.instance.getMoodleToken();

      // store 層只負責存取，還原 static 由 main.dart 呼叫 restoreToken 完成。
      expect(token, isNotNull);
      expect(MoodleWebApiConnector.wsToken, isNull);
    });

    test('restoreToken 由呼叫端負責，且 clearMoodleToken 不會把它還原（已知不對稱）', () async {
      await Model.instance
          .setMoodleToken(MoodleTokenEntity('sig', 'ws-token', 'pv-token'));
      MoodleWebApiConnector.restoreToken(
          (await Model.instance.getMoodleToken())!);

      expect(MoodleWebApiConnector.wsToken, 'ws-token');

      await Model.instance.clearMoodleToken();

      expect(await Model.instance.getMoodleToken(), isNull);
      // 登出後 process 內仍然是「已登入 Moodle」狀態，直到重開 App 為止：
      // clearMoodleToken 只 remove key，沒有把 restoreToken 寫進去的 static 還原。
      expect(MoodleWebApiConnector.wsToken, 'ws-token');
    });
  });

  group('course_semester_list：學期清單', () {
    test('setSemesterJsonList 之後重新載入會變成空的（存檔函式已刪除）', () async {
      Model.instance.setSemesterJsonList([
        SemesterJson(year: '112', semester: '1'),
        SemesterJson(year: '112', semester: '2'),
      ]);
      expect(Model.instance.getSemesterList().length, 2);
      expect(Model.instance.getSemesterJsonItem(0)?.semester, '1');
      expect(Model.instance.getSemesterJsonItem(5), isNull);

      // 沒有任何函式會寫 course_semester_list 這個 key；
      // setSemesterJsonList 只是記憶體快取，重新載入就全數消失。
      await Model.instance.loadSemesterJsonList();
      expect(Model.instance.getSemesterList(), isEmpty);
      expect((await pref()).getStringList(Model.courseSemesterJsonKey), isNull);
    });
  });

  group('getFirstUse / setAlreadyUse', () {
    test('沒有 timeOut 時只看記憶體旗標，要靠 setAlreadyUse 才會變 false', () async {
      const key = 'model_test_first_use_no_timeout';
      expect(await Model.instance.getFirstUse(key), isTrue);
      // 沒有 timeOut 就不會自動翻轉，呼叫幾次都還是 true
      expect(await Model.instance.getFirstUse(key), isTrue);

      Model.instance.setAlreadyUse(key);
      expect(await Model.instance.getFirstUse(key), isFalse);
    });

    test('帶 timeOut 時第二次就回 false，而且旗標是寫在 SharedPreferences 的時間戳', () async {
      const key = 'model_test_first_use_with_timeout';
      expect(await Model.instance.getFirstUse(key, timeOut: 60), isTrue);
      // 第一次呼叫就寫入 "${key}_timestamp" = now + 60s，
      // 第二次在到期前直接回 false，完全不看 _firstRun。
      expect(await Model.instance.getFirstUse(key, timeOut: 60), isFalse);

      final stamp = (await pref()).getInt('${key}_timestamp');
      expect(stamp, isNotNull);
      expect(stamp! > DateTime.now().millisecondsSinceEpoch, isTrue);

      // 兩種旗標的儲存位置不一致（一個在記憶體、一個在 prefs），
      // 所以同一個 key 用不用 timeOut 會得到不同語意。
      expect(await Model.instance.getFirstUse(key), isTrue);
    });
  });
}
