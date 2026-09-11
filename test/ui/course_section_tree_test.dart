import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/course_section_list.dart';
import 'package:flutter_test/flutter_test.dart';

/// 檔案分頁的分組規則。純資料，不需要 pump。
///
/// 段名用 NTUST Moodle 真的會回的格式（「09月 7日 - 09月 13日」）。
void main() {
  Contents file(String name) => Contents(type: 'file', filename: name);

  Modules module(String modname, String name, {List<Contents>? contents}) =>
      Modules(
          id: name.hashCode,
          modname: modname,
          name: name,
          contents: contents ?? []);

  MoodleCoreCourseGetContents section(String name, List<Modules> modules) =>
      MoodleCoreCourseGetContents(
          id: name.hashCode, name: name, modules: modules);

  /// 學期中的任何一天都不落在下面這些九月的週次裡，currentWeek 才會是 null，
  /// 分組結果就只剩 otherWithContent / empty 兩堆。
  final outsideTerm = DateTime(2026, 3, 1);

  group('CourseSection.fileCount', () {
    test('沒有 contents 的 resource 不算檔案——那是還沒上傳東西的空殼', () {
      // fixture 裡的「尚未上傳的檔案」就是這個形狀，點下去只吐「沒有任何資料」。
      final s = CourseSection.of(section('第一週', [module('resource', '第一週講義')]));

      expect(s.fileCount, 0);
      expect(s.hasFiles, isFalse);
    });

    test('resource 附檔跟主檔一起回來時仍然只算一列', () {
      final s = CourseSection.of(section('第一週', [
        module('resource', '講義',
            contents: [file('week1.html'), file('week1_img.png')]),
      ]));

      expect(s.fileCount, 1);
    });

    test('資料夾數裡面的檔案，空資料夾沒有東西可以下載', () {
      final withFiles = CourseSection.of(section('第一週', [
        module('folder', '課程講義',
            contents: [file('a.pdf'), file('b.pptx'), file('c.docx')]),
      ]));
      final empty =
          CourseSection.of(section('第二週', [module('folder', '課程講義')]));

      expect(withFiles.fileCount, 3);
      expect(empty.fileCount, 0);
    });

    test('url 的 contents 是外部連結不是檔案，整段都是 url 仍然沒有檔案', () {
      // NTUST 的「課程錄影」整段就是播放清單連結。
      final s = CourseSection.of(section('課程錄影', [
        module('url', '本學期課程錄影播放清單',
            contents: [Contents(type: 'url', filename: '本學期課程錄影播放清單')]),
        module('url', '參考資源播放清單',
            contents: [Contents(type: 'url', filename: '參考資源播放清單')]),
      ]));

      expect(s.fileCount, 0);
      expect(s.hasFiles, isFalse);
    });

    test('討論區、作業、測驗、標籤不算檔案', () {
      final s = CourseSection.of(section('一般', [
        module('forum', '公告'),
        module('assign', '期中報告'),
        module('quiz', '小考'),
        module('label', '記得繳交作業'),
      ]));

      expect(s.fileCount, 0);
      expect(s.hasFiles, isFalse);
    });
  });

  group('CourseSectionTree 的週次分組', () {
    final tree = CourseSectionTree.of([
      section('一般', [module('forum', '公告')]),
      section('09月 7日 - 09月 13日', [
        module('resource', '授課大綱', contents: [file('outline.pdf')]),
        module('resource', '成績評量方式', contents: [file('grading.pdf')]),
      ]),
      section('09月 14日 - 09月 20日', [
        module('resource', '第二週講義', contents: [file('week2.pdf')]),
      ]),
      section('09月 21日 - 09月 27日', [module('assign', '期中報告')]),
      section('09月 28日 - 10月 4日', []),
    ], now: outsideTerm);

    test('是週次格式，且今天不在任何一週裡', () {
      expect(tree.weekly, isTrue);
      expect(tree.currentWeek, isNull);
    });

    test('有任何模組就算有內容——作業、討論區與連結都算', () {
      expect(tree.otherWithContent.map((s) => s.raw.name), [
        '一般',
        '09月 7日 - 09月 13日',
        '09月 14日 - 09月 20日',
        '09月 21日 - 09月 27日',
      ]);
    });

    test('只有真的一片空白的那一段才收進「沒有內容」', () {
      expect(tree.empty.map((s) => s.raw.name), ['09月 28日 - 10月 4日']);
    });

    test('統計列：檔案數只數下載得到的，週數數的是有內容的週', () {
      expect(tree.totalFiles, 3);
      expect(tree.sectionsWithContent, 4);
    });
  });
}
