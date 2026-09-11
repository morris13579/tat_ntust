import 'dart:convert';

import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/score/score_json.dart';
import 'package:flutter_app/src/model/setting/setting_json.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// `Model.getInstance()` 在載入失敗時的行為。
///
/// 解析失敗只記錄並回報，磁碟上的原始位元組必須原封不動：回寫空物件等於
/// 「一個位元組壞掉就當場永久刪除」，而 setting（語言、自動更新偏好、目前顯示
/// 的課表）是唯一沒有伺服器副本可以重抓的一包。記憶體退回預設值讓 App 照常
/// 開起來，等下一次正常的 saveX 覆蓋掉。setting 另外多一層逐段搶救，
/// `course` 壞掉不會連 `other` 一起陪葬。
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestL10n();
  });

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    resetAppStatics();
  });

  Future<SharedPreferences> pref() => SharedPreferences.getInstance();

  CourseTableJson makeTable() => CourseTableJson(
        studentId: 'B10902000',
        studentName: '王小明',
        courseSemester: SemesterJson(year: '112', semester: '1'),
      );

  /// 一段可以正常解析的 `course`，用來確認另一段壞掉時它還活著。
  Map<String, dynamic> validCourseSection() => <String, dynamic>{
        'info': json.decode(json.encode(makeTable())) as Map<String, dynamic>,
      };

  group('解析失敗不再把空物件回寫覆蓋原始 blob', () {
    test('setting 整包解不開時，磁碟上的原始字串一個字都沒被動到', () async {
      // 被截斷的 blob：連 json.decode 都過不了。
      const broken = '{"course":{"info":{"studentId":"B109';
      SharedPreferences.setMockInitialValues({Model.settingJsonKey: broken});

      expect(await Model.instance.getInstance(), isTrue);

      // 把 SettingJson() 寫回同一個 key 的話，使用者的語言與目前顯示的課表
      // 就此消失且無法還原。
      expect((await pref()).getString(Model.settingJsonKey), broken);
    });

    test('setting 解不開時記憶體退回預設值，App 仍然開得起來', () async {
      SharedPreferences.setMockInitialValues({Model.settingJsonKey: '不是 JSON'});

      await Model.instance.getInstance();

      expect(Model.instance.getOtherSetting().lang, '');
      expect(Model.instance.getOtherSetting().useMoodleWebApi, isTrue);
      expect(Model.instance.getCourseSetting().info.studentId, '');
    });

    test('course_table_list 有壞行時，整份 StringList 不會被清成空的', () async {
      final good = json.encode(makeTable());
      SharedPreferences.setMockInitialValues({
        Model.courseTableJsonKey: <String>[good, '{壞掉的那一行'],
      });

      expect(await Model.instance.getInstance(), isTrue);

      // 寫入空 StringList 的話，連好的那一行都會一起消失。
      final raw = (await pref()).getStringList(Model.courseTableJsonKey);
      expect(raw, hasLength(2));
      expect(raw!.first, good);

      // 記憶體拿到的是「已成功解析的前綴」而不是空清單。這是
      // CourseTableStore.load 先清空再逐行 add 的既有結構造成的，
      // 刻意保留：有一張課表可看比一張都沒有好。
      expect(Model.instance.getCourseTableList(), hasLength(1));
    });

    test('score_credit 解不開時，磁碟上的原始字串沒被動到', () async {
      const broken = '{"info":[{"semester":';
      SharedPreferences.setMockInitialValues(
          {Model.scoreCreditJsonKey: broken});

      expect(await Model.instance.getInstance(), isTrue);

      expect((await pref()).getString(Model.scoreCreditJsonKey), broken);
      // 記憶體是空的 ScoreRankJson，不是 null。
      expect(Model.instance.getScore().info, isEmpty);
    });

    test('壞掉的 blob 會被下一次正常的 saveX 覆蓋掉，不會永遠卡著', () async {
      const broken = '不是 JSON';
      SharedPreferences.setMockInitialValues({Model.settingJsonKey: broken});
      await Model.instance.getInstance();

      // 這就是「自己痊癒」的路徑：使用者改了設定，正常寫入蓋過去。
      Model.instance.setOtherSetting(OtherSettingJson(lang: 'zh'));
      await Model.instance.saveSetting();

      final raw = (await pref()).getString(Model.settingJsonKey);
      expect(raw, isNot(broken));
      expect((json.decode(raw!) as Map)['other']['lang'], 'zh');
    });
  });

  group('setting 逐段搶救：一段壞掉不拖累另一段', () {
    test('course 段型別錯時，語言與影片播放器偏好仍然救得回來', () async {
      // studentId 宣告是 String，這裡放 int：整包 SettingJson.fromJson 會拋。
      final blob = json.encode(<String, dynamic>{
        'course': <String, dynamic>{
          'info': <String, dynamic>{'studentId': 12345},
        },
        'other': <String, dynamic>{
          'lang': 'zh',
          'useExternalVideoPlayer': true
        },
      });
      SharedPreferences.setMockInitialValues({Model.settingJsonKey: blob});

      // 沒有逐段搶救的話整包會退回 SettingJson()：lang 變回 ""、
      // useExternalVideoPlayer 變回 false。
      expect(await Model.instance.getInstance(), isFalse);

      expect(Model.instance.getOtherSetting().lang, 'zh');
      expect(Model.instance.getOtherSetting().useExternalVideoPlayer, isTrue);
      // 壞掉的那一段各自退回預設。
      expect(Model.instance.getCourseSetting().info.studentId, '');
      // 搶救成功不代表可以回寫，原始 blob 一樣要留著。
      expect((await pref()).getString(Model.settingJsonKey), blob);
    });

    test('other 段型別錯時，目前顯示的課表仍然救得回來', () async {
      // lang 宣告是 String，這裡放 int。
      final blob = json.encode(<String, dynamic>{
        'course': validCourseSection(),
        'other': <String, dynamic>{'lang': 123},
      });
      SharedPreferences.setMockInitialValues({Model.settingJsonKey: blob});

      expect(await Model.instance.getInstance(), isFalse);

      expect(Model.instance.getCourseSetting().info.studentId, 'B10902000');
      expect(Model.instance.getCourseSetting().info.studentName, '王小明');
      expect(Model.instance.getOtherSetting().lang, '');
      expect(Model.instance.getOtherSetting().useMoodleWebApi, isTrue);
    });

    test('整段不是物件（例如被寫成陣列）也只讓那一段退回預設', () async {
      final blob = json.encode(<String, dynamic>{
        'course': <dynamic>[],
        'other': <String, dynamic>{'lang': 'en', 'useMoodleWebApi': false},
      });
      SharedPreferences.setMockInitialValues({Model.settingJsonKey: blob});

      await Model.instance.getInstance();

      expect(Model.instance.getOtherSetting().lang, 'en');
      expect(Model.instance.getOtherSetting().useMoodleWebApi, isFalse);
      expect(Model.instance.getCourseSetting().info.studentId, '');
    });
  });

  group('沒有壞掉時行為不變', () {
    test('空的 SharedPreferences 一路載入成功，回傳 false', () async {
      expect(await Model.instance.getInstance(), isFalse);

      expect(Model.instance.getCourseTableList(), isEmpty);
      expect(Model.instance.getSemesterList(), isEmpty);
      expect(Model.instance.getScore().info, isEmpty);
      expect(Model.instance.getOtherSetting().lang, '');
    });

    test('正常的 blob 照樣載得回來，而且沒有被回寫改動', () async {
      final table = makeTable();
      final settingBlob = json.encode(SettingJson(
        course: CourseSettingJson(info: table),
        other: OtherSettingJson(lang: 'zh', useExternalVideoPlayer: true),
      ));
      final courseLine = json.encode(table);
      final scoreBlob = json.encode(ScoreRankJson());
      SharedPreferences.setMockInitialValues({
        Model.settingJsonKey: settingBlob,
        Model.courseTableJsonKey: <String>[courseLine],
        Model.scoreCreditJsonKey: scoreBlob,
      });

      expect(await Model.instance.getInstance(), isFalse);

      expect(Model.instance.getOtherSetting().lang, 'zh');
      expect(Model.instance.getOtherSetting().useExternalVideoPlayer, isTrue);
      expect(Model.instance.getCourseSetting().info.studentId, 'B10902000');
      expect(Model.instance.getCourseTableList(), hasLength(1));

      expect((await pref()).getString(Model.settingJsonKey), settingBlob);
      expect((await pref()).getStringList(Model.courseTableJsonKey),
          <String>[courseLine]);
      expect((await pref()).getString(Model.scoreCreditJsonKey), scoreBlob);
    });
  });
}
