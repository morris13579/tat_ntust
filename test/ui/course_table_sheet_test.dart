import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/pages/course_table/modal/course_options_sheet.dart';
import 'package:flutter_app/ui/pages/course_table/modal/favorite_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_l10n.dart';

/// 課表標頭的兩張選單。
///
/// 「導入其他課程」只有在看自己的課表時才給：加進去的課會寫回目前那一份
/// 快取，看著別人的課表加課等於改到對方的資料。
///
/// 收藏清單的每一列都要能認出「哪一份是現在畫面上的」——一整排只差年度的
/// 標籤，沒有記號就得靠記憶。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadTestL10n();
  });

  Future<void> pumpOpener(WidgetTester tester, VoidCallback onPressed) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: TextButton(onPressed: onPressed, child: const Text('開')),
        ),
      ),
    ));
    await tester.tap(find.text('開'));
    await tester.pumpAndSettle();
  }

  CourseTableJson table({
    required String studentId,
    required String year,
    required String semester,
    int courses = 2,
  }) {
    final value = CourseTableJson(
      studentId: studentId,
      courseSemester: SemesterJson(year: year, semester: semester),
    );
    for (int i = 0; i < courses; i++) {
      value.courseInfoMap[Day.monday]![SectionNumber.values[i]] =
          CourseInfoJson(
        main: CourseMainInfoJson(
          course: CourseMainJson(id: 'C$i', name: '課程$i', credits: '3'),
        ),
      );
    }
    return value;
  }

  group('課表選項', () {
    testWidgets('看自己的課表時列出切換課表與導入其他課程', (tester) async {
      final results = <CourseTableOption?>[];
      await pumpOpener(tester, () {});
      final context = tester.element(find.text('開'));
      final future = showCourseOptionsSheet(context: context, canImport: true);
      unawaitedResult(future, results);
      await tester.pumpAndSettle();

      expect(find.text(R.current.switchTable), findsOneWidget);
      expect(find.text(R.current.importCourse), findsOneWidget);
      // 副標說明每一列會做什麼，不是只有一個動詞。
      expect(find.text(R.current.importCourseHint), findsOneWidget);

      await tester.tap(find.text(R.current.importCourse));
      await tester.pumpAndSettle();
      expect(results, [CourseTableOption.importCourse]);
    });

    testWidgets('看別人的課表時沒有導入其他課程', (tester) async {
      await pumpOpener(tester, () {});
      final context = tester.element(find.text('開'));
      unawaitedResult(
          showCourseOptionsSheet(context: context, canImport: false), []);
      await tester.pumpAndSettle();

      expect(find.text(R.current.switchTable), findsOneWidget);
      expect(find.text(R.current.importCourse), findsNothing);
    });
  });

  group('收藏的課表清單', () {
    testWidgets('目前這一份有 check，每一列都有門數與學分', (tester) async {
      final value = [
        table(studentId: 'B11000001', year: '115', semester: '1', courses: 2),
        table(studentId: 'B11000001', year: '114', semester: '2', courses: 3),
      ];
      await pumpOpener(tester, () {});
      final context = tester.element(find.text('開'));
      unawaitedResult(
          showFavoriteSheet(
              context: context,
              value: value,
              selected: favoriteLabelOf(
                  'B11000001', SemesterJson(year: '115', semester: '1'))),
          <FavoriteChoice?>[]);
      await tester.pumpAndSettle();

      expect(find.text('B11000001 115-1'), findsOneWidget);
      expect(find.text('B11000001 114-2'), findsOneWidget);
      expect(find.text(favoriteSummary(value[0])), findsOneWidget);
      expect(find.text(favoriteSummary(value[1])), findsOneWidget);
      // 只有目前那一份帶記號。
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
      // 刪除留在每一列上，包含目前這一份。
      expect(find.byIcon(LucideIcons.trash2), findsNWidgets(2));
    });
  });
}

/// 把選單的回傳值收進 list，測試不必自己接 Future。
void unawaitedResult<T>(Future<T?> future, List<T?> into) {
  future.then(into.add);
}
