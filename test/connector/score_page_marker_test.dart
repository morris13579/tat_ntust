import 'package:flutter_app/src/connector/score_connector.dart';
import 'package:flutter_test/flutter_test.dart';

/// 收網時機的守衛：只看網址會在 OIDC 交握中途就誤收，因為那一站的查詢字串
/// 裡也有 client_id=StuScoreQueryServ。
void main() {
  /// 使用者回報時貼出來的那一段，逐字保留。
  const ssoBootstrap =
      '<input type="hidden" name="iss" value="https://ssoam2.ntust.edu.tw/">'
      '<noscript>Click here to finish the authorization process: '
      '<input type="submit" /></noscript></form>'
      '<script>document.form.submit();</script></body></html>';

  group('isScorePage', () {
    test('SSO 自動送出表單不是成績頁——這就是回報的那個 bug', () {
      expect(ScoreConnector.isScorePage(ssoBootstrap), isFalse,
          reason: '收下這一頁等於在轉址鏈的第一站就放棄，成績永遠抓不到');
    });

    test('有 box-content alerts 但沒有 tbody 的轉址頁也不算', () {
      expect(
        ScoreConnector.isScorePage(
            '<div class="box-content alerts"><p>處理中</p></div>'),
        isFalse,
      );
    });

    test('完全空白／載入中的頁面不算', () {
      expect(ScoreConnector.isScorePage(''), isFalse);
      expect(ScoreConnector.isScorePage('<html><body></body></html>'), isFalse);
    });

    test('真的成績頁才算', () {
      expect(
        ScoreConnector.isScorePage(
            '<div class="box-content alerts"><table><tbody>'
            '<tr><td>1141</td></tr></tbody></table></div>'),
        isTrue,
      );
    });

    test('大寫的 TBODY 也認得', () {
      expect(
        ScoreConnector.isScorePage(
            '<DIV CLASS="box-content alerts"><TABLE><TBODY>'
            '<TR><TD>1141</TD></TR></TBODY></TABLE></DIV>'),
        isTrue,
      );
    });

    test('isScorePage 為真的頁面，parseScoreRank 一定看得懂', () {
      // 兩道判準必須同進退，否則會收下一頁卻回報失敗。
      const html = '<html><body>'
          '<div class="box-content alerts"><table><tbody>'
          '<tr><td>1</td><td>1141</td><td>CS1234701</td><td>作業系統</td>'
          '<td>3</td><td>A+</td><td></td><td></td></tr>'
          '</tbody></table></div></body></html>';
      expect(ScoreConnector.isScorePage(html), isTrue);
      expect(ScoreConnector.parseScoreRank(html), isNotNull);
    });
  });
}
