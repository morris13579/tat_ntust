import 'package:flutter/material.dart';
import 'package:flutter_app/generated/l10n.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/controller/course_data/course_data_controller.dart';
import 'package:flutter_app/src/controller/course_detail/course_detail_controller.dart';
import 'package:flutter_app/src/controller/course_member/course_member_controller.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_enrol_get_users.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_gradereport_get_grade_items.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions.dart';
import 'package:flutter_app/src/model/ntust/ap_tree_json.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/store/cache_store.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/auth/app_auth_session.dart';
import 'package:flutter_app/ui/pages/course_data/screen/course_announcement_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/course_directory_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/course_score_page.dart';
import 'package:flutter_app/ui/pages/course_detail/screen/course_info_page.dart';
import 'package:flutter_app/ui/pages/course_member/course_member_page.dart';
import 'package:flutter_app/ui/pages/subsystem/sub_system_page.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/ntust_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 網路請求不可以寫在 build() 裡：每一次 rebuild（上層 setState、切換語言、
/// 鍵盤彈出……）都會重新登入、重新發請求，並再閃一次全螢幕進度遮罩。

/// 數 [MoodleRepository] 被呼叫幾次，其餘回一份空的成功結果。
///
/// 數次數而不是比對 Future 實例：請求發在 initState / controller 時沒有
/// Future 可比，真正要釘住的是「rebuild 不會多打一次 API」。
class _CountingMoodleRepository extends MoodleRepository {
  int calls = 0;

  @override
  Future<Result<MoodleUserGradesEntity>> getCourseScore(String courseId) async {
    calls++;
    return Ok(MoodleUserGradesEntity());
  }

  @override
  Future<Result<List<MoodleCoreCourseGetContents>>> getCourseDirectory(
      String courseId) async {
    calls++;
    return const Ok(<MoodleCoreCourseGetContents>[]);
  }

  @override
  Future<Result<MoodleModForumGetForumDiscussions>> getAnnouncements(
      String courseId) async {
    calls++;
    return Ok(MoodleModForumGetForumDiscussions());
  }

  /// 名單頁要畫得出列時才用得到，預設空清單。
  List<MoodleCoreEnrolGetUsers> membersToReturn = const [];

  @override
  Future<Result<List<MoodleCoreEnrolGetUsers>>> getMembers(
      String courseId) async {
    calls++;
    return Ok(membersToReturn);
  }
}

/// 同上，NTUST 那一側。
class _CountingNtustRepository extends NtustRepository {
  int calls = 0;

  @override
  Future<Result<List<APTreeJson>>> getSubSystemTree() async {
    calls++;
    return const Ok(<APTreeJson>[]);
  }

  @override
  Future<Result<CourseExtraInfoJson>> getCourseExtraInfo(
      String courseId, SemesterJson semester) async {
    calls++;
    return Ok(CourseExtraInfoJson());
  }
}

void main() {
  // 請求由頁面自己發或由 controller 發都可以，
  // 重點是 rebuild 之後呼叫次數不能增加。
  late CourseDataController dataController;
  late CourseDetailController detailController;
  late CourseMemberController memberController;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadTestL10n();
  });

  late _CountingMoodleRepository repo;
  late _CountingNtustRepository ntustRepo;

  setUp(() {
    resetAppStatics();
    // 離線時 run() 會在碰到任何連線之前就回 Failed，
    // 測試因此完全不需要網路；TaskUiDelegate 預設是 Noop，也不會彈框。
    ConnectivityProbe.instance = FakeConnectivityProbe(online: false);
    repo = _CountingMoodleRepository();
    MoodleRepository.instance = repo;
    ntustRepo = _CountingNtustRepository();
    NtustRepository.instance = ntustRepo;
    dataController = CourseDataController('AT1001');
    detailController = CourseDetailController(
        courseId: 'AT1001', semester: SemesterJson(year: '113', semester: '1'));
    memberController = CourseMemberController(courseId: 'AT1001');
    AuthSession.instance = AppAuthSession();
    // 離線失敗會畫 ErrorPage，而 ErrorPage.loginBtn 在未登入時會取
    // Get.context!.width——沒有 GetMaterialApp 就是 null 直接爆。
    // 這裡塞一組憑證讓它走 SizedBox 分支，測的東西才不會被那件事蓋掉。
    // 帳號與密碼要**成對**塞：AuthSession.isSignedIn 兩者都要非空。
    Model.instance.setAccount('B10000000');
    Model.instance.setPassword('not-a-real-password');
  });

  tearDown(() {
    MoodleRepository.instance = MoodleRepository();
    NtustRepository.instance = NtustRepository();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
  });

  /// 把待測頁面掛在一個可以由外部 setState 的 StatefulBuilder 底下。
  ///
  /// 不能用「換 MaterialApp 的 theme」來製造 rebuild：`home` 只在路由第一次
  /// 產生時被讀取，之後改 theme 不會讓這棵子樹重建，測試會假性通過。
  /// 上層 setState 才是真的會重跑 build()。
  Future<VoidCallback> pumpUnderRebuildableParent(
    WidgetTester tester,
    Widget Function() child,
  ) async {
    late StateSetter rebuildParent;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuildParent = setState;
            return child();
          },
        ),
      ),
    );
    return () => rebuildParent(() {});
  }

  /// 課程分頁那三頁只用到 `courseInfo.main.course.id`，其餘欄位走預設值即可。
  CourseInfoJson courseInfoOf(String id) => CourseInfoJson(
        main: CourseMainInfoJson(course: CourseMainJson(id: id)),
      );

  testWidgets('SubSystemPage 在上層 setState 之後不會重打一次 API', (tester) async {
    final rebuild = await pumpUnderRebuildableParent(
      tester,
      () => SubSystemPage(
        errorBuilder: (message) => Text(message),
        openWebView: (title, url) async {},
      ),
    );
    await tester.pumpAndSettle();
    expect(ntustRepo.calls, 1);

    rebuild();
    await tester.pumpAndSettle();

    expect(ntustRepo.calls, 1, reason: 'rebuild 之後又打了一次 API，代表請求跑回 build() 裡了');
  });

  testWidgets('CourseInfoPage 在上層 setState 之後不會重打一次 API', (tester) async {
    await detailController.loadInfo();
    final rebuild = await pumpUnderRebuildableParent(
      tester,
      () => CourseInfoPage(
        controller: detailController,
        errorBuilder: (m) => Text(m),
      ),
    );
    await tester.pumpAndSettle();
    expect(ntustRepo.calls, 1);

    rebuild();
    await tester.pumpAndSettle();

    expect(ntustRepo.calls, 1, reason: 'rebuild 之後又打了一次 API，代表請求跑回 build() 裡了');
  });

  testWidgets('CourseDirectoryPage 在上層 setState 之後不會重打一次 API', (tester) async {
    await dataController.loadDirectory();
    final rebuild = await pumpUnderRebuildableParent(
      tester,
      () => CourseDirectoryPage(courseInfoOf('AT1001'),
          controller: dataController),
    );
    await tester.pumpAndSettle();
    expect(repo.calls, 1);

    rebuild();
    await tester.pumpAndSettle();

    expect(repo.calls, 1, reason: 'rebuild 之後又打了一次 API，代表請求跑回 build() 裡了');
  });

  testWidgets('CourseAnnouncementPage 在上層 setState 之後不會重打一次 API',
      (tester) async {
    await dataController.loadAnnouncements();
    final rebuild = await pumpUnderRebuildableParent(
      tester,
      () => CourseAnnouncementPage(
        courseInfoOf('AT1001'),
        controller: dataController,
        errorBuilder: (m) => Text(m),
        openWebView: (t, u) async {},
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.calls, 1);

    rebuild();
    await tester.pumpAndSettle();

    expect(repo.calls, 1, reason: 'rebuild 之後又打了一次 API，代表請求跑回 build() 裡了');
  });

  testWidgets('CourseScorePage 在上層 setState 之後不會重打一次 API', (tester) async {
    await dataController.loadScore();
    final rebuild = await pumpUnderRebuildableParent(
      tester,
      () => CourseScorePage(courseInfoOf('AT1001'), controller: dataController),
    );
    await tester.pumpAndSettle();
    expect(repo.calls, 1);

    rebuild();
    await tester.pumpAndSettle();

    expect(repo.calls, 1, reason: 'rebuild 之後又打了一次 API，代表請求跑回 build() 裡了');
  });

  testWidgets('CourseMemberPage 在上層 setState 之後不會重打一次 API', (tester) async {
    // 這一頁自己在 initState 發請求——課程頁不再順手打那支慢的名單 API，
    // 只有真的進到這一頁的人才付那幾秒。所以這裡不預先 load：pump 完之後
    // 剛好一次，rebuild 之後還是一次。
    final rebuild = await pumpUnderRebuildableParent(
      tester,
      // 這個 widget 拿得到 const 也不該寫 const：const widget 在 rebuild 時會
      // 拿到同一個實例，Element.updateChild 會整段短路、根本不重跑 build()，
      // 測試就會假性通過。
      () => CourseMemberPage(
        controller: memberController,
        courseName: '微積分（一）',
        knownMemberCount: 3,
        errorBuilder: (message, onRetry) => Text(message),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.calls, 1);

    rebuild();
    await tester.pumpAndSettle();

    expect(repo.calls, 1, reason: 'rebuild 之後又打了一次 API，代表請求跑回 build() 裡了');
  });

  /// 畫面必須每次 build 現算，不可以當成請求的 side effect 存進 State 欄位：
  /// 提示條的訊息與搜尋框的 hint 都來自 R.current，只填一次的話切語言、切主題
  /// 後畫面會停在第一次的樣子。
  testWidgets('CourseMemberPage 切換語言後畫面文字要跟著更新（畫面必須每次 build 現算）',
      (tester) async {
    // 這一則要走真的 repository：驗的是「離線 + 有快取時畫面畫得出來，而且
    // 換語言會重畫」。setUp 裝的計數假件回的是 Ok，用它就測不到 Stale。
    MoodleRepository.instance = MoodleRepository();
    // 離線 + 有快取時 run() 回 Stale，資料由 CacheStore 讀出來，
    // 因此整段測試不需要網路。
    await CacheStore.instance.write<List<MoodleCoreEnrolGetUsers>>(
      CacheKey<List<MoodleCoreEnrolGetUsers>>(
        'cache_moodle_member',
        'AT1001',
        decode: (json) => (json as List)
            .map((e) => MoodleCoreEnrolGetUsers.fromJson(e))
            .toList(),
      ),
      [MoodleCoreEnrolGetUsers(id: 1, fullName: 'B10000000 @ 王小明')],
    );

    // 這個測試會改動 process 級的 Intl.defaultLocale，收尾要還原，
    // 否則同檔案後面的測試會拿到英文語系。
    addTearDown(loadTestL10n);

    final rebuild = await pumpUnderRebuildableParent(
      tester,
      () => CourseMemberPage(
        controller: memberController,
        courseName: '微積分（一）',
        knownMemberCount: 1,
        errorBuilder: (message, onRetry) => Text(message),
      ),
    );
    await tester.pumpAndSettle();

    // 名單畫得出來，而且上面掛著「你看到的是舊資料」的提示條。
    expect(find.text('王小明'), findsOneWidget);
    expect(find.text(S.current.networkError), findsOneWidget);

    await loadTestL10n(const Locale('en'));
    rebuild();
    await tester.pumpAndSettle();

    expect(
      find.text(S.current.networkError),
      findsOneWidget,
      reason: '畫面還是第一次建立時的那一份，語言換了卻沒跟著換',
    );
  });
}
