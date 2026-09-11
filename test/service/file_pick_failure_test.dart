import 'package:flutter_app/src/service/file_pick_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// file_picker 丟出來的 PlatformException code 怎麼分類。
///
/// 只驗這一段純對照：真正的挑檔案要碰平台通道，測試裡走的是
/// [NoopFilePickService]。
void main() {
  FilePickFailureReason reasonOf(String code) =>
      PlatformFilePickService.pickFailureReasonOf(code);

  test('權限被拒的三種寫法都算 denied', () {
    expect(
        reasonOf('read_external_storage_denied'), FilePickFailureReason.denied);
    expect(reasonOf('photo_access_denied'), FilePickFailureReason.denied);
    expect(reasonOf('permission_denied'), FilePickFailureReason.denied);
  });

  test('11.x 自己丟的碼都不是權限問題，只說這條路走不通', () {
    for (final code in [
      'no_activity',
      'already_active',
      'unknown_path',
      'invalid_format_type',
      'multiple_request',
      'file_picker_error',
      'Unsupported picker type',
      '',
    ]) {
      expect(reasonOf(code), FilePickFailureReason.unavailable, reason: code);
    }
  });

  test('取消不是失敗：Noop 實作回空清單而不是丟例外', () async {
    expect(await const NoopFilePickService().pick(limit: 3), isEmpty);
  });
}
