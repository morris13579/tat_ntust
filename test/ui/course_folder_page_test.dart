import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/util/file_utils.dart';
import 'package:flutter_app/ui/components/file_type_icon.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_folder_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sprintf/sprintf.dart';

import '../helpers/test_l10n.dart';

/// 資料夾頁的畫面規格。這一頁不打網路：資料整包由呼叫端傳進來。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadTestL10n();
    await initializeDateFormatting();
  });

  final courseInfo = CourseInfoJson(
    main:
        CourseMainInfoJson(course: CourseMainJson(id: 'CS1001', name: '作業系統')),
  );

  Contents file(String name,
          {String path = '/',
          String mimetype = '',
          int size = 0,
          int modified = 0}) =>
      Contents(
        type: 'file',
        filename: name,
        filepath: path,
        mimetype: mimetype,
        filesize: size,
        timemodified: modified,
      );

  final tree = Modules(
    name: '講義',
    modname: 'folder',
    contents: [
      file('dataset.bin'),
      file('week1',
          mimetype: 'application/pdf', size: 2048, modified: 1725500100),
      file('week2.pptx'),
      file('sub1.pdf', path: '/第一週/'),
      file('sub2.pdf', path: '/第一週/'),
      file('deep.pdf', path: '/第一週/補充/'),
    ],
  );

  /// 正式路徑是從課程詳情頁 `Get.to` 進來的。直接當 home 的話
  /// `Get.currentRoute` 是 '/'，點子資料夾那條 preventDuplicates 的迴歸就測不到。
  Future<void> pump(WidgetTester tester, CourseFolderPage page) async {
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
    await tester.pump();
    unawaited(Get.to(() => page));
    await tester.pumpAndSettle();
  }

  testWidgets('根層先畫子資料夾再畫檔案，標題與麵包屑都是模組名', (tester) async {
    await pump(tester, CourseFolderPage(courseInfo, tree));

    expect(find.widgetWithText(AppBar, '講義'), findsOneWidget);
    // 麵包屑在 AppBar 之外還有一份。
    expect(find.text('講義'), findsNWidgets(2));

    final titles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((t) => (t.title as Text).data)
        .toList();
    expect(titles, ['第一週', 'dataset.bin', 'week1', 'week2.pptx']);
  });

  testWidgets('每個檔案依 mimetype 或檔名畫出自己的 icon', (tester) async {
    await pump(tester, CourseFolderPage(courseInfo, tree));

    final icons =
        tester.widgetList<FileTypeIcon>(find.byType(FileTypeIcon)).toList();
    expect(icons.map((i) => i.iconName), ['unknown', 'pdf', 'powerpoint']);
  });

  testWidgets('檔案列的副標帶大小與修改時間，中間以 · 分隔', (tester) async {
    await pump(tester, CourseFolderPage(courseInfo, tree));

    final subtitle = find.textContaining(FileUtils.formatBytes(2048, 1));
    expect(subtitle, findsOneWidget);
    expect(tester.widget<Text>(subtitle).data, contains(' · '));
    expect(tester.widget<Text>(subtitle).data, contains('2024'));
  });

  testWidgets('沒有大小也沒有修改時間的檔案不畫副標', (tester) async {
    await pump(tester, CourseFolderPage(courseInfo, tree));

    expect(find.textContaining('0.0 KB'), findsNothing);
    expect(find.textContaining('1970'), findsNothing);
  });

  testWidgets('子資料夾列顯示整個子樹的檔案數', (tester) async {
    await pump(tester, CourseFolderPage(courseInfo, tree));

    expect(find.text(sprintf(R.current.folderFileCount, [3])), findsOneWidget);
  });

  testWidgets('點子資料夾一路進到第三層，返回鍵一層一層回得來', (tester) async {
    await pump(tester, CourseFolderPage(courseInfo, tree));

    await tester.tap(find.text('第一週'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '第一週'), findsOneWidget);
    expect(find.text('講義 / 第一週'), findsOneWidget);
    expect(find.text('sub1.pdf'), findsOneWidget);
    expect(find.text('dataset.bin'), findsNothing);

    // 第二層再推一次同一個型別的頁面，GetX 的 preventDuplicates 會靜默擋掉。
    await tester.tap(find.text('補充'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '補充'), findsOneWidget);
    expect(find.text('deep.pdf'), findsOneWidget);

    Get.back();
    await tester.pumpAndSettle();

    expect(find.text('sub1.pdf'), findsOneWidget);

    Get.back();
    await tester.pumpAndSettle();

    expect(find.text('dataset.bin'), findsOneWidget);
  });

  testWidgets('上百個檔案的一層只建可見的列', (tester) async {
    final many = Modules(
      name: '講義',
      modname: 'folder',
      contents: [for (var i = 0; i < 200; i++) file('file$i.pdf')],
    );

    await pump(tester, CourseFolderPage(courseInfo, many));

    final built = tester.widgetList(find.byType(ListTile)).length;
    expect(built, greaterThan(0));
    expect(built, lessThan(200), reason: '整張卡片塞進一個 Column 就會全部建出來');
  });

  testWidgets('深層路徑可以直接建構', (tester) async {
    await pump(tester, CourseFolderPage(courseInfo, tree, path: '/第一週/補充/'));

    expect(find.widgetWithText(AppBar, '補充'), findsOneWidget);
    expect(find.text('講義 / 第一週 / 補充'), findsOneWidget);
    expect(find.text('deep.pdf'), findsOneWidget);
  });

  testWidgets('空資料夾畫空狀態，不拋也不畫任何 icon', (tester) async {
    await pump(tester,
        CourseFolderPage(courseInfo, Modules(name: '空的', modname: 'folder')));

    expect(find.byType(FileTypeIcon), findsNothing);
    expect(find.text(R.current.folderEmpty), findsOneWidget);
  });

  testWidgets('子路徑底下沒有東西時也是空狀態', (tester) async {
    await pump(tester, CourseFolderPage(courseInfo, tree, path: '/不存在/'));

    expect(find.text(R.current.folderEmpty), findsOneWidget);
  });
}
