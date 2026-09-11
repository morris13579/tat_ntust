import 'package:flutter_app/src/util/moodle_pluginfile_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// 前綴推導的規格。伺服器兩個方向都只是前綴的 `str_replace`，所以這裡認的
/// 只有「網址結尾等於 filepath + filename 的某一種寫法」。
void main() {
  ({String filepath, String filename, String url}) file({
    String filepath = '/',
    required String filename,
    required String url,
  }) =>
      (filepath: filepath, filename: filename, url: url);

  const host = 'https://moodle2.ntust.edu.tw/webservice/pluginfile.php';
  const area = '$host/555/assignsubmission_onlinetext/submissions_onlinetext';

  group('baseOf', () {
    test('前綴不含結尾斜線，而且接回 rawEncodePath 就是原本的網址', () {
      const url = '$area/8801/a.png';
      final base = MoodlePluginFileUtils.baseOf([
        file(filename: 'a.png', url: url),
      ]);

      expect(base, '$area/8801');
      expect(base!.endsWith('/'), isFalse);
      expect(base + MoodlePluginFileUtils.rawEncodePath('/a.png'), url);
    });

    test('PHP rawurlencode 的寫法認得出來——Uri.encodeComponent 不會編 `()`', () {
      const url = '$area/8801/Lecture%20%281%29.png';
      expect(MoodlePluginFileUtils.encodePath('/Lecture (1).png'),
          '/Lecture%20(1).png');
      expect(MoodlePluginFileUtils.rawEncodePath('/Lecture (1).png'),
          '/Lecture%20%281%29.png');

      expect(
          MoodlePluginFileUtils.baseOf([
            file(filename: 'Lecture (1).png', url: url),
          ]),
          '$area/8801');
    });

    test('沒編碼的網址也認，子資料夾算在後綴裡', () {
      expect(
          MoodlePluginFileUtils.baseOf([
            file(
                filepath: '/sub/',
                filename: 'a.png',
                url: '$area/8801/sub/a.png'),
          ]),
          '$area/8801');
    });

    test('帶 query 的網址先切掉再比——有些 exporter 寫死 forcedownload', () {
      expect(
          MoodlePluginFileUtils.baseOf([
            file(filename: 'a.png', url: '$area/8801/a.png?forcedownload=1'),
          ]),
          '$area/8801');
    });

    test('空清單、空網址、對不上的名字都回 null', () {
      expect(MoodlePluginFileUtils.baseOf(const []), isNull);
      expect(MoodlePluginFileUtils.baseOf([file(filename: 'a.png', url: '')]),
          isNull);
      expect(
          MoodlePluginFileUtils.baseOf([
            file(filename: 'b.png', url: '$area/8801/a.png'),
          ]),
          isNull);
    });

    test('第一筆對不上就換下一筆，不是整包放棄', () {
      expect(
          MoodlePluginFileUtils.baseOf([
            file(filename: 'b.png', url: '$area/8801/a.png'),
            file(filename: 'c.png', url: '$area/8801/c.png'),
          ]),
          '$area/8801');
    });
  });
}
