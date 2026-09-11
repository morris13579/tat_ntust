import 'dart:io';

import 'package:flutter_app/src/util/file_icon_table.dart';
import 'package:flutter_app/src/util/file_icon_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('FileIconUtils.iconNameForExtension', () {
    test('常見課程檔案各自有 icon', () {
      const expected = {
        'pdf': 'pdf',
        'doc': 'document',
        'docx': 'document',
        'xls': 'spreadsheet',
        'xlsx': 'spreadsheet',
        'csv': 'spreadsheet',
        'ppt': 'powerpoint',
        'pptx': 'powerpoint',
        'zip': 'archive',
        'rar': 'archive',
        '7z': 'archive',
        'mp4': 'video',
        'mov': 'video',
        'mp3': 'audio',
        'wav': 'audio',
        'jpg': 'image',
        'png': 'image',
        'svg': 'image',
        'gif': 'gif',
        'txt': 'text',
        'json': 'text',
        'html': 'markup',
        'xml': 'markup',
        'java': 'sourcecode',
        'c': 'sourcecode',
        'cpp': 'sourcecode',
        'odt': 'writer',
        'ods': 'calc',
        'odp': 'impress',
        'epub': 'epub',
        'psd': 'psd',
        'h5p': 'h5p',
        'mbz': 'moodle',
      };
      for (final entry in expected.entries) {
        expect(FileIconUtils.iconNameForExtension(entry.key), entry.value,
            reason: entry.key);
      }
    });

    test('沒有 icon、但 MIME 主類型是 image/video/audio/text 的副檔名，用主類型當 icon', () {
      expect(FileIconUtils.iconNameForExtension('webp'), 'image');
      expect(FileIconUtils.iconNameForExtension('mkv'), 'video');
      expect(FileIconUtils.iconNameForExtension('mid'), 'audio');
      expect(FileIconUtils.iconNameForExtension('py'), 'text');
      expect(FileIconUtils.iconNameForExtension('yaml'), 'text');
    });

    test('大小寫、前置點、query、anchor、filepool hash 都清掉', () {
      expect(FileIconUtils.iconNameForExtension('PDF'), 'pdf');
      expect(FileIconUtils.iconNameForExtension('.pdf'), 'pdf');
      expect(FileIconUtils.iconNameForExtension('pdf?forcedownload=1'), 'pdf');
      expect(FileIconUtils.iconNameForExtension('pdf#page=2'), 'pdf');
      expect(
        FileIconUtils.iconNameForExtension('pdf_${'0123456789abcdef' * 2}'),
        'pdf',
      );
    });

    test('認不得的副檔名回 null（dmg、xxx 在官方表裡就是 unknown）', () {
      expect(FileIconUtils.iconNameForExtension('dmg'), isNull);
      expect(FileIconUtils.iconNameForExtension('xxx'), isNull);
      expect(FileIconUtils.iconNameForExtension('exe'), isNull);
      expect(FileIconUtils.iconNameForExtension(''), isNull);
      expect(FileIconUtils.iconNameForExtension('.'), isNull);
    });
  });

  group('FileIconUtils.extensionOf / iconNameForFilename', () {
    test('取最後一個點之後的部分並轉小寫', () {
      expect(FileIconUtils.extensionOf('lecture01.pdf'), 'pdf');
      expect(FileIconUtils.extensionOf('第一週 講義.PPTX'), 'pptx');
      expect(FileIconUtils.extensionOf('archive.tar.gz'), 'gz');
      expect(FileIconUtils.extensionOf('.gitignore'), 'gitignore');
    });

    test('沒有副檔名回 null', () {
      expect(FileIconUtils.extensionOf('README'), isNull);
      expect(FileIconUtils.extensionOf('ends.with.dot.'), isNull);
      expect(FileIconUtils.extensionOf(''), isNull);
    });

    test('檔名走到 icon', () {
      expect(FileIconUtils.iconNameForFilename('第一週 講義.PPTX'), 'powerpoint');
      expect(FileIconUtils.iconNameForFilename('archive.tar.gz'), 'archive');
      expect(FileIconUtils.iconNameForFilename('README'), isNull);
      expect(FileIconUtils.iconNameForFilename('.gitignore'), isNull);
    });
  });

  group('FileIconUtils.iconNameForMimetype', () {
    test('常見 MIME type', () {
      expect(FileIconUtils.iconNameForMimetype('application/pdf'), 'pdf');
      expect(
        FileIconUtils.iconNameForMimetype(
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document'),
        'document',
      );
      expect(
          FileIconUtils.iconNameForMimetype('application/msword'), 'document');
      expect(FileIconUtils.iconNameForMimetype('image/jpeg'), 'image');
      expect(FileIconUtils.iconNameForMimetype('text/plain'), 'text');
      expect(FileIconUtils.iconNameForMimetype('application/zip'), 'archive');
      expect(FileIconUtils.iconNameForMimetype('application/x-zip-compressed'),
          'archive');
    });

    test('`;` 之後的參數切掉、大小寫與前後空白不影響', () {
      expect(
        FileIconUtils.iconNameForMimetype('video/mp4; codecs="avc1.42E01E"'),
        'video',
      );
      expect(FileIconUtils.iconNameForMimetype(' Application/PDF '), 'pdf');
      expect(FileIconUtils.iconNameForMimetype('text/plain; charset=utf-8'),
          'text');
    });

    test('認不得的 MIME 回 null，好讓呼叫端退回用檔名判斷', () {
      expect(FileIconUtils.iconNameForMimetype('application/octet-stream'),
          isNull);
      expect(FileIconUtils.iconNameForMimetype(''), isNull);
      expect(FileIconUtils.iconNameForMimetype('   '), isNull);
      expect(FileIconUtils.iconNameForMimetype('made/up'), isNull);
    });
  });

  group('FileIconUtils.iconNameFromModicon', () {
    const host = 'https://moodle.ntust.edu.tw/theme/image.php';

    test('Moodle 4.x 的 slasharguments 網址', () {
      expect(
        FileIconUtils.iconNameFromModicon('$host/boost/core/1700000000/f/pdf'),
        'pdf',
      );
      expect(
        FileIconUtils.iconNameFromModicon(
            '$host/boost/core/1700000000/f/spreadsheet'),
        'spreadsheet',
      );
    });

    test('3.x 帶尺寸後綴', () {
      expect(
        FileIconUtils.iconNameFromModicon(
            '$host/boost/core/1700000000/f/document-24'),
        'document',
      );
    });

    test('slasharguments 關閉時的 query 形式（斜線被百分比編碼）', () {
      expect(
        FileIconUtils.iconNameFromModicon(
            '$host?theme=boost&component=core&rev=1700000000&image=f%2Fpdf-24'),
        'pdf',
      );
      expect(
        FileIconUtils.iconNameFromModicon(
            '$host?theme=boost&component=core&rev=1700000000&image=f/archive'),
        'archive',
      );
    });

    test('不是檔案類型 icon 的模組圖示回 null', () {
      expect(
        FileIconUtils.iconNameFromModicon(
            '$host/boost/forum/1700000000/monologo'),
        isNull,
      );
      expect(
        FileIconUtils.iconNameFromModicon(
            '$host/boost/folder/1700000000/monologo'),
        isNull,
      );
      expect(FileIconUtils.iconNameFromModicon(''), isNull);
    });

    test('舊版才有的名稱（本專案沒有對應 SVG）回 null，不會指到不存在的資產', () {
      expect(
        FileIconUtils.iconNameFromModicon(
            '$host/boost/core/1700000000/f/avi-24'),
        isNull,
      );
      expect(
        FileIconUtils.iconNameFromModicon('$host/boost/core/1700000000/f/jpeg'),
        isNull,
      );
    });

    test('壞掉的百分比編碼不會拋', () {
      expect(
          FileIconUtils.iconNameFromModicon('$host?image=f%2Fpdf%zz'), 'pdf');
      expect(FileIconUtils.iconNameFromModicon('%'), isNull);
    });
  });

  group('FileIconUtils.iconFor', () {
    test('mimetype 優先於檔名', () {
      expect(
        FileIconUtils.iconFor(filename: 'a.txt', mimetype: 'application/pdf'),
        'pdf',
      );
    });

    test('mimetype 認不得就看檔名（官方 App 這時會畫 unknown）', () {
      expect(
        FileIconUtils.iconFor(
            filename: 'a.pdf', mimetype: 'application/octet-stream'),
        'pdf',
      );
    });

    test('檔名也認不得就看 modicon', () {
      expect(
        FileIconUtils.iconFor(
          filename: 'data.bin',
          modicon:
              'https://moodle.ntust.edu.tw/theme/image.php/boost/core/1/f/archive',
        ),
        'archive',
      );
    });

    test('三個線索都沒有就是 unknown', () {
      expect(FileIconUtils.iconFor(), FileIconUtils.unknown);
      expect(FileIconUtils.iconFor(filename: 'README'), FileIconUtils.unknown);
      expect(
        FileIconUtils.iconFor(
            filename: 'x.exe', mimetype: 'application/octet-stream'),
        FileIconUtils.unknown,
      );
    });

    test('assetPath 指向 assets/image/files', () {
      expect(FileIconUtils.assetPath('pdf'), 'assets/image/files/pdf.svg');
      expect(FileIconUtils.assetPath(FileIconUtils.unknown),
          'assets/image/files/unknown.svg');
    });
  });

  group('icon 資產', () {
    final assetNames = Directory(FileIconUtils.assetDir)
        .listSync()
        .whereType<File>()
        .where((f) => p.extension(f.path) == '.svg')
        .map((f) => p.basenameWithoutExtension(f.path))
        .toSet();

    test('iconNames 與 assets/image/files/ 裡的 SVG 一一對應', () {
      expect(assetNames, unorderedEquals(FileIconUtils.iconNames));
    });

    test('對照表裡的每個 icon 名稱都有檔案', () {
      final used = {
        ...FileIconTable.byExtension.values,
        ...FileIconTable.byMimetype.values,
      };
      expect(used, isNotEmpty);
      expect(used.difference(FileIconUtils.iconNames), isEmpty);
    });

    test('unknown 一定有檔案：那是所有退路的終點', () {
      expect(FileIconUtils.iconNames, contains(FileIconUtils.unknown));
      expect(File(FileIconUtils.assetPath(FileIconUtils.unknown)).existsSync(),
          isTrue);
    });
  });
}
