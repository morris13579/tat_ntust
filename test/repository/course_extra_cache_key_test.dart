import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/setting/setting_json.dart';
import 'package:flutter_app/src/repository/ntust_repository.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/reset_statics.dart';

/// 課程詳情的快取要分語系：那支 API 依語系回不同字串，語言不進 key 的話，
/// 切換語言後這一頁會一直讀到舊語系的快取。
void main() {
  final semester = SemesterJson(year: '114', semester: '1');

  void setLang(String lang) =>
      Model.instance.setOtherSetting(OtherSettingJson(lang: lang));

  setUp(resetAppStatics);

  test('同一門課在兩個語系下是不同的 cache id', () {
    setLang('TW_zh');
    final zh = NtustRepository.courseExtraCacheKey('CS1234701', semester).id;

    setLang('_en');
    final en = NtustRepository.courseExtraCacheKey('CS1234701', semester).id;

    expect(zh, isNot(en), reason: '共用 id 的話換語言之後這一頁會一直是舊語系');
  });

  test('同語系、同課號、同學期是同一個 id', () {
    setLang('TW_zh');
    expect(
      NtustRepository.courseExtraCacheKey('CS1234701', semester).id,
      NtustRepository.courseExtraCacheKey('CS1234701', semester).id,
    );
  });

  test('課號與學期仍然是 id 的一部分', () {
    setLang('TW_zh');
    final base = NtustRepository.courseExtraCacheKey('CS1234701', semester).id;
    expect(
      NtustRepository.courseExtraCacheKey('CS9999901', semester).id,
      isNot(base),
    );
    expect(
      NtustRepository.courseExtraCacheKey(
              'CS1234701', SemesterJson(year: '113', semester: '2'))
          .id,
      isNot(base),
    );
  });

  test('key name 沒變——登出時是靠 cache_ 前綴掃出來清的', () {
    expect(NtustRepository.courseExtraCacheKey('CS1234701', semester).name,
        'cache_course_extra');
  });
}
