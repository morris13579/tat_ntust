import 'package:flutter_app/src/model/ntust/ap_tree_json.dart';
import 'package:flutter_app/src/repository/ntust_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:get/get.dart';

/// 資訊系統的狀態、本地搜尋與分類展開。
///
/// **搜尋不打 API。** 整棵樹一次就全部拿回記憶體，而 `getSubSystemTree` 走的是
/// SSO；每輸入一個字元重抓一次只會換來一次登入檢查與幾百毫秒的等待。
class SubSystemController {
  /// null 代表還在載入。
  final tree = Rxn<Result<List<APTreeJson>>>();

  final keyword = ''.obs;

  Future<void> load() async {
    tree.value = null;
    tree.value = await NtustRepository.instance.getSubSystemTree();
  }

  void search(String value) => keyword.value = value.trim();

  /// 空關鍵字一律成立，呼叫端就不必每處各判斷一次。
  bool matches(String name) =>
      keyword.value.isEmpty ||
      name.toLowerCase().contains(keyword.value.toLowerCase());

  List<APListJson> visibleItems(APTreeJson category) =>
      category.apList.where((ap) => matches(ap.name)).toList();

  void dispose() {
    tree.close();
    keyword.close();
  }
}
