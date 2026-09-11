import 'package:flutter_app/src/util/html_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// 特徵化測試：凍結 HtmlUtils 目前的行為（含已知的怪異之處）。
///
/// `clean` 只有 `moodle_webapi_connector.dart` 一個呼叫端（課程名稱去實體化）。
void main() {
  group('HtmlUtils.clean', () {
    test('沒有實體的純文字原樣回傳', () {
      expect(HtmlUtils.clean('資料結構 A班'), '資料結構 A班');
    });

    test('空字串回傳空字串', () {
      expect(HtmlUtils.clean(''), '');
    });

    test('五個常見實體都會被還原', () {
      expect(HtmlUtils.clean('&amp;'), '&');
      expect(HtmlUtils.clean('&lt;'), '<');
      expect(HtmlUtils.clean('&gt;'), '>');
      expect(HtmlUtils.clean('&quot;'), '"');
    });

    test('&nbsp; 還原成 U+00A0 不間斷空格，不是一般空格', () {
      // 注意：課名比對／trim 若預期一般空格會踩到這裡。
      final result = HtmlUtils.clean('\u8cc7\u5de5&nbsp;\u7cfb');
      expect(result, '\u8cc7\u5de5\u00a0\u7cfb');
      expect(result.contains('\u0020'), isFalse);
    });

    test('中文夾雜實體：只換實體，中文不動', () {
      expect(HtmlUtils.clean('資工&amp;電機&lt;必修&gt;'), '資工&電機<必修>');
    });

    test('未知實體維持原樣不會被吃掉', () {
      expect(HtmlUtils.clean('&unknownentity;'), '&unknownentity;');
    });

    test('缺分號的 &amp 仍會被還原成 &（現況）', () {
      // html_unescape 允許省略分號，所以原文本來就想顯示「&amp」四個字元時
      // 會被改寫。
      expect(HtmlUtils.clean('A&amp B'), 'A& B');
    });

    test('clean 不是冪等的：連續兩次會把 &amp;lt; 拆成 <（現況）', () {
      expect(HtmlUtils.clean('&amp;lt;'), '&lt;');
      expect(HtmlUtils.clean(HtmlUtils.clean('&amp;lt;')), '<');
    });
  });
}
