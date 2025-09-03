import 'package:flutter_app/src/service/app_service.dart';
import 'package:get/get.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    Get.put(AppService());
  }
}