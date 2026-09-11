import 'package:flutter_app/src/connector/score_connector.dart';
import 'package:flutter_test/flutter_test.dart';

/// 成績頁解析的守衛：看不懂的頁面一律回 null，不能回空結果。
///
/// `_fetchScorePage` 在第一次 `onLoadStop` 就收網，而 SSO 轉址鏈的每一站都會
/// 觸發它；轉址頁常常有 `box-content alerts` 卻沒有 `<tbody>`。一旦解析回傳
/// 「非 null 但完全空」的結果，呼叫端會當成功，把硬碟上的成績蓋成空白——
/// 使用者看到的是整頁空白而且沒有任何錯誤訊息。
///
/// 這裡刻意用最小的合成 HTML，不放真實成績頁：那是個人資料。
void main() {
  String page(String body) => '<html><body>$body</body></html>';

  const rankRow = '''
    <tr><td>1141</td><td>1</td><td>2</td><td>90</td><td>1</td><td>2</td><td>90</td></tr>''';
  const scoreRow = '''
    <tr><td>1</td><td>1141</td><td>CS1234701</td><td>作業系統</td>
        <td>3</td><td>A+</td><td></td><td></td></tr>''';

  group('看不懂的頁面一律回 null，不能回空結果', () {
    test('完全沒有 box-content alerts（被導回登入頁）', () {
      expect(ScoreConnector.parseScoreRank(page('<div>請先登入</div>')), isNull);
    });

    test('有 box-content alerts 但裡面沒有 tbody（轉址頁／錯誤頁）', () {
      // 這正是實機上抓到的形狀：class 在、表格不在。
      final html = page('<div class="box-content alerts"><p>處理中</p></div>');
      expect(ScoreConnector.parseScoreRank(html), isNull,
          reason: '這一份先前會回傳非 null 的空結果，把使用者的成績蓋掉');
    });

    test('結構看得懂但解析出零個學期，也不寫回', () {
      final html = page(
          '<div class="box-content alerts"><table><tbody></tbody></table></div>');
      expect(ScoreConnector.parseScoreRank(html), isNull);
    });
  });

  group('正常的頁面照常解析', () {
    test('排名 + 成績兩個區塊', () {
      final html = page('''
        <div class="box-content alerts"><table><tbody>$rankRow</tbody></table></div>
        <div class="box-content alerts"><table><tbody>$scoreRow</tbody></table></div>''');

      final info = ScoreConnector.parseScoreRank(html);
      expect(info, isNotNull);
      expect(info!.info.length, 1);
      expect(info.info[0].semester.year, '114');
      expect(info.info[0].semester.semester, '1');
      expect(info.info[0].item.length, 1);
      expect(info.info[0].item[0].courseId, 'CS1234701');
      expect(info.info[0].item[0].name, '作業系統');
      expect(info.info[0].item[0].score, 'A+');
    });

    test('只有一個區塊的新生：沒有排名表，但成績仍讀得到', () {
      // 這是 items 在兩段解析之間刻意不重設的理由。守衛不能誤傷這個情境。
      final html = page(
          '<div class="box-content alerts"><table><tbody>$scoreRow</tbody></table></div>');

      final info = ScoreConnector.parseScoreRank(html);
      expect(info, isNotNull, reason: '新生沒有排名表，但不該因此看不到成績');
      expect(info!.info[0].item[0].courseId, 'CS1234701');
    });
  });
}
