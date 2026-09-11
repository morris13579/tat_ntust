import 'package:flutter/cupertino.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/generated/l10n.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/setting/setting_json.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:get/get.dart';

enum LangEnum { en, zh }

class LanguageUtils {
  static Future<void> init(BuildContext context) async {
    OtherSettingJson otherSetting = Model.instance.getOtherSetting();
    if (otherSetting.lang.isEmpty || !otherSetting.lang.contains("_")) {
      //如果沒有設定語言使用手機目前語言
      Locale locale = Localizations.localeOf(context);
      // 一定要 await，不然會在 R 尚未載入時就回去畫 UI。
      await load(locale);
    } else {
      await load(string2Locale(otherSetting.lang));
    }
  }

  static List<Locale> get getSupportLocale {
    return S.delegate.supportedLocales;
  }

  /// 切換語言的唯一入口：換掉 intl 訊息表、換掉 Flutter 的 Localizations、
  /// 寫回設定。三件事少一件就會有地方沒被切換。
  static Future<void> load(Locale locale) async {
    if (getSupportLocale.contains(locale)) {
      await R.load(locale);
      // 不要拿掉。GetMaterialApp 沒傳 locale 時 Localizations 跟的是手機語系，
      // 會把上一行設好的 Intl.defaultLocale 蓋回去；而且已經建好的畫面不會重畫。
      // Get.updateLocale 同時設定 Get.locale 並 forceAppUpdate。
      await Get.updateLocale(locale);
      String lang = locale2String(locale);
      OtherSettingJson otherSetting = Model.instance.getOtherSetting();
      if (otherSetting.lang != lang) {
        //只有不相同時可以載入
        otherSetting.lang = lang;
        Model.instance.setOtherSetting(otherSetting);
        await Model.instance.saveOtherSetting();
        await Model.instance.clearCourseTableList();
        await Model.instance.clearCourseSetting();
      }
    } else {
      Log.e("no any locale load");
      return;
    }
  }

  static String locale2String(Locale locale) {
    String countryCode = locale.countryCode ?? "";
    String languageCode = locale.languageCode;
    return '${countryCode}_$languageCode';
  }

  /// 把持久化字串比對回支援清單裡的 Locale，比對不到回 null。
  ///
  /// 支援清單裡 en 的 countryCode 是 **null**，而 locale2String 會把 null
  /// 寫成空字串（存成 `"_en"`），所以比對時一定要把 countryCode 正規化成
  /// ""，否則英文存進去再讀出來永遠比對不到。[getLangIndex] 要靠這個
  /// round-trip 分辨「真的選了英文」與「根本沒設定」。
  static Locale? _matchSupportLocale(String lang) {
    final parts = lang.split("_");
    // 沒設定過語言時 lang 是空字串，`"".split("_")` 只有一個元素；
    // 少了這道檢查 parts[1] 會拋。
    if (parts.length < 2) {
      return null;
    }
    final countryCode = parts[0];
    final languageCode = parts[1];
    for (Locale locale in getSupportLocale) {
      if (locale.languageCode == languageCode &&
          (locale.countryCode ?? "") == countryCode) {
        return locale;
      }
    }
    return null;
  }

  /// 比對不到時仍回傳支援清單的第一個（英文）：init() 與設定頁都假設一定
  /// 拿得到一個 Locale。會依語言改變伺服器行為的 [getLangIndex] 不吃這個
  /// fallback。
  static Locale string2Locale(String lang) {
    return _matchSupportLocale(lang) ?? getSupportLocale[0];
  }

  static Future<void> setLangByIndex(LangEnum langEnum) async {
    Locale locale = getSupportLocale[langEnum.index];
    await load(locale);
  }

  /// 目前生效的語言。
  ///
  /// 只有真的比對到支援清單裡的語系才據以判定，其餘（沒設定過、格式壞掉、
  /// 不支援的語系）一律落到中文。**不可以改用 [string2Locale] 的 fallback**：
  /// 那會把「從沒設定過語言」判成英文，而 CourseConnector 會據此改送
  /// `Culture=en-US` 與 `"language": "en"`，NTUSTConnector 改抓 /EN/student，
  /// 使用者拿到整批英文課名與英文子系統清單，UI 卻還是跟著手機語言的中文。
  static LangEnum getLangIndex() {
    OtherSettingJson otherSetting = Model.instance.getOtherSetting();
    final Locale? locale = _matchSupportLocale(otherSetting.lang);
    if (locale == null) {
      return LangEnum.zh;
    }
    return getSupportLocale.indexOf(locale) == LangEnum.en.index
        ? LangEnum.en
        : LangEnum.zh;
  }
}
