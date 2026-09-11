import 'package:flutter_app/src/util/html_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// `HtmlUtils.clean` 的安全契約測試。
///
/// 這裡刻意跟 html_utils_test.dart 分開：那邊凍結的是「還原了哪些實體」，
/// 這邊凍結的是「為什麼我們沒有在 clean 裡面做 sanitise」。
///
/// clean 的唯一呼叫端是 `moodle_webapi_connector.getCourseDirectory` 的
/// `Modules.name`，而它只流進 `Text` / `baseAppbar` / `RouteUtils.toWebViewPage`
/// 的 title（title 最後也只是 `Text`）；頁面上那幾個 HtmlWidget 吃的是
/// `ap.description`、成績表格 HTML、論壇貼文 HTML，都沒經過 clean。
/// 下面第三個測試會擋住「順手加剝標籤防護」這種看似安全、實際會吃掉課名的修法。
void main() {
  group('HtmlUtils.clean 的純文字 sink 契約', () {
    test('還原後會產生活的標記，所以輸出只能餵純文字 sink', () {
      // 這不是漏洞而是這個函式的本質：它是 escape 的反向操作。
      // 真正的防線是「呼叫端不得把輸出交給 HTML 渲染器」，
      // 不是在這裡假裝自己是 sanitiser。
      expect(
        HtmlUtils.clean('&lt;script&gt;alert(1)&lt;/script&gt;'),
        '<script>alert(1)</script>',
      );
    });

    test('數值實體同樣會被還原，所以輸出也不能拿去組檔案路徑', () {
      // `&#46;&#46;&#47;` 在原文是惰性的，還原後就是 `../`。
      // 目前下載檔名用的是 contents.filename 而不是 clean 過的 Modules.name，
      // 這條路徑沒有被打開；若哪天要用 name 當路徑，必須自己再做正規化。
      expect(HtmlUtils.clean('&#46;&#46;&#47;etc'), '../etc');
    });

    test('合法課名裡的 &lt; &gt; 必須完整保留，不得被當成標籤剝掉', () {
      // 這條是防守型測試：如果有人為了「修 XSS」在 clean 裡加剝標籤，
      // 這裡會紅。真實課名會用到 < >（數學式、版本標註），
      // 靜默刪字比一個沒有 sink 的注入風險嚴重。
      expect(HtmlUtils.clean('演算法 x&lt;y 進階'), '演算法 x<y 進階');
      expect(HtmlUtils.clean('C++ &lt;入門&gt;'), 'C++ <入門>');
    });
  });
}
