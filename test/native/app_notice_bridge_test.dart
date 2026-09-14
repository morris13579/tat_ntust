import 'package:flutter_app/src/model/announcement/announcement_json.dart';
import 'package:flutter_app/src/native/app_notice_bridge.dart';
import 'package:flutter_app/src/util/remote_config_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_l10n.dart';

AnnouncementInfoJson info(String title) => AnnouncementInfoJson(
      title: title,
      content: '- [表單](https://forms.gle/x) 請填',
      startTime: DateTime.utc(2025, 9, 1, 9),
      endTime: DateTime.utc(2025, 10, 1, 9),
      test: false,
    );

/// 原生版的啟動公告。要不要跳在 `RemoteConfigUtils.resolveAnnouncement`，這裡只驗交給 Swift 的內容。
void main() {
  setUpAll(() async {
    await loadTestL10n();
    await initializeDateFormatting();
  });

  test('照原本的順序、帶著倒數；沒有要跳的回 null', () async {
    final bridge = AppNoticeBridge(
      resolve: (test) async =>
          test ? AnnouncementRequest([info('A'), info('B')], 5) : null,
    );

    expect(await bridge.launchAnnouncement(false), isNull);
    final launch = (await bridge.launchAnnouncement(true))!;

    expect(launch.notices.map((n) => n.title), ['A', 'B']);
    expect(launch.countDown, 5);
    expect(launch.notices.first.excerpt, '表單 請填');
  });
}
