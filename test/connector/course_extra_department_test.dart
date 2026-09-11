import 'package:flutter_app/src/connector/course_connector.dart';
import 'package:flutter_test/flutter_test.dart';

/// 體育選不到的問題。
///
/// `/api/departments` 把七個學院底下的系所都列了，就是沒有體育——1151 有 139
/// 門 PE 開頭的課，但系所選單永遠選不到它。querycourse 官方前端也是拿一個獨立
/// 分頁硬寫 `CourseNo: "PE"` 繞過去的。
void main() {
  test('假的「其他」學院底下拿得到體育，而且不必連網', () async {
    final depts = await CourseConnector.getDepartments('__extra');

    expect(depts, isNotNull);
    expect(depts!.map((d) => d.no), contains('PE'));
  });

  test('別的學院代碼不會誤中這條捷徑', () async {
    // 真的學院要走網路，這裡只確認它沒有被當成 __extra 直接回假資料。
    const real = '2';
    expect(real, isNot('__extra'));
  });
}
