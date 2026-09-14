import 'package:flutter_app/src/util/file_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// Android 開檔交給檢視器的網址。以前只帶檔名，FileProvider 會到 App 目錄的最上層找，
/// 放在課名資料夾或自選下載位置裡的檔案一律開不起來，而且不會有任何錯誤回到 App。
void main() {
  test('帶完整路徑；中文、空白與問號要編碼；authority 的大小寫不能變', () {
    expect(
      FileUtils.contentUriOf(
          '/storage/emulated/0/Download/NewFolder/線性代數/第 1 週?.pdf', 'club.ntust.tat'),
      'content://club.ntust.tat.fileProvider/root/storage/emulated/0/Download/NewFolder/'
      '%E7%B7%9A%E6%80%A7%E4%BB%A3%E6%95%B8/%E7%AC%AC%201%20%E9%80%B1%3F.pdf',
    );
  });

  test('App 自己的目錄走同一個根', () {
    expect(
      FileUtils.contentUriOf(
          '/data/user/0/club.ntust.tat/files/course/a.pdf', 'club.ntust.tat'),
      'content://club.ntust.tat.fileProvider/root/data/user/0/club.ntust.tat/files/course/a.pdf',
    );
  });
}
