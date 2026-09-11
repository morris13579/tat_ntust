import 'dart:io';

import 'package:flutter_app/src/util/file_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// `FileDownload.download` 的快取判斷完全靠這個契約：檔案不在就 throw。
///
/// 如果哪天 openFile 改成「不在就安靜回傳」，那邊的
/// `if (await _openIfExists(savePath)) return;` 會永遠成立，變成點了檔案什麼
/// 都不做；反過來如果改成不 throw 而回 false，快取又會整個失效、每次重抓。
/// 兩種都不會有測試擋下來，所以把契約釘在這裡。
void main() {
  test('檔案不存在時 openFile 會 throw，不是安靜回傳', () async {
    final missing = '${Directory.systemTemp.path}/tat-does-not-exist-4711.pdf';
    expect(File(missing).existsSync(), isFalse);

    await expectLater(FileUtils.openFile(missing), throwsA(isA<Exception>()));
  });
}
