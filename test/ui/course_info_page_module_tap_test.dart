import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_quizzes_by_courses.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_user_attempts.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_user_best_grade.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_folder_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_forum_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_info_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/course_directory_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_quiz_detail_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/course_section_list.dart';
import 'package:flutter_app/src/controller/course_data/course_data_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:get/get.dart';
import 'package:sprintf/sprintf.dart';

import 'package:flutter_app/src/service/task_ui_delegate.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/recording_ui.dart';
import '../helpers/test_l10n.dart';

/// contents 為空的模組被點到時的行為。只點空模組，所以不會進到真的會寫檔的
/// FileDownload。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadTestL10n();
    // 週次標題會走 DateFormat，沒有這一行拿不到語系資料。
    await initializeDateFormatting();
  });

  /// toast 現在走 TaskUiDelegate（見 MyToast），所以用既有的錄音假物件收。
  final ui = RecordingUi();
  setUp(() {
    ui.toasts.clear();
    TaskUiDelegate.instance = ui;
  });
  tearDown(() => TaskUiDelegate.instance = const NoopTaskUiDelegate());

  final courseInfo = CourseInfoJson(
    main:
        CourseMainInfoJson(course: CourseMainJson(id: 'CS1001', name: '作業系統')),
  );

  Future<void> pumpWithModule(WidgetTester tester, Modules module) async {
    await tester.pumpWidget(GetMaterialApp(
      home: CourseInfoPage(
        courseInfo,
        MoodleCoreCourseGetContents(name: '第一週', modules: [module]),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text(module.name));
    await tester.pumpAndSettle();
  }

  testWidgets('點 contents 為空的 resource 模組只會 toast，不會拋', (tester) async {
    await pumpWithModule(tester, Modules(name: '尚未上傳的檔案', modname: 'resource'));

    expect(tester.takeException(), isNull);
    expect(ui.toasts, [R.current.nothingHere]);
  });

  testWidgets('點 contents 為空的 url 模組也是 toast，而不是靜默', (tester) async {
    await pumpWithModule(tester, Modules(name: '課程網站', modname: 'url'));

    expect(tester.takeException(), isNull);
    expect(ui.toasts, [R.current.nothingHere]);
  });

  testWidgets('點空的 folder 模組會推進資料夾頁並畫空狀態', (tester) async {
    await pumpWithModule(tester, Modules(name: '空資料夾', modname: 'folder'));

    expect(find.byType(CourseFolderPage), findsOneWidget);
    expect(find.text(R.current.folderEmpty), findsOneWidget);
    expect(ui.toasts, isEmpty);
  });

  testWidgets('點 forum 模組會推進討論區頁，不再直接開網頁', (tester) async {
    // forum 的 contents 也是空的；先前這一支是 openWebView。
    AuthSession.instance = FakeAuthSession();
    MoodleRepository.instance = _FailingQuizRepository();
    addTearDown(() {
      AuthSession.instance = const UninstalledAuthSession();
      MoodleRepository.instance = MoodleRepository();
    });

    await pumpWithModule(
        tester, Modules(name: '課程討論區', modname: 'forum', instance: 5499));

    final page = tester.widget<CourseForumPage>(find.byType(CourseForumPage));
    expect(page.forumId, 5499, reason: 'Modules.instance 就是 forum id');
    expect(page.forumName, '課程討論區');
    expect(ui.toasts, isEmpty);
  });

  testWidgets('點 quiz 模組會推進測驗頁，不再掉進 default 分支 toast', (tester) async {
    // quiz 的 contents 一定是空的，先前會落到 resource/default 那一支。
    AuthSession.instance = FakeAuthSession();
    MoodleRepository.instance = _FailingQuizRepository();
    addTearDown(() {
      AuthSession.instance = const UninstalledAuthSession();
      MoodleRepository.instance = MoodleRepository();
    });

    await pumpWithModule(
        tester, Modules(name: '期中考', modname: 'quiz', instance: 4101));

    expect(find.byType(CourseQuizDetailPage), findsOneWidget);
    expect(ui.toasts, isEmpty);
  });

  group('檔案分頁', _directoryTests);
}

/// 測驗頁一開就會發三個請求、討論區頁發一個；這裡只驗導頁，所以全部立刻失敗。
class _FailingQuizRepository extends MoodleRepository {
  @override
  Future<Result<List<Discussions>>> getForumDiscussions(int forumId) async =>
      const Failed(FetchFailed('x'));

  @override
  Future<Result<MoodleQuiz>> getQuiz(String courseId, int quizId) async =>
      const Failed(FetchFailed('x'));

  @override
  Future<Result<List<MoodleQuizAttempt>>> getQuizAttempts(int quizId,
          {bool background = false}) async =>
      const Failed(FetchFailed('x'));

  @override
  Future<Result<MoodleQuizBestGrade>> getQuizBestGrade(int quizId,
          {bool background = false}) async =>
      const Failed(FetchFailed('x'));
}

/// 檔案分頁的就地展開、兩種課程格式與檔名搜尋。
void _directoryTests() {
  final courseInfo = CourseInfoJson(
    main:
        CourseMainInfoJson(course: CourseMainJson(id: 'CS1001', name: '作業系統')),
  );

  Modules file(String name) => Modules(
        id: name.hashCode,
        name: name,
        modname: 'resource',
        contents: [Contents(filename: '$name.pdf', filesize: 1024)],
      );

  /// 今天一定落在裡面的週次名稱，格式與 NTUST Moodle 回來的一樣。
  String weekAroundToday() {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 1));
    final to = now.add(const Duration(days: 1));
    return '${from.month.toString().padLeft(2, '0')}月 ${from.day} 日'
        ' - ${to.month.toString().padLeft(2, '0')}月 ${to.day} 日';
  }

  Future<void> pumpDirectory(
      WidgetTester tester, List<MoodleCoreCourseGetContents> sections) async {
    final controller = CourseDataController('CS1001');
    controller.directory.value = Ok(sections);
    addTearDown(controller.dispose);
    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(
        body: CourseDirectoryPage(courseInfo, controller: controller),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('點週次是就地展開，不再推 CourseInfoPage', (tester) async {
    await pumpDirectory(tester, [
      MoodleCoreCourseGetContents(
          id: 1, name: weekAroundToday(), modules: [file('本週講義')]),
      MoodleCoreCourseGetContents(
          id: 2, name: '02月 03 日 - 02月 09 日', modules: [file('舊講義')]),
    ]);

    // 本週那一張預設展開，其餘的收著。
    expect(find.text('本週講義.pdf'), findsNothing);
    expect(find.text('本週講義'), findsOneWidget);
    expect(find.text('舊講義'), findsNothing);

    await tester.tap(find.byType(CourseSectionRow).at(1));
    await tester.pumpAndSettle();

    expect(find.text('舊講義'), findsOneWidget);
    expect(find.byType(CourseInfoPage), findsNothing);
  });

  testWidgets('主題式：展開先露三個檔案，其餘收在連結後面', (tester) async {
    await pumpDirectory(tester, [
      MoodleCoreCourseGetContents(id: 1, name: '一般', modules: [file('課程大綱')]),
      MoodleCoreCourseGetContents(
        id: 2,
        name: '課程教材',
        summary: '<p>講義與參考資料</p>',
        modules: [for (var i = 1; i <= 5; i++) file('講義 $i')],
      ),
    ]);

    expect(find.text(R.current.topic), findsOneWidget);
    expect(
        find.text(sprintf(R.current.fileStatsTopic, [6, 2])), findsOneWidget);
    // summary 的 HTML 標籤要被剝掉。
    expect(find.text('講義與參考資料'), findsOneWidget);

    await tester.tap(find.text('課程教材'));
    await tester.pumpAndSettle();

    expect(find.text('講義 3'), findsOneWidget);
    expect(find.text('講義 4'), findsNothing);

    await tester.tap(find.text(sprintf(R.current.showRemainingFiles, [2])));
    await tester.pumpAndSettle();

    expect(find.text('講義 5'), findsOneWidget);
  });

  testWidgets('搜尋檔名會跨週次篩選，而且不打 API', (tester) async {
    await pumpDirectory(tester, [
      MoodleCoreCourseGetContents(id: 1, name: '一般', modules: [file('課程大綱')]),
      MoodleCoreCourseGetContents(
          id: 2, name: '01月 05 日 - 01月 11 日', modules: [file('第一章講義')]),
    ]);

    await tester.enterText(find.byType(TextField), '講義');
    await tester.pumpAndSettle();

    expect(find.text('第一章講義'), findsOneWidget);
    expect(find.text('課程大綱'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text(R.current.fileSearchNoResult), findsOneWidget);
  });
}
