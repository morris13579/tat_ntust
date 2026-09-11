import 'package:dio/dio.dart';
import 'package:flutter_app/src/connector/interceptors/redacting_log_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

/// 遮蔽規則。
///
/// 防的是實機上觀察到的洩漏：Dio 內建的 LogInterceptor 會把完整的 ssoam2
/// session cookie 與 AuthServer token 印進 logcat，debug build 上任何讀得到
/// logcat 的程式都拿得到。
void main() {
  group('header', () {
    test('cookie 與 authorization 的值被遮掉，鍵留著', () {
      final out = RedactingLogInterceptor.redactHeaders({
        'cookie': 'AuthServer=super-secret-value; ntustLan=zh-TW',
        'authorization': 'Bearer abcdef',
        'user-agent': 'Mozilla/5.0',
      });

      expect(out['cookie'], isNot(contains('super-secret-value')));
      expect(out['authorization'], isNot(contains('abcdef')));
      // 鍵要留著：知道「有沒有帶 cookie」對除錯是必要的。
      expect(out.keys, containsAll(['cookie', 'authorization']));
      // 無關的 header 原樣保留。
      expect(out['user-agent'], 'Mozilla/5.0');
    });

    test('大小寫不影響判斷', () {
      final out = RedactingLogInterceptor.redactHeaders({'Cookie': 'a=b'});
      expect(out['Cookie'], isNot(contains('a=b')));
    });
  });

  group('body', () {
    test('密碼與 token 欄位被遮掉，其餘保留', () {
      final out = RedactingLogInterceptor.redactBody({
        'Username': 'B10902000',
        'Password': 'hunter2',
        'wstoken': 'deadbeef',
        '__RequestVerificationToken': 'csrf-value',
        'courseId': 'CS1234701',
      }) as Map;

      expect(out['Username'], 'B10902000', reason: '帳號是識別用的，留著');
      expect(out['Password'], isNot(contains('hunter2')));
      expect(out['wstoken'], isNot(contains('deadbeef')));
      expect(out['__RequestVerificationToken'], isNot(contains('csrf-value')));
      expect(out['courseId'], 'CS1234701');
    });

    test('巢狀結構也會遞迴處理', () {
      final out = RedactingLogInterceptor.redactBody({
        'items': [
          {'password': 'a'},
          {'name': 'b'},
        ],
      }) as Map;
      final items = out['items'] as List;
      expect((items[0] as Map)['password'], isNot(contains('a')));
      expect((items[1] as Map)['name'], 'b');
    });

    test('字串 body 整個遮掉', () {
      // 登入請求的 body 正好是 form-urlencoded 字串，無法逐欄位判斷。
      final out = RedactingLogInterceptor.redactBody(
          'Username=B10902000&Password=hunter2');
      expect(out.toString(), isNot(contains('hunter2')));
    });

    test('null 維持 null', () {
      expect(RedactingLogInterceptor.redactBody(null), isNull);
    });
  });

  group('query 參數', () {
    test('wstoken 被遮掉，其餘保留', () {
      final out = RedactingLogInterceptor.redactUri(
          Uri.parse('https://moodle.ntust.edu.tw/webservice/rest/server.php'
              '?wstoken=deadbeef&wsfunction=core_course_get_contents'));

      expect(out, isNot(contains('deadbeef')));
      expect(out, contains('wsfunction=core_course_get_contents'));
      expect(out, contains('/webservice/rest/server.php'));
    });

    test('沒有 query 時原樣回傳', () {
      const url = 'https://ssoam2.ntust.edu.tw/';
      expect(RedactingLogInterceptor.redactUri(Uri.parse(url)), url);
    });
  });

  group('FormData（上傳頭貼那條路）', () {
    test('只印欄位名與檔名，token 的值不會出現', () {
      final out = RedactingLogInterceptor.redactBody(FormData.fromMap({
        'token': 'super-secret-wstoken',
        'file_1': MultipartFile.fromString('x', filename: 'profile.jpg'),
      }));

      expect(out, isA<Map>());
      final map = out as Map;
      expect(map['fields'], ['token']);
      expect(map['files'], ['profile.jpg']);
      // 連遮蔽後的長度提示都不該有：這一路乾脆完全不印值。
      expect(map.toString(), isNot(contains('super-secret-wstoken')));
      expect(map.toString(), isNot(contains('已遮蔽')));
    });
  });

  test('遮蔽字串保留長度資訊但不含原值', () {
    final masked = RedactingLogInterceptor.mask('hunter2');
    expect(masked, isNot(contains('hunter2')));
    // 「值是空的」與「值有 7 個字元」在除錯時是不同的資訊。
    expect(masked, contains('7'));
    expect(RedactingLogInterceptor.mask(''), '<空>');
  });
}
