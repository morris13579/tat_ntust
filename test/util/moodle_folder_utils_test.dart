import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/util/moodle_folder_utils.dart';
import 'package:flutter_test/flutter_test.dart';

Contents c(String name, {String path = '/', int size = 0, int modified = 0}) =>
    Contents(
      type: 'file',
      filename: name,
      filepath: path,
      filesize: size,
      timemodified: modified,
    );

void main() {
  group('listing', () {
    test('根目錄只回這一層的檔案', () {
      final l = MoodleFolderUtils.listing([
        c('a.pdf'),
        c('deep.pdf', path: '/講義/'),
        c('b.pdf'),
      ]);

      expect(l.files.map((f) => f.filename), ['a.pdf', 'b.pdf']);
    });

    test('子資料夾由 filepath 推出來，照名稱排序', () {
      final l = MoodleFolderUtils.listing([
        c('root.pdf'),
        c('x.pdf', path: '/講義/'),
        c('y.pdf', path: '/講義/'),
        c('z.pdf', path: '/作業/'),
      ]);

      expect(l.folders.map((f) => f.name), ['作業', '講義']);
      expect(l.files.map((f) => f.filename), ['root.pdf']);
    });

    test('fileCount 是整個子樹的檔案數', () {
      final l = MoodleFolderUtils.listing([
        c('x', path: '/a/'),
        c('y', path: '/a/b/'),
        c('z', path: '/a/b/'),
      ]);

      expect(l.folders.single.name, 'a');
      expect(l.folders.single.fileCount, 3);
    });

    test('子資料夾的 path 可以直接餵回 listing', () {
      final contents = [
        c('root.pdf'),
        c('x.pdf', path: '/講義/'),
      ];
      final root = MoodleFolderUtils.listing(contents);
      final sub =
          MoodleFolderUtils.listing(contents, path: root.folders.single.path);

      expect(root.folders.single.path, '/講義/');
      expect(sub.files.map((f) => f.filename), ['x.pdf']);
      expect(sub.folders, isEmpty);
    });

    test('深層路徑只回那一層', () {
      final contents = [
        c('x', path: '/a/'),
        c('y', path: '/a/b/'),
        c('z', path: '/a/b/'),
      ];
      final l = MoodleFolderUtils.listing(contents, path: '/a/b/');

      expect(l.files.map((f) => f.filename), ['y', 'z']);
    });

    test('filepath 是空字串時當成根目錄（url 模組的 null）', () {
      final l = MoodleFolderUtils.listing([c('link', path: '')]);

      expect(l.files.single.filename, 'link');
      expect(l.folders, isEmpty);
    });

    test('同名子資料夾只出現一次', () {
      final l = MoodleFolderUtils.listing([
        c('x', path: '/a/'),
        c('y', path: '/a/'),
        c('z', path: '/a/'),
      ]);

      expect(l.folders.length, 1);
      expect(l.folders.single.fileCount, 3);
    });

    test('同名檔案維持原本的相對順序', () {
      final first = c('same.pdf', size: 1);
      final second = c('same.pdf', size: 2);
      final l = MoodleFolderUtils.listing([first, second]);

      expect(l.files.map((f) => f.filesize), [1, 2]);
    });

    test('完全空的 contents 是空 listing', () {
      expect(MoodleFolderUtils.listing(const []).isEmpty, isTrue);
    });

    test('不存在的路徑回空 listing 而不是拋', () {
      final l = MoodleFolderUtils.listing([c('x')], path: '/沒有這一層/');

      expect(l.isEmpty, isTrue);
    });
  });

  group('normalizePath', () {
    test('空字串當成根目錄', () {
      expect(MoodleFolderUtils.normalizePath(''), '/');
    });

    test('補上頭尾斜線', () {
      expect(MoodleFolderUtils.normalizePath('a/b'), '/a/b/');
    });

    test('收掉重複斜線', () {
      expect(MoodleFolderUtils.normalizePath('//a///b//'), '/a/b/');
    });

    test('反斜線換成斜線', () {
      expect(MoodleFolderUtils.normalizePath(r'\a\b\'), '/a/b/');
    });
  });

  group('segments', () {
    test('segments', () {
      expect(MoodleFolderUtils.segments('/a/b/'), ['a', 'b']);
      expect(MoodleFolderUtils.segments('/'), isEmpty);
    });
  });

  group('compareNames', () {
    test('數字段落照數值比', () {
      expect(MoodleFolderUtils.compareNames('week2', 'week10'), lessThan(0));
      expect(MoodleFolderUtils.compareNames('第10章', '第2章'), greaterThan(0));
    });

    test('大小寫不敏感，但仍有確定的順序', () {
      final names = ['readme', 'README'];
      names.sort(MoodleFolderUtils.compareNames);

      expect(MoodleFolderUtils.compareNames('Abc', 'abd'), lessThan(0));
      expect(MoodleFolderUtils.compareNames('README', 'readme'), isNot(0));
      expect(names, ['README', 'readme']);
    });

    test('中文照 Unicode 碼位排，不是筆畫也不是拼音', () {
      // 「作」U+4F5C 在「講」U+8B1B 之前；ICU 定序會照拼音把「講」排前面。
      expect(MoodleFolderUtils.compareNames('作業', '講義'), lessThan(0));
    });
  });
}
