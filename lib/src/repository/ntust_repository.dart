import 'package:flutter/foundation.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/repository/retry.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/connector/classroom_connector.dart';
import 'package:flutter_app/src/connector/course_connector.dart';
import 'package:flutter_app/src/model/classroom/classroom_option.dart';
import 'package:flutter_app/src/model/classroom/classroom_usage_json.dart';
import 'package:flutter_app/src/model/course/course_query_filter.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/store/cache_store.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/connector/ntust_connector.dart';
import 'package:flutter_app/src/connector/score_connector.dart';
import 'package:flutter_app/src/model/ntust/ap_tree_json.dart';
import 'package:flutter_app/src/model/score/score_json.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/repository/run.dart';
import 'package:flutter_app/src/util/language_utils.dart';

/// NTUST 那一側的資料來源。
///
/// **分界是系統而不是領域**，與 [MoodleRepository] 對稱：這裡是所有用 SSO
/// cookie 取得、或走 NTUST 公開 API 的東西（成績、資訊系統、課表、課程查詢、
/// 學期清單）；那裡是所有用 wsToken 取得的東西。App 只有這兩個真正的憑證。
///
/// 別和 `lib/src/store/` 底下那些 `*Repository`／`ScoreStore` 混為一談，
/// 那些是持久化，職責不同。
class NtustRepository {
  NtustRepository();

  static NtustRepository instance = NtustRepository();

  /// 歷年成績與排名。
  ///
  /// **沒有快取參數。** 成績的持久化由 `lib/src/store/score_store.dart`
  /// 負責，而且那份資料不只成績頁在用——課表對 urlPath 為空的歷史學期是靠
  /// 它反查課號的。把它同時放進 CacheStore 會有兩份會漂移的副本。
  ///
  /// 所以這裡 `cache` 留空：失敗就是 [Failed]，由呼叫端決定要不要沿用
  /// 硬碟上既有的成績（`ScorePageController` 本來就是那樣做的）。
  Future<Result<ScoreRankJson>> getScoreRank() => run<ScoreRankJson>(
        requires: const {SystemId.ntustSso},
        fetch: ScoreConnector.getScoreRank,
        // 沒有 progressMessage：成績頁自己有 ScoreUIState.loading。
        errorMessage: R.current.getScoreError,
        debugLabel: 'scoreRank',
      );

  /// 教室查詢的校區與大樓選單。
  ///
  /// **沒有快取**，與 [getSubSystemTree] 同一個理由：這份清單很小、變動極少，
  /// 加上去只是多一個會過期的副本。
  ///
  /// 特別不能用 `cacheFirst`：它命中就永遠不再打網路，而這份清單**是會變的**
  /// ——課務組把一棟大樓納進借用系統時（`MA` 與 `RB` 現在就是有選項、沒教室
  /// 的狀態），使用者會永遠看不到那一棟，而且只有登出才清得掉。
  ///
  /// 取得它要一次交握加上「每個校區各一次 postback」，大約三秒。那是一次
  /// 冷啟動的成本，[ClassroomConnector] 留著的頁面狀態會讓同一輪的後續查詢
  /// 只剩一個 postback。
  Future<Result<List<ClassroomCampusJson>>> getClassroomCampuses() =>
      run<List<ClassroomCampusJson>>(
        requires: const {SystemId.ntustSso},
        fetch: ClassroomConnector.getCampuses,
        errorMessage: R.current.somethingError,
        debugLabel: 'classroomCampuses',
      );

  /// 某一天、某個校區（[buildingCode] 為 null 就是整個校區）的教室使用情形。
  ///
  /// 快取的 id 帶齊三個查詢條件，不同的日期與大樓各自留一份，翻回去看過的
  /// 那一天不必再打網路。
  ///
  /// 沒有 `progressMessage`：查詢頁自己用 `ResultView` 畫載入狀態，再疊一個
  /// 全螢幕遮罩會變成兩個轉圈。
  Future<Result<ClassroomUsageJson>> getClassroomUsage({
    required String campusCode,
    required DateTime date,
    String? buildingCode,
  }) =>
      run<ClassroomUsageJson>(
        requires: const {SystemId.ntustSso},
        cache: classroomUsageCacheKey(
            campusCode: campusCode, date: date, buildingCode: buildingCode),
        fetch: () => ClassroomConnector.getUsage(
            campusCode: campusCode,
            date: date,
            buildingCode: buildingCode),
        errorMessage: R.current.somethingError,
        debugLabel: 'classroomUsage',
      );

  @visibleForTesting
  static CacheKey<ClassroomUsageJson> classroomUsageCacheKey({
    required String campusCode,
    required DateTime date,
    String? buildingCode,
  }) {
    final day = "${date.year.toString().padLeft(4, '0')}"
        "${date.month.toString().padLeft(2, '0')}"
        "${date.day.toString().padLeft(2, '0')}";
    return CacheKey<ClassroomUsageJson>(
      "cache_classroom_usage",
      "$campusCode-${buildingCode ?? 'all'}-$day",
      decode: (json) => ClassroomUsageJson.fromJson(json),
    );
  }

  /// 資訊系統的功能樹。
  ///
  /// 沒有快取：這份清單很小、變動極少，加上去只是多一個會過期的副本。
  Future<Result<List<APTreeJson>>> getSubSystemTree() => run<List<APTreeJson>>(
        requires: const {SystemId.ntustSso},
        fetch: NTUSTConnector.getSubSystem,
        errorMessage: R.current.somethingError,
        debugLabel: 'subSystemTree',
      );

  /// 課程查詢。
  ///
  /// **`requires` 是空的。** 它打的是 `querycourse/api/courses`，一個免憑證的
  /// 公開 API。加上登入需求只會讓還沒登入的使用者一查課就被彈登入頁。
  Future<Result<List<CourseMainInfoJson>>> searchCourse(
          SemesterJson semester, CourseQueryFilter filter) =>
      run<List<CourseMainInfoJson>>(
        requires: const {},
        fetch: () => CourseConnector.searchCourse(semester, filter),
        // 不開進度框：搜尋頁自己就有載入狀態，再疊一個全螢幕遮罩會變成兩個
        // 轉圈，而且遮罩擋住輸入框時看起來像整頁卡死。
        retry: RetryPolicy.none,
        errorMessage: R.current.getCourseError,
        debugLabel: 'searchCourse',
      );

  /// 課程詳細資訊的快取位址。
  ///
  /// **語言是 key 的一部分**：那支 API 依語系回不同字串，語言不進 key 的話，
  /// 切換語言後這一頁會一直讀到舊語系的快取而且不會過期。
  @visibleForTesting
  static CacheKey<CourseExtraInfoJson> courseExtraCacheKey(
          String courseId, SemesterJson semester) =>
      CacheKey<CourseExtraInfoJson>(
        "cache_course_extra",
        "$courseId-${semester.year}${semester.semester}"
            "-${LanguageUtils.getLangIndex().name}",
        decode: (json) => CourseExtraInfoJson.fromJson(json),
      );

  /// 單一課程的詳細資訊。
  ///
  /// `requires` 同樣是空的——`querycourse/api/coursedetials` 也是公開 API。
  Future<Result<CourseExtraInfoJson>> getCourseExtraInfo(
          String courseId, SemesterJson semester) =>
      run<CourseExtraInfoJson>(
        requires: const {},
        cache: courseExtraCacheKey(courseId, semester),
        fetch: () => CourseConnector.getCourseExtraInfo(courseId, semester),
        // 沒有 progressMessage：course_info_page 用 ResultView，它自己會畫。
        errorMessage: R.current.getCourseDetailError,
        debugLabel: 'courseExtraInfo',
      );

  /// 某個學期的課表。
  ///
  /// **`requires` 只有 `ntustSso`，不要加回選課系統的探針。**
  /// `CourseConnector.login()` 只是 GET 首頁、看 HTML 裡有沒有 `DoLoginCB`；
  /// 它想確認的事（SSO cookie 在那台主機上有效）正是 `run()` 的重試迴圈已經
  /// 在做的：抓取失敗就 `invalidate` 再試一次。
  ///
  /// 沒有 `cache:`：課表的持久化是 `Model.addCourseTable`（course_table_list），
  /// 同時放進 CacheStore 會有兩份會漂移的副本。
  Future<Result<CourseTableJson>> getCourseTable(
          String studentId, SemesterJson semester) =>
      run<CourseTableJson>(
        requires: const {SystemId.ntustSso},
        fetch: () => _fetchCourseTable(studentId, semester),
        progressMessage: R.current.getCourse,
        errorMessage: R.current.getCourseError,
        debugLabel: 'courseTable',
      );

  /// querycourse 支援的學期，由新到舊。
  ///
  /// 模擬排課用的是這一份而不是 `getSemesterList`：後者要有成績或選課紀錄才
  /// 生得出學期，新學期在選課開始前根本不在裡面。免憑證，沒登入也查得到。
  Future<List<SemesterJson>> getQueryCourseSemesters() =>
      CourseConnector.getCourseSemesterList();

  /// 掃進來的課表要補的課名與教室。
  ///
  /// QR 只帶課號與上課時間，格子離線就畫得出來；這一支負責把課名、教室、老師
  /// 補上。`requires` 是空的——querycourse 免憑證，沒登入的人也要能完成匯入，
  /// 這對「同學傳一張 QR 給還沒用過 TAT 的人」是關鍵。
  ///
  /// 查不到就回空清單而不是失敗：對方的課表可能有這學期查不到的課，那不該讓
  /// 整份匯入失敗——時間格子本來就已經對了。
  Future<List<CourseMainInfoJson>> restoreSharedCourses(
    SemesterJson semester,
    List<String> courseIds, {
    void Function(int done, int total)? onProgress,
  }) async {
    var done = 0;
    final lookups = await lookupSharedCourses(
      semester,
      courseIds,
      onResolved: (_) => onProgress?.call(++done, courseIds.length),
    );
    return [for (final lookup in lookups) ...lookup.courses];
  }

  /// 逐門查課，查完一門回報一門。
  ///
  /// 與 [restoreSharedCourses] 是同一條路，差別只在呼叫端拿得到「這一門是查
  /// 不到還是查不動」，而且不必等全部查完才有東西可畫。
  Future<List<SharedCourseLookup>> lookupSharedCourses(
    SemesterJson semester,
    List<String> courseIds, {
    void Function(SharedCourseLookup lookup)? onResolved,
    bool Function()? isCancelled,
  }) async {
    if (courseIds.isEmpty) return [];
    // 一門課一個請求，而且是循序的。十門課排成一列就是十次來回，所以開四條
    // ——再多就是拿學校主機當壓測目標。
    const concurrency = 4;
    final result = <SharedCourseLookup>[];
    for (var i = 0; i < courseIds.length; i += concurrency) {
      // 呼叫端已經離開就不要再開下一批：使用者什麼都看不到，主機照樣挨打。
      if (isCancelled?.call() ?? false) break;
      final batch = courseIds.skip(i).take(concurrency);
      final fetched = await Future.wait(batch.map((id) async {
        try {
          final value = await CourseConnector.getCourseMainInfoListByCourseId(
              semester, [id]);
          // null 是連不上；非 null 但空清單是這學期查無此課。
          return value == null
              ? SharedCourseLookup(id: id, courses: const [], failed: true)
              : SharedCourseLookup(id: id, courses: value.json, failed: false);
        } catch (e, stack) {
          Log.eWithStack(e.toString(), stack);
          return SharedCourseLookup(id: id, courses: const [], failed: true);
        }
      }));
      for (final lookup in fetched) {
        result.add(lookup);
        onResolved?.call(lookup);
      }
    }
    return result;
  }

  /// 課表一律以課號向課程查詢 API 逐門查回來。
  ///
  /// **不要為 `semester.urlPath` 非空的學期加回「抓選課系統課表網頁」那條
  /// 路。** urlPath 會跟著課表一起存進 SharedPreferences，所以在學校換系統
  /// 之前存過課表的使用者，按重新整理就會被送進一個為舊版 HTML 寫死索引
  /// （table[2]、table[3]、text-success[7]）的解析器，丟 RangeError、回 null、
  /// 課表載入失敗。
  Future<CourseTableJson?> _fetchCourseTable(
      String studentId, SemesterJson semester) async {
    final courseIds = await _courseIdsFor(semester);
    // null 或空都算失敗。用空清單去查課程 API 會得到一張零課程的課表，
    // 下面的 addCourseTable 會拿它覆蓋掉該學期原本正確的快取。
    if (courseIds == null || courseIds.isEmpty) return null;
    final value = await CourseConnector.getCourseMainInfoListByCourseId(
        semester, courseIds);
    if (value == null) return null;

    final courseTable = CourseTableJson()
      ..courseSemester = semester
      ..studentId = studentId
      ..studentName = value.studentName;
    for (final courseMainInfo in value.json) {
      final courseInfo = CourseInfoJson();
      var add = false;
      for (int i = 0; i < 7; i++) {
        final day = Day.values[i];
        final time = courseMainInfo.course.time[day] ?? "";
        courseInfo.main = courseMainInfo;
        add |= courseTable.setCourseDetailByTimeString(day, time, courseInfo);
      }
      if (!add) {
        // 代表課程沒有時間
        courseTable.setCourseDetailByTime(
            Day.unKnown, SectionNumber.t_UnKnown, courseInfo);
      }
    }
    if (studentId == Model.instance.getAccount()) {
      // 只儲存自己的課表
      Model.instance.addCourseTable(courseTable);
      await Model.instance.saveCourseTableList();
    }
    return courseTable;
  }

  /// 歷史學期（`urlPath` 為空）要靠課號反查課表。課號優先取自成績快取，
  /// 取不到才改問 Moodle。
  ///
  /// Moodle 那條是 **best-effort**：`tryEnsure` 失敗不拋，只是回 null 讓
  /// 呼叫端走課表頁本來就有的錯誤框。也刻意放在成績快取沒中之後才做——
  /// 用 `run()` 的 `optional` 會在每一次抓課表時都先確保 Moodle 已登入，
  /// 即使根本用不到。
  Future<List<String>?> _courseIdsFor(SemesterJson semester) async {
    final fromScore =
        await Model.instance.getScore().getCourseIdBySemester(semester);
    if (fromScore.where((id) => id.toUpperCase() != "TC1010301").isNotEmpty) {
      return fromScore;
    }
    await AuthSession.instance.tryEnsure(SystemId.moodleWebApi);
    final ids = await MoodleWebApiConnector.getCourseIds(semester);
    return (ids == null || ids.isEmpty) ? null : ids;
  }

  /// 學期選單的內容。
  ///
  /// **兩個來源各自回答不同的問題，不要「簡化」成一次請求：**
  /// - `ScoreConnector.getScoreRank()`：**這位學生修過哪些學期**——有修課才有
  ///   成績。這是唯一能回答這件事的來源。拿不到時退回硬碟上那一份。
  /// - `MoodleWebApiConnector.getCurrentSemester()`：當前學期。成績系統只知道
  ///   已經有成績的學期，開學初的當前學期要靠這裡補。
  ///
  /// **不要加回 `CourseConnector.getCourseSemester()`**：App 對 courseselection
  /// 的請求全部停在 ssoam2 的登入表單上，OIDC 交握從來沒完成過，實機量到它
  /// 每次貢獻 0 個學期，只換來三個請求與約 700ms。
  ///
  /// `querycourse/api/semestersinfo` 看起來是完美替代品，但它免憑證，回的是
  /// 「系統有哪些學期」而不是「這位學生有哪些」——113 年入學的人會選得到 112。
  ///
  /// `retry: none`：來源都失敗時不彈重試框，回 [Failed] 讓呼叫端彈手動選
  /// 學期的對話框（那是 `course_model` 的事，見 `manualSemesterDialog`）。
  /// [background] 給啟動後的預載用：不開進度框、不開登入頁，失敗就安靜失敗。
  Future<Result<List<SemesterJson>>> getSemesterList(
      {bool background = false}) async {
    final result = await run<SemesterListFetch>(
      requires: const {SystemId.ntustSso},
      retry: RetryPolicy.none,
      background: background,
      // background 要傳進去：run() 只把它套在自己那一次 ensure 上，而
      // _fetchSemesterList 裡面還有一次 Moodle 的 tryEnsure。
      fetch: () => _fetchSemesterList(background: background),
      progressMessage: R.current.getCourseSemester,
      errorMessage: R.current.getCourseError,
      debugLabel: 'semesterList',
    );
    return switch (result) {
      // 抓到了，但歷年那個來源一個學期都沒給——清單裡只剩當前學期。
      // 必須是 [Stale] 而不是 [Ok]，呼叫端才不會把這份殘缺清單當完整答案
      // 快取起來，害下拉選單從此只剩一個選項。
      Ok(:final data) when !data.hasHistory =>
        Stale(data.semesters, FetchFailed(R.current.getCourseError)),
      Ok(:final data) => Ok(data.semesters),
      // 這條走不到（沒有傳 cache，run() 就產不出 Stale），但 Result 是
      // sealed，少一支編不過。
      Stale(:final data, :final reason) => Stale(data.semesters, reason),
      Failed(:final reason) => Failed<List<SemesterJson>>(reason),
    };
  }

  Future<SemesterListFetch?> _fetchSemesterList(
      {bool background = false}) async {
    // null 代表「一個來源都沒給出學期」，呼叫端才會走到手動選學期的對話框。
    // 所以這裡不要先寫成 `[]`——空清單與「完全沒有答案」在上層是兩件事。
    List<SemesterJson>? value;

    // 成績與 moodle 是兩個互相獨立的來源，所以刻意拆成兩個 try：共用一個
    // try 的話，成績這段一拋（getScoreRank() 逾時或被導到登入頁時會回 null）
    // 就會連「從 moodle 補當前學期」與排序一起跳過，卻仍然回成功，課表頁
    // 拿到一份未排序、又缺當前學期的清單。
    ScoreRankJson? history;
    var liveScore = false;
    try {
      final scoreRank = await ScoreConnector.getScoreRank();
      // 回 null 代表「這次拿不到成績」，不是「成績是空的」，
      // 不可以寫進 Model 把硬碟上既有的成績蓋掉。
      if (scoreRank != null) {
        Model.instance.setScore(scoreRank);
        history = scoreRank;
        liveScore = true;
        // 各自 try：寫入失敗不該讓已經拿到的學期清單整段消失。
        try {
          await Model.instance.saveScore();
        } catch (e) {
          Log.d(e);
        }
      }
    } catch (e) {
      Log.d(e);
    }

    // 這次拿不到成績時退回硬碟上那一份：修過哪些學期不會變，上一次存下來的
    // 答案今天仍然正確。少了這個回退，成績系統偶爾一次逾時（SSO 剛登入、
    // 子系統 session 還沒建立時很常見）就會產出「只有當前學期」的清單，而
    // 呼叫端的快取閘門只看清單空不空，那份殘缺清單會被當成最終答案留下來。
    final scoreSource = liveScore
        ? 'live'
        : (Model.instance.getScore().info.isEmpty ? 'none' : 'cache');
    history ??= Model.instance.getScore();
    if (history.info.isNotEmpty) {
      value ??= [];
      for (final i in history.info) {
        if (!value.contains(i.semester)) value.add(i.semester);
      }
    }

    // 從 moodle 補當前學期。best-effort：這一段失敗不影響上面的結果。
    try {
      await AuthSession.instance
          .tryEnsure(SystemId.moodleWebApi, interactive: !background);
      final currentSemester = await MoodleWebApiConnector.getCurrentSemester();
      if (currentSemester != null) {
        // value 只在「所有來源都沒有資料」時才會維持 null，呼叫端才會走到
        // 手動選學期的對話框；這裡不要無條件 `value ??= []`，否則那個
        // fallback 會被吃掉，變成回傳一份空清單。
        value ??= [];
        if (value
            .where((e) =>
                e.year == currentSemester.year &&
                e.semester == currentSemester.semester)
            .isEmpty) {
          value.add(currentSemester);
        }
      }
    } catch (e) {
      Log.d(e);
    }

    value?.sort((a, b) {
      final yearA = int.tryParse(a.year) ?? 0;
      final yearB = int.tryParse(b.year) ?? 0;
      final semesterA = int.tryParse(a.semester) ?? 0;
      final semesterB = int.tryParse(b.semester) ?? 0;
      final yearCompare = yearB.compareTo(yearA);
      return yearCompare != 0 ? yearCompare : semesterB.compareTo(semesterA);
    });
    // 學期清單只剩一個時，唯一要問的是「哪個來源沒答」。這一行就是答案：
    // 歷年學期**完全**靠 score 一個來源，它沒答就只剩 moodle 給的當前學期。
    Log.d('[semester-list] score=$scoreSource '
        'history=${history.info.length} total=${value?.length}');
    if (value == null) return null;
    return SemesterListFetch(value, hasHistory: history.info.isNotEmpty);
  }
}

/// [NtustRepository.getSemesterList] 內部用的中繼結果。
///
/// [hasHistory] 是「這份清單完不完整」唯一的依據：歷年學期只有成績系統
/// 答得出來，它沒答的話清單裡就只有當前學期。
class SemesterListFetch {
  final List<SemesterJson> semesters;

  /// 歷年來源（成績系統，或硬碟上快取的那一份成績）有沒有貢獻學期。
  final bool hasHistory;

  const SemesterListFetch(this.semesters, {required this.hasHistory});
}

/// 一個課號查回來的結果。
///
/// 「查不到」跟「查不動」不是同一件事：前者是這學期真的沒有這門課，後者只是
/// 這一次沒連上。混在一起的話，離線時整份課表都會被說成查無此課。
class SharedCourseLookup {
  const SharedCourseLookup({
    required this.id,
    required this.courses,
    required this.failed,
  });

  final String id;

  /// API 回的每一列。同一個課號開在不同教室會有多列。
  final List<CourseMainInfoJson> courses;

  /// 這一次請求根本沒打成功。
  final bool failed;

  /// 這學期查無此課。查不動不算。
  bool get notFound => !failed && courses.isEmpty;
}
