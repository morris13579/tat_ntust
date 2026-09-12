import 'package:flutter_app/src/model/mail/mail_message_json.dart';
import 'package:flutter_app/ui/pages/mail/components/mail_groups.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../helpers/test_l10n.dart';

MailMessageJson at(DateTime date, {int uid = 1}) => MailMessageJson(
      uid: uid,
      subject: '主旨 $uid',
      dateMillis: date.millisecondsSinceEpoch,
    );

/// 信件清單的分組與主旨顯示。純函式，不需要畫面。
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestL10n();
    // 日期格式吃 locale，釘住才不會跟著跑測試的機器變。
    await initializeDateFormatting();
    Intl.defaultLocale = 'zh_TW';
  });

  group('依日期分組', () {
    // 2026/09/10 是星期四，所以這一週從 09/07 星期一開始。
    final now = DateTime(2026, 9, 10, 14, 0);

    test('今天、本週、更早各自成組，順序固定', () {
      final groups = MailGroups.groupByAge([
        at(DateTime(2026, 9, 10, 9, 0), uid: 1),
        at(DateTime(2026, 9, 8, 9, 0), uid: 2),
        at(DateTime(2026, 9, 1, 9, 0), uid: 3),
      ], now);

      expect(groups.map((g) => g.bucket).toList(),
          [MailBucket.today, MailBucket.thisWeek, MailBucket.earlier]);
      expect(groups.map((g) => g.items.single.uid).toList(), [1, 2, 3]);
    });

    test('空的組不畫出來', () {
      final groups = MailGroups.groupByAge([at(now)], now);

      expect(groups.single.bucket, MailBucket.today);
    });

    test('本週從這個星期一 00:00 起算', () {
      // 和通知頁的 groupByAge 同一條界線，兩頁的「本週」才是同一個意思。
      final groups = MailGroups.groupByAge([
        at(DateTime(2026, 9, 7, 0, 0), uid: 1),
        at(DateTime(2026, 9, 6, 23, 59), uid: 2),
      ], now);

      expect(groups.map((g) => g.bucket).toList(),
          [MailBucket.thisWeek, MailBucket.earlier]);
    });

    test('沒有日期的信落在最舊那一組，不是今天', () {
      // dateMillis 是 0 代表伺服器沒給 Date:，那個 epoch 是 1970。當成今天的
      // 話它會排在最上面，看起來像剛到的新信。
      final groups =
          MailGroups.groupByAge([const MailMessageJson(uid: 9)], now);

      expect(groups.single.bucket, MailBucket.earlier);
    });

    test('原本的順序不重排', () {
      final groups = MailGroups.groupByAge([
        at(DateTime(2026, 9, 10, 9, 0), uid: 1),
        at(DateTime(2026, 9, 10, 11, 0), uid: 2),
      ], now);

      expect(groups.single.items.map((m) => m.uid).toList(), [1, 2]);
    });
  });

  group('時間欄', () {
    final now = DateTime(2026, 9, 10, 14, 0);

    test('今天給時間、今年給日期、更早才寫年份', () {
      expect(MailGroups.formatDate(DateTime(2026, 9, 10, 9, 5), now), '09:05');
      expect(MailGroups.formatDate(DateTime(2026, 9, 8), now), '09/08');
      expect(MailGroups.formatDate(DateTime(2025, 9, 8), now), '2025/09/08');
    });

    test('沒有日期就不畫', () {
      expect(MailGroups.formatDate(DateTime.fromMillisecondsSinceEpoch(0), now),
          '');
    });
  });

  test('四位數以上的信件數要有千分位', () {
    // 「4367 封」很容易看成 43 萬。
    expect(MailGroups.formatCount(4367), '4,367');
    expect(MailGroups.formatCount(0), '0');
  });
}
