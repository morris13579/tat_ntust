import 'package:flutter_app/src/config/app_link.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/ui/screen/main_screen.dart';
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

      var data = await Connector.getDataByGet(
          ConnectorParameter(AppLink.privacyPolicyUrl));
      content.value = data;
    } catch (e) {
      isError.value = true;
      errorMsg.value = e.toString().replaceAll("Exception:", "");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> onAgreePrivacyPolicy() async {
    await Model.instance.setAgreeContributor(true);
    Get.back();
  }
}
