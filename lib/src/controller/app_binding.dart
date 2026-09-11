import 'package:flutter_app/src/controller/calendar/calendar_controller.dart';
import 'package:flutter_app/src/controller/course_table/course_controller.dart';
import 'package:flutter_app/src/controller/main_page/main_controller.dart';
import 'package:flutter_app/src/controller/score_page/score_page_controller.dart';
import 'package:flutter_app/src/service/app_service.dart';
import 'package:get/get.dart';

/// 啟動時註冊的相依。掛在 `GetMaterialApp.initialBinding`。
///
/// **分頁的 controller 在這裡註冊，不在頁面的 `build()` 裡 `Get.put`。**
/// Get.put 對已註冊的實例是 no-op，onInit 不會再跑，狀態會卡住
/// （見 CourseController.reset()）。
///
/// `fenix: true` 讓實例被 `Get.delete` 之後還能重建。`Get.offAll` 是目前重建
/// 所有 controller 的機制，沒有 fenix 的話第二次 `Get.find` 會拋。
class AppBindings extends Bindings {
  @override
  void dependencies() {
    Get.put(AppService());
    Get.lazyPut<MainController>(() => MainController(), fenix: true);
    Get.lazyPut<CourseController>(() => CourseController(), fenix: true);
    Get.lazyPut<CalendarController>(() => CalendarController(), fenix: true);
    Get.lazyPut<ScorePageController>(() => ScorePageController(), fenix: true);
  }
}
