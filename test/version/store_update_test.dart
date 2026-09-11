import 'package:flutter_app/src/version/store_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('不是 Android / iOS 就當沒有新版，不碰平台通道', () async {
    expect(await StoreUpdate.offer(), isFalse);
  });
}
