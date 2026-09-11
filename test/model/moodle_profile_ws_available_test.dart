import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// MoodleProfileEntity 把 core_webservice_get_site_info 回的 functions[] 建成
/// 索引，wsAvailable / wsVersion 讓呼叫端不必多發請求就能確認站台有沒有開某個
/// function。這裡釘的是索引本身的語意。
void main() {
  MoodleProfileEntity profileWith(List<Map<String, dynamic>> functions) =>
      MoodleProfileEntity.fromJson({'functions': functions});

  group('MoodleProfileEntity.wsAvailable', () {
    test('清單裡有的 function 回 true，沒有的回 false', () {
      final e = profileWith([
        {'name': 'core_webservice_get_site_info', 'version': '2022041900'},
        {'name': 'mod_forum_get_forums_by_courses', 'version': '2021051700'},
      ]);

      expect(e.wsAvailable('core_webservice_get_site_info'), isTrue);
      expect(e.wsAvailable('mod_forum_get_forums_by_courses'), isTrue);
      expect(e.wsAvailable('gradereport_user_get_grade_items'), isFalse);
    });

    test('functions 缺席時一律回 false，不會拋', () {
      // 站台少送 functions 時 fromJson 退回空清單，查詢不該變成例外。
      final e = MoodleProfileEntity.fromJson({});

      expect(e.functions, isEmpty);
      expect(e.wsAvailable('core_webservice_get_site_info'), isFalse);
      expect(e.wsVersion('core_webservice_get_site_info'), isNull);
    });

    test('name 缺席的項目不會讓空字串查詢誤判成可用', () {
      // fromJson 對缺席的 name 會退回 ''（刻意保留的寬鬆行為），
      // 這種項目沒有任何 function 叫得動，必須排除在索引外。
      final e = profileWith([
        {'version': '2022041900'},
        {'name': 'core_course_get_contents', 'version': '2022041900'},
      ]);

      expect(e.functions.length, 2);
      expect(e.wsAvailable(''), isFalse);
      expect(e.wsAvailable('core_course_get_contents'), isTrue);
    });

    test('function 名稱大小寫必須完全相符', () {
      // Moodle 的 wsfunction 是大小寫敏感的，索引不做寬鬆比對，
      // 免得打錯名字反而被當成「站台有這個 function」。
      final e = profileWith([
        {'name': 'core_course_get_contents', 'version': '2022041900'},
      ]);

      expect(e.wsAvailable('Core_Course_Get_Contents'), isFalse);
    });
  });

  group('MoodleProfileEntity.wsVersion', () {
    test('回傳站台回報的版本字串', () {
      final e = profileWith([
        {'name': 'core_course_get_contents', 'version': '2022041900'},
      ]);

      expect(e.wsVersion('core_course_get_contents'), '2022041900');
      expect(e.wsVersion('core_course_get_courses'), isNull);
    });

    test('version 缺席的項目仍算可用，版本是空字串', () {
      // 可用與否看 name 在不在清單裡，跟站台有沒有回報版本無關。
      final e = profileWith([
        {'name': 'core_course_get_contents'},
      ]);

      expect(e.wsAvailable('core_course_get_contents'), isTrue);
      expect(e.wsVersion('core_course_get_contents'), '');
    });
  });

  group('索引與 functions 欄位的同步', () {
    test('functions 換成另一個 List 之後索引跟著更新', () {
      // functions 是可變欄位而索引有快取，換掉整個 List 時快取必須失效，
      // 否則會查到舊站台的清單。
      final e = profileWith([
        {'name': 'core_course_get_contents', 'version': '2022041900'},
      ]);
      expect(e.wsAvailable('core_course_get_contents'), isTrue);

      e.functions = [
        MoodleProfileFunctions(name: 'core_user_get_users', version: '2021'),
      ];

      expect(e.wsAvailable('core_course_get_contents'), isFalse);
      expect(e.wsAvailable('core_user_get_users'), isTrue);
      expect(e.wsVersion('core_user_get_users'), '2021');
    });

    test('重複查詢結果一致（快取不會在第二次查詢時漏掉項目）', () {
      final e = profileWith([
        {'name': 'core_course_get_contents', 'version': '2022041900'},
        {'name': 'core_user_get_users', 'version': '2021051700'},
      ]);

      for (var i = 0; i < 3; i++) {
        expect(e.wsAvailable('core_course_get_contents'), isTrue);
        expect(e.wsAvailable('core_user_get_users'), isTrue);
        expect(e.wsAvailable('core_course_get_courses'), isFalse);
      }
    });
  });

  test('新增的索引欄位不會被序列化出去', () {
    // _wsIndex / _wsIndexSource 是私有欄位，json_serializable 應該忽略；
    // 這條擋住的是有人日後把它們改成公開欄位而污染 toJson 的回應。
    final e = profileWith([
      {'name': 'core_course_get_contents', 'version': '2022041900'},
    ]);
    e.wsAvailable('core_course_get_contents');

    final json = e.toJson();
    expect(json.containsKey('_wsIndex'), isFalse);
    expect(json.containsKey('wsIndex'), isFalse);
    expect(json['functions'], isA<List<dynamic>>());
  });
}
