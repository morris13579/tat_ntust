import 'package:flutter_app/src/config/mail_config.dart';
import 'package:flutter_app/src/connector/mail_connector.dart';
import 'package:flutter_test/flutter_test.dart';

/// 分頁的序號窗口。
///
/// 這一組存在的理由是速度：先前每一頁都先 `SEARCH ALL`，四千多封的信箱每一頁
/// 都要把四千多個 UID 拉回來再排序，成本隨信箱大小線性成長。現在改成從游標那
/// 一封的序號往回抓連續一段，這個純函式就是那段窗口的算法。
void main() {
  int start(int end, [int limit = MailConfig.pageSize]) =>
      MailConnector.pageStart(end, limit);

  test('滿滿一頁：從 end 往回數 limit 封', () {
    expect(start(4371, 50), 4322);
    expect(4371 - 4322 + 1, 50, reason: '這個範圍剛好 50 封');
  });

  test('剛好一頁', () {
    expect(start(50, 50), 1);
  });

  test('不足一頁就從第一封開始，不會算出 0 或負數', () {
    // IMAP 的序號從 1 起算，送出 `0:30` 這種範圍伺服器會回 BAD。
    expect(start(30, 50), 1);
    expect(start(1, 50), 1);
  });

  test('只多一封', () {
    expect(start(51, 50), 2);
  });

  test('start 回到 1 就代表沒有更舊的了——`hasMore` 就是拿它判的', () {
    expect(start(50, 50), 1);
    expect(start(51, 50), greaterThan(1));
  });
}
