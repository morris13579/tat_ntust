import 'package:flutter_app/src/native/core_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/reset_statics.dart';

/// 原生版啟動時的隱私權同意閘門。判準壞了，使用者不是每次開 App 都被擋一次，就是從來沒同意過。
void main() {
  setUp(resetAppStatics);

  test('還沒同意就要先同意；同意之後不再問', () async {
    const bridge = CoreBridge();

    expect(await bridge.needsPrivacyAgreement(), isTrue);
    await bridge.agreePrivacyPolicy();
    expect(await bridge.needsPrivacyAgreement(), isFalse);
  });
}
