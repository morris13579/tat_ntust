import 'package:flutter/services.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/config/app_link.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:get/get.dart';

class PrivacyPolicyController extends GetxController {
  var isLoading = true.obs;
  var isError = false.obs;
  var errorMsg = "".obs;
  var content = "".obs;

  @override
  Future<void> onInit() async {
    super.onInit();
    await load();
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      isError.value = false;
      content.value = await fetchPolicy();
    } catch (e) {
      isError.value = true;
      errorMsg.value = e.toString().replaceAll("Exception:", "");
    } finally {
      isLoading.value = false;
    }
  }

  /// 取隱私政策內文：先問網路，失敗就退回打包進 App 的那一份。
  ///
  /// **這一頁是新使用者的第一道關卡，而且沒有退路**：同意鈕在 `BasePage` 的
  /// child 裡，`isError` 為 true 時整個 child 會被錯誤頁換掉，鈕不會被畫出來
  /// 也沒有重試。網路慢一點就會把人永遠擋在門外。
  ///
  /// 備援讀的 `privacy-policy.md` 與 GitHub raw 服務的是同一個檔案
  /// （見 pubspec.yaml）。兩邊都失敗才會 throw。登入頁與「關於」頁的唯讀入口
  /// 也共用這一份，免得只有其中一條路有離線備援。
  static Future<String> fetchPolicy() async {
    try {
      return await Connector.getDataByGet(
          ConnectorParameter(AppLink.privacyPolicyUrl));
    } catch (e) {
      Log.e("privacy policy 取不到，改用打包的那一份: $e");
      try {
        return await rootBundle.loadString(_bundledPolicy);
      } catch (bundleError, stack) {
        Log.eWithStack(bundleError.toString(), stack);
        // 丟回網路那一則：對使用者有意義的是「連不上」，不是 asset 找不到。
        throw e;
      }
    }
  }

  /// 必須與 pubspec.yaml 的 assets 那一行逐字一致。
  static const String _bundledPolicy = "privacy-policy.md";

  Future<void> onAgreePrivacyPolicy() async {
    await Model.instance.setAgreeContributor(true);
    Get.back();
  }
}
