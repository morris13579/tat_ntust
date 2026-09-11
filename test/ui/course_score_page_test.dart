import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/controller/course_data/course_data_controller.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_gradereport_get_grade_items.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/store/cache_store.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/ui/components/tile/moodle_file_tile.dart';
import 'package:flutter_app/ui/pages/course_data/screen/course_score_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 成績頁的畫面規格，資料來自 `gradereport_user_get_grade_items`。
///
/// 課程總分只能看結構化的 `itemtype == 'course'`，不可以比對項目名稱：那串字是
/// Moodle 依**使用者的 Moodle 介面語言**產生的（get_string('coursetotal',
/// 'grades')），與 App 的語系無關，比對文字的話同學把 Moodle 介面切成英文就會
/// 靜靜地不再加粗。所以下面刻意用**英文**的項目名稱來測課程總分。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadTestL10n();
  });

  setUp(() {
    resetAppStatics();
    // 離線時 run() 有快取就直接回 Stale，不碰網路，因此整個測試不需要網路。
    ConnectivityProbe.instance = FakeConnectivityProbe(online: false);
    Model.instance.setAccount('B10000000');
  });

  tearDown(() {
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
  });

  CourseInfoJson courseInfoOf(String id) => CourseInfoJson(
        main: CourseMainInfoJson(course: CourseMainJson(id: id)),
      );

  /// 把成績直接放進 `cache_moodle_score`，讓離線的 run() 命中它。
  /// 這裡刻意走正式路徑上的 [decodeCachedScore]，不另外寫一份 decoder。
  Future<void> seedScore(String courseId, MoodleUserGradesEntity grades) =>
      CacheStore.instance.write<MoodleUserGradesEntity>(
        CacheKey<MoodleUserGradesEntity>(
          'cache_moodle_score',
          courseId,
          decode: decodeCachedScore,
        ),
        grades,
      );

  Future<void> pumpScorePage(WidgetTester tester, String courseId) async {
    // 狀態現在住在 CourseDataController 裡：正式路徑上是 CourseDataPage
    // 在進入時一次發完三個分頁的請求，分頁自己不發。
    final controller = CourseDataController(courseId);
    await controller.loadScore();
    // 正式路徑上這一頁掛在 CourseDataPage 的 Scaffold 底下。
    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(
          body:
              CourseScorePage(courseInfoOf(courseId), controller: controller)),
    ));
    await tester.pumpAndSettle();
  }

  /// 老師回饋是唯一會展開的東西，點整列就會開。
  Future<void> expand(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  FontWeight? weightOfTitle(WidgetTester tester, String title) =>
      tester.widget<Text>(find.text(title)).style?.fontWeight;

  MoodleUserGradesEntity gradesWith(List<MoodleGradeItemEntity> items) =>
      MoodleUserGradesEntity(
        courseId: 28914,
        userId: 5252,
        userFullName: '測試學生',
        maxDepth: 2,
        gradeItems: items,
      );

  testWidgets('Moodle 介面是英文時，課程總分仍然加粗（舊行為在這裡不會加粗）', (tester) async {
    await seedScore(
      'AT1001',
      gradesWith([
        MoodleGradeItemEntity(
          id: 1,
          itemName: 'Quiz 1',
          itemType: 'mod',
          gradeFormatted: '90.00',
        ),
        MoodleGradeItemEntity(
          id: 2,
          itemName: 'Course total',
          itemType: 'course',
          gradeFormatted: '85.00',
        ),
      ]),
    );

    await pumpScorePage(tester, 'AT1001');

    expect(weightOfTitle(tester, 'Course total'), FontWeight.bold);
    expect(weightOfTitle(tester, 'Quiz 1'), FontWeight.w500);
  });

  testWidgets('類別總分是半粗，不會被誤判成課程總分', (tester) async {
    await seedScore(
      'AT1002',
      gradesWith([
        MoodleGradeItemEntity(
          id: 1,
          itemName: 'Category total',
          itemType: 'category',
          gradeFormatted: '70.00',
        ),
        MoodleGradeItemEntity(
          id: 2,
          itemName: 'Course total',
          itemType: 'course',
          gradeFormatted: '85.00',
        ),
      ]),
    );

    await pumpScorePage(tester, 'AT1002');

    expect(weightOfTitle(tester, 'Category total'), FontWeight.w600);
    expect(weightOfTitle(tester, 'Course total'), FontWeight.bold);
  });

  testWidgets('展開後顯示的是 *formatted 那一組（graderaw 是 null 也不會空白）', (tester) async {
    // moodle2.ntust.edu.tw 實測：學生 token 拿不到 graderaw，
    // 只有 gradeformatted / percentageformatted / weightformatted /
    // rangeformatted 有值。用原始數值欄位畫的話整頁會是空的。
    await seedScore(
      'AT1003',
      gradesWith([
        MoodleGradeItemEntity(
          id: 1,
          itemName: '期中考',
          itemType: 'mod',
          gradeRaw: null,
          gradeFormatted: '90.00',
          percentageFormatted: '90.00 %',
          weightFormatted: '30.00 %',
          rangeFormatted: '0-100',
          feedback: '寫得不錯',
          feedbackFormat: 1,
        ),
      ]),
    );

    await pumpScorePage(tester, 'AT1003');

    // 四個值不再各佔一列：百分比、權量、全距擠在標題底下那一行，分數自己
    // 一欄靠右，回饋才需要展開。
    expect(
      find.text('90.00 % · ${R.current.weight} 30.00 % · '
          '${R.current.fullRange} 0-100 · ${R.current.gradeFeedbackTag}'),
      findsOneWidget,
    );
    expect(find.text('90.00'), findsOneWidget, reason: '分數欄');

    await expand(tester, '期中考');
    expect(find.text('寫得不錯', findRichText: true), findsOneWidget);
  });

  testWidgets('空字串與整串 &nbsp; 的欄位整列不畫', (tester) async {
    await seedScore(
      'AT1004',
      gradesWith([
        MoodleGradeItemEntity(
          id: 1,
          itemName: '作業一',
          itemType: 'mod',
          gradeFormatted: '-',
          percentageFormatted: '',
          weightFormatted: '10.00 %',
          rangeFormatted: '0-100',
          // Moodle 對「沒有回饋」送的就是這一串，不是空字串。
          feedback: '&nbsp;',
        ),
      ]),
    );

    await pumpScorePage(tester, 'AT1004');

    // 空字串的百分比不出現，整串 &nbsp; 等於沒有回饋——那一行就不該有
    // 「老師回饋」這個可以點開的提示。
    expect(
      find.text('${R.current.weight} 10.00 % · '
          '${R.current.fullRange} 0-100'),
      findsOneWidget,
    );
    expect(find.textContaining(R.current.gradeFeedbackTag), findsNothing);
  });

  testWidgets('itemname 是 null 的項目直接跳過，不會畫出無名的一列', (tester) async {
    await seedScore(
      'AT1005',
      gradesWith([
        MoodleGradeItemEntity(id: 1, itemType: 'mod', gradeFormatted: '60.00'),
        MoodleGradeItemEntity(
          id: 2,
          itemName: '課程總分',
          itemType: 'course',
          gradeFormatted: '85.00',
        ),
      ]),
    );

    await pumpScorePage(tester, 'AT1005');

    expect(find.text('課程總分'), findsOneWidget);
    expect(find.text('60.00'), findsNothing, reason: '無名的那一列整列不畫');
  });

  testWidgets('全距的 HTML 實體在解碼邊界就還原，畫面上不會出現 &ndash;', (tester) async {
    // Moodle 送的全距是 `0&ndash;100`。修在 widget 裡用字串取代只會治這一頁，
    // 所以還原寫在 MoodleRepository.normalizeScore，網路與快取兩條路都經過它
    // ——這個測試走的正是快取那一條。
    await seedScore(
      'AT1006',
      gradesWith([
        MoodleGradeItemEntity(
          id: 1,
          itemName: '期末考',
          itemType: 'mod',
          gradeFormatted: '88.00',
          percentageFormatted: '88.00&nbsp;%',
          weightFormatted: '25.00&nbsp;%',
          rangeFormatted: '0&ndash;100',
        ),
      ]),
    );

    await pumpScorePage(tester, 'AT1006');

    expect(find.textContaining('&ndash;'), findsNothing);
    expect(find.textContaining('&nbsp;'), findsNothing);
    expect(
      find.text('88.00 % · ${R.current.weight} 25.00 % · '
          '${R.current.fullRange} 0\u2013100'),
      findsOneWidget,
    );
  });

  testWidgets('只有空標籤的回饋不算有回饋：那一行不掛「回饋」，整列也點不開', (tester) async {
    // Moodle 對「沒有回饋」不只送空字串，也會送一個空殼 div。照字串長度算的話
    // 每一列都會掛上「回饋」，這個提示就等於不存在。
    await seedScore(
      'AT1007',
      gradesWith([
        MoodleGradeItemEntity(
          id: 1,
          itemName: '作業二',
          itemType: 'mod',
          gradeFormatted: '70.00',
          feedback: '<div class="no-overflow"><p>&nbsp;</p></div>',
        ),
      ]),
    );

    await pumpScorePage(tester, 'AT1007');

    expect(find.textContaining(R.current.gradeFeedbackTag), findsNothing);
    await expand(tester, '作業二');
    expect(find.text(R.current.collapse), findsNothing);
  });

  testWidgets('有回饋的列：那一行有「回饋」，展開後是「老師回饋」加一個「收起」', (tester) async {
    await seedScore(
      'AT1008',
      gradesWith([
        MoodleGradeItemEntity(
          id: 1,
          itemName: 'HW3',
          itemType: 'mod',
          gradeFormatted: '92.00',
          feedback: '<div class="no-overflow"><p>變異數少了交叉項</p></div>',
        ),
        MoodleGradeItemEntity(
          id: 2,
          itemName: 'HW4',
          itemType: 'mod',
          gradeFormatted: '60.00',
        ),
      ]),
    );

    await pumpScorePage(tester, 'AT1008');

    // 提示只掛在有回饋的那一列上——這才是「哪一列有老師回饋」的答案。
    expect(find.textContaining(R.current.gradeFeedbackTag), findsOneWidget);

    await expand(tester, 'HW3');
    expect(find.text(R.current.assignFeedback), findsOneWidget);
    expect(find.text(R.current.collapse), findsOneWidget);
    expect(find.text('變異數少了交叉項', findRichText: true), findsOneWidget);

    // 「收起」收得回去。
    await tester.tap(find.text(R.current.collapse));
    await tester.pumpAndSettle();
    expect(find.text(R.current.collapse), findsNothing);
  });

  testWidgets('回饋裡的 pluginfile 連結變成一列附件，一般連結留在文字裡', (tester) async {
    await seedScore(
      'AT1009',
      gradesWith([
        MoodleGradeItemEntity(
          id: 1,
          itemName: 'HW3',
          itemType: 'mod',
          gradeFormatted: '92.00',
          feedback: '<p>對照附件</p>'
              '<p><a href="https://moodle2.ntust.edu.tw/webservice/pluginfile.php/'
              '1/assignfeedback_file/feedback/9/hw3_feedback.pdf">'
              'hw3_feedback.pdf</a></p>'
              '<p><a href="https://example.com/notes">課外閱讀</a></p>',
        ),
      ]),
    );

    await pumpScorePage(tester, 'AT1009');
    await expand(tester, 'HW3');

    expect(find.widgetWithText(MoodleFileTile, 'hw3_feedback.pdf'),
        findsOneWidget);
    // 一般網址不是檔案，換成一列「下載」會騙人。
    expect(find.widgetWithText(MoodleFileTile, '課外閱讀'), findsNothing);
    expect(find.text('課外閱讀', findRichText: true), findsOneWidget);
  });
}
