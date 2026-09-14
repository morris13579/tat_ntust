import 'package:flutter_app/src/model/moodle_token_entity.dart';
import 'package:flutter_app/src/service/interactive_login_gateway.dart';
import 'package:flutter_app/ui/auth/moodle_login_page.dart';
import 'package:flutter_app/ui/auth/ntust_login_page.dart';
import 'package:get/get.dart';

/// 用 GetX 導航把登入頁推到最前面的 [InteractiveLoginGateway] 實作。
///
/// 「需要真人的登入」與 GetX 導航唯一相接的地方；task 與 connector 只認得
/// 介面，不 import 任何 UI。
class GetInteractiveLoginGateway implements InteractiveLoginGateway {
  const GetInteractiveLoginGateway();

  @override
  Future<NtustInteractiveLoginResult?> signInNtust({
    required String account,
    required String password,
  }) async =>
      // 使用者按返回鍵時沒有 result。
      await Get.to<NtustInteractiveLoginResult>(
        () => LoginNTUSTPage(username: account, password: password),
      );

  @override
  Future<MoodleTokenEntity?> signInMoodle({
    required String account,
    required String password,
  }) async =>
      // Get.to 回 Future<T?>?：導航尚未就緒時是 null 而不是 Future，
      // 所以要 await 而非直接回傳。
      await Get.to<MoodleTokenEntity>(
        () => LoginMoodlePage(username: account, password: password),
      );
}
