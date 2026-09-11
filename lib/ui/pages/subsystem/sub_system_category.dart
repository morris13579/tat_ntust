import 'package:flutter_app/src/R.dart';

/// `serviceId` 是 NTUST 那一側的不透明代號，分類名稱只能自己對照。
///
/// 對不到就回 null 而不是空字串：多出一個沒見過的代號時，該分類底下的服務
/// 照樣要畫出來，只是少一列標題——比畫一列空白標題或整段吞掉都好。
///
/// 回傳值必須在 `build()` 期間才求值，所以是函式而不是常數表：`R.current`
/// 寫進欄位初始式會被 test/l10n 擋下，而且語言切換後不會更新。
String? subSystemCategoryName(String serviceId) => switch (serviceId) {
      'service-1' => R.current.curriculum,
      'service-2' => R.current.person_info,
      'service-3' => R.current.campus_life,
      'service-4' => R.current.financial_support,
      'service-5' => R.current.activities,
      'service-6' => R.current.resources,
      _ => null,
    };
