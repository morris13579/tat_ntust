import 'dart:convert';

import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_setting_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// 釘住這兩個 entity 的寬鬆解析契約：欄位缺席或為 null 時退回預設值。
/// Moodle 換版少送一個欄位，不該讓整個個人資料或通知設定解析失敗。
void main() {
  group('MoodleProfileEntity', () {
    test('完整回應解析得出 UI 真正會用到的三個欄位', () {
      final e = MoodleProfileEntity.fromJson({
        'sitename': 'NTUST Moodle',
        'username': 'b10902000',
        'firstname': '王小明',
        'lastname': '',
        'fullname': '王小明',
        'userid': 12345,
        'userpictureurl': 'https://moodle.ntust.edu.tw/pic.png',
        'functions': [
          {'name': 'core_webservice_get_site_info', 'version': '2022041900'}
        ],
        'advancedfeatures': [
          {'name': 'usecomments', 'value': 1}
        ],
        'usercanmanageownfiles': true,
        'userissiteadmin': false,
      });

      expect(e.username, 'b10902000');
      expect(e.firstname, '王小明');
      expect(e.userpictureurl, 'https://moodle.ntust.edu.tw/pic.png');
      expect(e.userid, 12345);
      expect(e.functions.single.name, 'core_webservice_get_site_info');
      expect(e.advancedfeatures.single.value, 1);
      expect(e.usercanmanageownfiles, isTrue);
    });

    test('空物件不會拋，每個欄位退回預設值', () {
      final e = MoodleProfileEntity.fromJson({});

      expect(e.username, '');
      expect(e.userid, 0);
      expect(e.functions, isEmpty);
      expect(e.advancedfeatures, isEmpty);
      expect(e.userissiteadmin, isFalse);
    });

    test('欄位明確為 null 時同樣退回預設值', () {
      final e = MoodleProfileEntity.fromJson({
        'username': null,
        'userid': null,
        'functions': null,
      });

      expect(e.username, '');
      expect(e.userid, 0);
      expect(e.functions, isEmpty);
    });

    test('toJson 與 toString 來回一致', () {
      final e = MoodleProfileEntity.fromJson({
        'username': 'b10902000',
        'userid': 7,
        'functions': [
          {'name': 'f', 'version': 'v'}
        ],
      });

      final round = MoodleProfileEntity.fromJson(e.toJson());
      expect(round.username, 'b10902000');
      expect(round.userid, 7);
      expect(round.functions.single.name, 'f');
      // explicitToJson，巢狀物件要是 Map 而不是實例。
      expect(jsonDecode(e.toString())['functions'][0]['name'], 'f');
    });
  });

  group('MoodleSettingEntity', () {
    Map<String, dynamic> processor({bool checked = true}) => {
          'displayname': 'Mobile',
          'name': 'airnotifier',
          'locked': false,
          'userconfigured': 1,
          'loggedin': {
            'name': 'loggedin',
            'displayname': '線上',
            'checked': checked
          },
          'loggedoff': {
            'name': 'loggedoff',
            'displayname': '離線',
            'checked': checked
          },
          'enabled': true,
        };

    Map<String, dynamic> fullResponse() => {
          'preferences': {
            'userid': 12345,
            'disableall': 0,
            'processors': [
              {
                'displayname': 'Mobile',
                'name': 'airnotifier',
                'hassettings': true,
                'contextid': 1,
                'userconfigured': 1,
              }
            ],
            'components': [
              {
                'displayname': '作業',
                'notifications': [
                  {
                    'displayname': '作業繳交通知',
                    'preferencekey':
                        'message_provider_mod_assign_assign_notification',
                    'processors': [processor()],
                  }
                ],
              }
            ],
          },
          'warnings': [],
        };

    test('完整回應解析出設定頁需要的三層結構', () {
      final e = MoodleSettingEntity.fromJson(fullResponse());

      expect(e.preferences.userid, 12345);
      expect(e.preferences.processors.single.displayname, 'Mobile');

      final component = e.preferences.components.single;
      expect(component.displayname, '作業');
      final notification = component.notifications.single;
      expect(notification.preferencekey,
          'message_provider_mod_assign_assign_notification');
      expect(notification.processors.single.enabled, isTrue);
      expect(notification.processors.single.loggedin?.checked, isTrue);
    });

    test('loggedin / loggedoff 為 null 時整包仍然解析得出來', () {
      // 臺科的 Moodle 對部分 processor 這兩個欄位就是送 null（實機確認），
      // 所以必須是可空的：寫成必填時 `json['loggedin'] as Map<String, dynamic>`
      // 會拋 TypeError，整個「Moodle 設定」頁變成錯誤畫面。
      final raw = fullResponse();
      final proc = ((((raw['preferences'] as Map)['components'] as List).first
              as Map)['notifications'] as List)
          .first as Map;
      (proc['processors'] as List).first['loggedin'] = null;
      (proc['processors'] as List).first['loggedoff'] = null;

      final e = MoodleSettingEntity.fromJson(
          jsonDecode(jsonEncode(raw)) as Map<String, dynamic>);

      final processor = e
          .preferences.components.single.notifications.single.processors.single;
      expect(processor.loggedin, isNull);
      expect(processor.loggedoff, isNull);
      // 畫面真正需要的欄位不受影響。
      expect(processor.displayname, 'Mobile');
      expect(processor.enabled, isTrue);
    });

    test('preferences 底下缺欄位時退回空清單，不會拋', () {
      // 走 jsonDecode 以取得與真實回應相同的 Map<String, dynamic> 型別。
      final e = MoodleSettingEntity.fromJson(
          jsonDecode('{"preferences": {}}') as Map<String, dynamic>);

      expect(e.preferences.components, isEmpty);
      expect(e.preferences.processors, isEmpty);
      expect(e.warnings, isEmpty);
    });

    test('preferences 整個缺席時解析當下就失敗', () {
      // 要在解析當下就失敗，拖到 res.preferences.components 才拋
      // LateInitializationError 的話錯誤離原因很遠。
      // getSettings 的 try/catch 會回 null，設定頁顯示錯誤訊息。
      expect(() => MoodleSettingEntity.fromJson({}), throwsA(anything));
    });

    test('toJson 巢狀物件會被展開成 Map', () {
      final e = MoodleSettingEntity.fromJson(fullResponse());
      final decoded = jsonDecode(jsonEncode(e.toJson()));

      expect(
          decoded['preferences']['components'][0]['notifications'][0]
              ['processors'][0]['loggedoff']['displayname'],
          '離線');
    });
  });
}
