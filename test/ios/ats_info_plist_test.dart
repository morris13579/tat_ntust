import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `ios/Runner/Info.plist` 的 App Transport Security 設定守門測試。
///
/// `NSAllowsArbitraryLoads` 這類 key 只有放在 `NSAppTransportSecurity` dict
/// 裡面才有意義，放到最上層 iOS 會直接忽略；網域寫成 `ntut.edu.tw`（臺北科大，
/// 上游版本留下的）也一樣等於沒放行。兩種錯都沒有徵兆：plist 照樣合法、App
/// 照樣建置、模擬器上看不出來，只會讓人以為已經放行了。
///
/// 這裡直接讀 repo 內的原始檔（`flutter test` 的工作目錄就是套件根目錄），
/// 因為要驗的是那個檔案本身的結構，不是任何 Dart 端的行為。
void main() {
  const plistPath = 'ios/Runner/Info.plist';

  late String plist;

  setUpAll(() {
    // 先把 XML 註解拿掉：plist 的說明文字本身就寫著 `NSAllowsArbitraryLoads`
    // 與 `ntut.edu.tw`，不剝掉的話這個測試會被說明文字騙到。
    plist = File(plistPath)
        .readAsStringSync()
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  });

  /// 取出 `NSAppTransportSecurity` 那個 `<dict>` 的內容。
  ///
  /// 刻意用字串切割而不是完整的 plist 解析器：要驗的正是「key 在哪一層」，
  /// 會把巢狀攤平的讀法看不出層級。
  String atsBlock() {
    const key = '<key>NSAppTransportSecurity</key>';
    final start = plist.indexOf(key);
    expect(start, isNot(-1), reason: '找不到 NSAppTransportSecurity');
    final dictStart = plist.indexOf('<dict>', start);
    final dictEnd = plist.indexOf('</dict>', dictStart);
    return plist.substring(dictStart, dictEnd);
  }

  test('放寬的 key 必須在 NSAppTransportSecurity 裡面，不能在最上層', () {
    final ats = atsBlock();
    final outside = plist.replaceRange(
        plist.indexOf(ats), plist.indexOf(ats) + ats.length, '');

    expect(outside.contains('NSAllowsArbitraryLoadsInWebContent'), isFalse,
        reason: '放在 NSAppTransportSecurity 之外等於沒寫，iOS 會忽略它');
    expect(outside.contains('NSAllowsArbitraryLoads'), isFalse, reason: '同上');
  });

  test('只放行 WebView 內容，不要全域放行', () {
    // ATS 管不到 Dio：dart:io 的 HttpClient 走自己的 BoringSSL，不經
    // NSURLSession。需要放寬的只有 WKWebView 裡的內容——Moodle 的課程 HTML
    // 帶著 http:// 的圖片與連結。App 自己的連線維持嚴格。
    final ats = atsBlock();

    expect(ats.contains('NSAllowsArbitraryLoadsInWebContent'), isTrue);
    expect(
      RegExp(r'<key>NSAllowsArbitraryLoads</key>').hasMatch(ats),
      isFalse,
      reason: 'lib/ 裡沒有任何明文 http 端點，學校六台主機全是 HTTPS，'
          '不需要全域放行',
    );
  });

  test('不要再出現 ntut.edu.tw——那是別間學校', () {
    // 整份專案只有這個 plist 出現過 ntut.edu.tw。
    expect(RegExp(r'\bntut\.edu\.tw').hasMatch(plist), isFalse,
        reason: '臺北科大的網域，從上游抄來忘了改');
  });

  test('沒有留下對不到任何主機的例外網域', () {
    // 例外網域用來放行明文或降低 TLS 版本。ntust.edu.tw 底下六台主機全是
    // HTTPS 且 TLS 1.2 以上，沒有一台需要例外；留著只會讓人以為有。
    expect(atsBlock().contains('NSExceptionDomains'), isFalse);
  });
}
