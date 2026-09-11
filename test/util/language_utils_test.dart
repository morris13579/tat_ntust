import 'package:flutter/widgets.dart';
import 'package:flutter_app/src/model/setting/setting_json.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/reset_statics.dart';

/// 特徵化測試：凍結 LanguageUtils 的語言字串轉換與 getLangIndex 行為
/// （含已知的怪異之處）。語言判定不只是顯示：connector 會據此改用不同語系的
/// URL 與參數，所以任何改動都要讓 CI 抓得到。
///
/// 只測不需要 Flutter binding 的純邏輯：
/// `init` / `load` / `setLangByIndex` 會走到 `R.load`、`S.delegate` 與
/// `Model.instance.saveOtherSetting()`（SharedPreferences 實際寫入），
/// 因此不在本檔涵蓋範圍。
void main() {
  /// 直接改寫 Model 記憶體中的 OtherSettingJson。
  /// `getOtherSetting()` 只讀 in-memory 欄位，不碰 SharedPreferences，
  /// 所以 headless 可用。
  void setLangSetting(String lang) {
    Model.instance.setOtherSetting(OtherSettingJson(lang: lang));
  }

  setUp(() {
    // Model.instance 是 process 級 singleton，測試之間會互相污染。
    resetAppStatics();
    setLangSetting('');
  });

  group('getSupportLocale', () {
    test('支援語系順序固定為 [en, zh_TW]', () {
      final locales = LanguageUtils.getSupportLocale;
      expect(locales.length, 2);
      expect(locales[0].languageCode, 'en');
      expect(locales[1].languageCode, 'zh');
      expect(locales[1].countryCode, 'TW');
    });

    test('英文語系沒有 countryCode（是 null 而非空字串）', () {
      // 這一點是下面 locale2String 會產生 "_en" 的直接原因。
      expect(LanguageUtils.getSupportLocale[0].countryCode, isNull);
    });

    test('LangEnum 的順序與 getSupportLocale 的索引一致', () {
      // setLangByIndex 直接用 langEnum.index 取 locale，兩者一旦錯位就會選錯語言。
      expect(LangEnum.values.length, 2);
      expect(LangEnum.en.index, 0);
      expect(LangEnum.zh.index, 1);
    });
  });

  group('locale2String', () {
    test('中文語系序列化為 countryCode_languageCode 格式', () {
      expect(
        LanguageUtils.locale2String(const Locale('zh', 'TW')),
        'TW_zh',
      );
    });

    test('英文語系序列化成 "_en"，前面少了國碼（現況）', () {
      // 已知問題：支援清單中的 en 沒有 countryCode，locale2String 以 "" 補位，
      // 於是持久化字串是 "_en" 而不是 "US_en"。
      expect(
        LanguageUtils.locale2String(LanguageUtils.getSupportLocale[0]),
        '_en',
      );
    });
  });

  group('string2Locale', () {
    test('"TW_zh" 會真的比對到支援清單中的 zh_TW', () {
      final locale = LanguageUtils.string2Locale('TW_zh');
      expect(locale, LanguageUtils.getSupportLocale[1]);
    });

    test('空字串比對不到，落到 getSupportLocale[0]（英文）', () {
      // 先檢查長度再切，不要讓 `"".split("_")[1]` 的 RangeError 變成控制流程。
      // 這個 fallback 只留給 string2Locale 的呼叫端，getLangIndex 不吃它，
      // 見下面 getLangIndex 那一組。
      expect(
          LanguageUtils.string2Locale(''), LanguageUtils.getSupportLocale[0]);
    });

    test('格式錯誤（用 "-" 分隔）同樣落到英文', () {
      expect(
        LanguageUtils.string2Locale('zh-TW'),
        LanguageUtils.getSupportLocale[0],
      );
    });

    test('"US_en" 其實比對不到，是靠 fallback 才回英文（現況）', () {
      // 已知問題：支援清單的 en 其 countryCode 為 null，永遠不會等於 "US"，
      // 迴圈跑完沒有命中，最後才因為 fallback 回傳 getSupportLocale[0]。
      // 結果碰巧正確，但不是比對成功。
      expect(
        LanguageUtils.string2Locale('US_en'),
        LanguageUtils.getSupportLocale[0],
      );
    });

    test('locale2String 產生的 "_en" 現在是真的比對成功，不是靠 fallback', () {
      // 比對時要把 null 的 countryCode 正規化成 ""：拿 null 跟 "" 比永遠不等，
      // 英文就只是碰巧被 fallback 送回英文，getLangIndex 也因此分不出
      // 「真的選了英文」與「根本沒設定」。
      expect(
        LanguageUtils.string2Locale('_en'),
        LanguageUtils.getSupportLocale[0],
      );
    });

    test('英文的 round-trip 也是穩定的', () {
      final locale = LanguageUtils.getSupportLocale[0];
      expect(
        LanguageUtils.string2Locale(LanguageUtils.locale2String(locale)),
        locale,
      );
    });

    test('不支援的語系字串（如 "JP_ja"）落到英文而非保留原值', () {
      expect(
        LanguageUtils.string2Locale('JP_ja'),
        LanguageUtils.getSupportLocale[0],
      );
    });

    test('zh_TW 的 round-trip 是穩定的', () {
      final locale = LanguageUtils.getSupportLocale[1];
      expect(
        LanguageUtils.string2Locale(LanguageUtils.locale2String(locale)),
        locale,
      );
    });
  });

  group('getLangIndex', () {
    test('lang 為空字串（沒設定過）時回傳 LangEnum.zh', () {
      // 沒設定過不可以判成英文：CourseConnector 會改送 Culture=en-US 與
      // "language": "en"、NTUSTConnector 改抓 /EN/student，使用者拿到整批英文
      // 課名，UI 卻還是跟著手機語言的中文，也與 init() 「沒設定就跟隨手機語言」
      // 的意圖相反。
      setLangSetting('');
      expect(LanguageUtils.getLangIndex(), LangEnum.zh);
    });

    test('lang 為 "TW_zh" 時回傳 LangEnum.zh', () {
      setLangSetting('TW_zh');
      expect(LanguageUtils.getLangIndex(), LangEnum.zh);
    });

    test('lang 為 "_en"（實際存檔格式）時仍回傳 LangEnum.en', () {
      // 這條是上面「沒設定就回中文」的護欄：真的選過英文的使用者不能被
      // 一起掃到中文去。"_en" 是 locale2String 對英文的輸出格式。
      setLangSetting('_en');
      expect(LanguageUtils.getLangIndex(), LangEnum.en);
    });

    test('lang 格式錯誤時回傳 LangEnum.zh', () {
      // 比對不到就落到中文。string2Locale 一定回傳支援清單中的元素，
      // 所以「比對失敗」判不得靠 indexOf == -1。
      setLangSetting('this_is_not_a_locale');
      expect(LanguageUtils.getLangIndex(), LangEnum.zh);
    });

    test('不支援的語系（如 "JP_ja"）回傳 LangEnum.zh 而非英文', () {
      // 手機語系不在支援清單時 load() 不會寫回設定，lang 有可能一直是
      // 這種比對不到的值；這種情況同樣不該被判定成英文。
      setLangSetting('JP_ja');
      expect(LanguageUtils.getLangIndex(), LangEnum.zh);
    });
  });
}
