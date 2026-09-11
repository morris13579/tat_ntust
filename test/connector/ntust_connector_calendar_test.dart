import 'dart:io';

import 'package:flutter_app/src/connector/ntust_connector.dart';
import 'package:flutter_test/flutter_test.dart';

/// `NTUSTConnector.parseCalendarLinks` 的 fixture golden。
///
/// fixture 是用**未登入的純 HTTP** 抓的
/// `https://www.academic.ntust.edu.tw/p/404-1048-78935.php?Lang=zh-tw`
/// 原始頁面，一個字都沒改。
///
/// **這個來源不需要學生帳號**：getCalendarUrl 只對公開頁面做一次 GET，
/// 不帶任何憑證。
///
/// 為什麼值得一份 golden：這段解析對 DOM 有三個很脆的假設（第 2 個
/// .meditor 區塊、其中最後一個 ul、li 文字以 "(" 分段），學校改版時是這裡
/// 先壞，而壞掉的表現是行事曆頁完全打不開，不是少一個學年度。
void main() {
  String loadFixture() =>
      File('test/fixtures/academic/calendar_404-1048-78935.html')
          .readAsStringSync();

  test('抓出 .ics 那一份清單（不是上面的 .xlsx 清單）', () {
    final links =
        NTUSTConnector.parseCalendarLinks(loadFixture(), 'https://example.com');

    // 取 `.last` 的理由：同一個 .meditor 區塊裡前面還有一份 .xlsx 的
    // 學年度清單，那份不是 App 要的。這條斷言就是在守 `.last`。
    for (final url in links.values) {
      expect(url, endsWith('.ics'));
    }
    expect(links.length, 6);
  });

  test('key 是 "(" 之前那段，value 是接上 host 的絕對網址', () {
    final links =
        NTUSTConnector.parseCalendarLinks(loadFixture(), 'https://example.com');

    expect(links['115學年度行事曆'],
        'https://example.com//var/file/48/1048/img/488885678.ics');
    expect(links['113學年度行事曆'],
        'https://example.com//var/file/48/1048/img/NTUST113.ics');
  });

  test('li 內 </a> 之後的補充文字（"-114.7.3更新"）不會混進 key', () {
    // 114 那一列的 li 是 `<a>114學年度行事曆(ics檔案)</a><span>-114.7.3更新</span>`，
    // i.text 會把 span 一起吃進來，靠 split("(").first 砍掉。
    final links =
        NTUSTConnector.parseCalendarLinks(loadFixture(), 'https://example.com');

    expect(links.containsKey('114學年度行事曆'), isTrue);
    expect(links['114學年度行事曆'],
        'https://example.com//var/file/48/1048/img/788923882.ics');
  });

  test('href 本來就以 "/" 開頭，接上 host 會多一個斜線（刻意保留的現況）', () {
    // 實測伺服器對 `...tw//var/file/...ics` 照回 200，雙斜線不是壞網址。
    // 釘成 golden，是要讓「順手修掉」的人知道那是可觀察行為的改動。
    final links = NTUSTConnector.parseCalendarLinks(
        loadFixture(), NTUSTConnector.calendarHost);

    expect(links['115學年度行事曆'], contains('.tw//var/'));
  });

  test('一列裡有兩個連結時只取第一個', () {
    // 110 那一列除了 ics 還接了一個修正版的連結。
    final links =
        NTUSTConnector.parseCalendarLinks(loadFixture(), 'https://example.com');

    expect(links['110學年度行事曆 '],
        'https://example.com//var/file/48/1048/img/541567461.ics');
  });

  test('key 可能帶著尾端空白（現況，會原樣顯示在學期選單上）', () {
    // 110 那一列的文字是 "110學年度行事曆(ics檔案) (經本校…)"，
    // split("(").first 留下一個尾端空白，而它會原樣顯示在選單上；
    // 要 trim 是可觀察行為的改動，不是無害的整理。
    final links =
        NTUSTConnector.parseCalendarLinks(loadFixture(), 'https://example.com');

    expect(links.containsKey('110學年度行事曆 '), isTrue);
    expect(links.containsKey('110學年度行事曆'), isFalse);
  });

  test('頁面結構不對時直接拋例外，由 getCalendarUrl 的 catch 轉成 null', () {
    // 學校改版把 .meditor 拿掉的話會是這條路。之所以不在 parse 裡吞掉，
    // 是因為 getCalendarUrl 的 catch 有 Log.eWithStack，回報得到 Crashlytics；
    // 在這裡默默回空 Map 反而會變成「選單是空的」的無聲失敗。
    expect(
      () => NTUSTConnector.parseCalendarLinks(
          '<html><body>maintenance</body></html>', 'https://example.com'),
      throwsA(isA<RangeError>()),
    );
  });
}
