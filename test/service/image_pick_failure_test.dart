import 'package:flutter_app/src/service/image_pick_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// image_picker 丟出來的 PlatformException code 怎麼分類。
///
/// 只驗這一段純對照：真正的挑圖要碰平台通道，測試裡走的是
/// [NoopImagePickService]。
void main() {
  ImagePickFailureReason reasonOf(String code) =>
      PlatformImagePickService.pickFailureReasonOf(code);

  test('相機被拒（含 restricted）都算相機權限', () {
    expect(
        reasonOf('camera_access_denied'), ImagePickFailureReason.cameraDenied);
    expect(reasonOf('camera_access_restricted'),
        ImagePickFailureReason.cameraDenied);
  });

  test('相簿被拒（含 restricted）都算相簿權限', () {
    expect(
        reasonOf('photo_access_denied'), ImagePickFailureReason.galleryDenied);
    expect(reasonOf('photo_access_restricted'),
        ImagePickFailureReason.galleryDenied);
  });

  test('認不得的 code 不冒充成權限問題，只說這條路走不通', () {
    expect(reasonOf('multiple_request'), ImagePickFailureReason.unavailable);
    // 沒有相機 App 與重入都不是權限：系統設定裡沒有開關可開。
    expect(reasonOf('no_available_camera'), ImagePickFailureReason.unavailable);
    expect(reasonOf('already_active'), ImagePickFailureReason.unavailable);
  });
}
