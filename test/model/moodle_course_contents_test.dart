import 'dart:convert';
import 'dart:io';

import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/util/moodle_folder_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Contents.mimetype', () {
    test('回應帶 mimetype 時解析出來', () {
      final c = Contents.fromJson({
        'type': 'file',
        'filename': 'week1.pdf',
        'filepath': '/',
        'filesize': 1234,
        'fileurl':
            'https://moodle.ntust.edu.tw/webservice/pluginfile.php/1/week1.pdf',
        'mimetype': 'application/pdf',
        'timemodified': 1700000000,
      });

      expect(c.filename, 'week1.pdf');
      expect(c.mimetype, 'application/pdf');
    });

    test('欄位缺席或為 null 都退回空字串（舊站台、舊快取）', () {
      expect(Contents.fromJson({'filename': 'a.pdf'}).mimetype, '');
      expect(
          Contents.fromJson({'filename': 'a.pdf', 'mimetype': null}).mimetype,
          '');
    });

    test('toJson / fromJson 往返保留 mimetype，寫進快取再讀回來不會變成空字串', () {
      final original = Contents(filename: 'a.pdf', mimetype: 'application/pdf');
      final restored =
          Contents.fromJson(json.decode(json.encode(original.toJson())));

      expect(restored.mimetype, 'application/pdf');
    });

    test('整段 section → module → contents 都解得出來', () {
      final section = MoodleCoreCourseGetContents.fromJson({
        'id': 1,
        'name': '第一週',
        'visible': 1,
        'summary': '',
        'summaryformat': 1,
        'modules': [
          {
            'id': 10,
            'name': '講義',
            'modname': 'resource',
            'modicon':
                'https://moodle.ntust.edu.tw/theme/image.php/boost/core/1/f/pdf',
            'contents': [
              {'filename': 'week1.pdf', 'mimetype': 'application/pdf'},
            ],
          },
        ],
      });

      final module = section.modules.single;
      expect(module.modname, 'resource');
      expect(module.modicon, endsWith('/f/pdf'));
      expect(module.contents.single.mimetype, 'application/pdf');
    });
  });

  group('core_course_get_contents.json', () {
    MoodleCoreCourseGetContents section() =>
        MoodleCoreCourseGetContents.fromJson(json.decode(
            File('test/fixtures/moodle/core_course_get_contents.json')
                .readAsStringSync()) as Map<String, dynamic>);

    test('整份 fixture 解得出來，資料夾的四個檔案帶著路徑與大小', () {
      final modules = section().modules;
      expect(modules.length, 5);

      final folder = modules.first;
      expect(folder.modname, 'folder');
      expect(folder.contents.map((c) => c.filepath),
          ['/', '/講義/', '/講義/第一週/', '/作業/']);
      expect(folder.contents.map((c) => c.filesize),
          [245760, 1048576, 32768, 5242880]);
      expect(folder.contents.first.timemodified, 1725500100);
    });

    test('url 模組的 filepath: null 解成空字串', () {
      final url = section().modules.firstWhere((m) => m.modname == 'url');

      expect(url.contents.single.filepath, '');
      expect(url.contents.single.timecreated, 0);
    });

    test('contents: [] 的模組解成空 list 而不是 null', () {
      final empty = section().modules.firstWhere((m) => m.name == '尚未上傳的檔案');

      expect(empty.contents, isEmpty);
    });

    test('舊快取殘留的 folderIsNone 被忽略，不會讓 fromJson 拋', () {
      // 欄位已移除，json_serializable 對未知 key 是靜靜略過。
      expect(section().modules.first.name, '課程講義');
    });

    test('fixture 直接餵進 MoodleFolderUtils：根層兩個子資料夾加一個檔案', () {
      final l = MoodleFolderUtils.listing(section().modules.first.contents);

      expect(l.folders.map((f) => f.name), ['作業', '講義']);
      expect(l.folders.map((f) => f.fileCount), [1, 2]);
      expect(l.files.map((f) => f.filename), ['課程大綱.pdf']);
    });
  });
}
