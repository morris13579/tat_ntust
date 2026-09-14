import 'dart:ui' show Locale;

import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/score/score_json.dart';
import 'package:flutter_app/src/repository/ntust_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/interactive_login_gateway.dart';
import 'package:flutter_app/src/store/credentials_store.dart';
import 'package:flutter_app/src/store/moodle_session_store.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/language_utils.dart';

/// 原生版取資料的入口。由 `core_main.dart` 安裝。
///
/// 這一層刻意很薄：只做「呼叫 repository」與「把結果翻成邊界型別」兩件事。
/// 不走 `CourseModel`——那一層會 `MyToast`、會 `TaskUiDelegate.chooseSemester`，
/// 那些在原生版是 Swift 的責任（走 `TatCoreUiApi`）。
class CoreBridge implements TatCoreApi {
  const CoreBridge();

  static void install() => TatCoreApi.setUp(const CoreBridge());

  @override
  CoreStatus status() {
    final credentials = CredentialsStore.instance;
    return CoreStatus(
      credentials: credentials.lastResult.name,
      account: credentials.account,
      // 記憶體那一份就夠：coreMain 啟動時已經把磁碟上的 token 還原過。
      hasMoodleToken: MoodleSessionStore.instance.token != null,
      courseTableCount: Model.instance.getCourseTableList().length,
      locale: Model.instance.getOtherSetting().lang,
    );
  }

  @override
  Future<CourseTableResult> getCourseTable(String? semester) async {
    final studentId = Model.instance.getAccount();

    final SemesterJson? target;
    if (semester != null) {
      target = _parseSemester(semester);
      if (target == null) {
        return CourseTableFailed(
          reason: CoreFailureFetchFailed(detail: '學期格式不是 "115-1"：$semester'),
        );
      }
    } else {
      final list = await NtustRepository.instance.getSemesterList();
      // **失敗要把「它的」原因原樣往上送，不要自己編一個。**
      // 學期清單拿不到最常見的原因是沒登入，而 NotSignedIn 是不可重試的
      // ——換成 FetchFailed 的話畫面會給一顆按了也沒用的「重試」，
      // 而不是一顆登入按鈕。這正是 Result 三態存在的理由。
      if (list case Failed<List<SemesterJson>>(:final reason)) {
        return CourseTableFailed(reason: _toFailure(reason));
      }
      // **要用回傳的清單，不要讀 Model。** `getSemesterList()` 只把結果放進
      // `Result` 就回來了，寫進 `Model` 的是 Flutter 版的 `CourseModel`
      // ——原生版沒有那一層。實測過：成績抓得到六個學期，但 Model 是空的，
      // 於是畫面顯示「學期清單是空的」。
      final semesters = list.dataOrNull ?? const <SemesterJson>[];
      if (semesters.isEmpty) {
        return CourseTableFailed(
          reason: CoreFailureFetchFailed(detail: '學期清單是空的'),
        );
      }
      target = semesters.first;
    }

    final result =
        await NtustRepository.instance.getCourseTable(studentId, target);
    // Dart 這一側的 switch 是窮盡的（Result 與 FailureReason 都是 sealed），
    // 少一個分支編譯不過。Swift 那一側沒有這個保證——Pigeon 把 sealed 產生成
    // protocol，所以翻譯放在這裡而不是 Swift。
    return switch (result) {
      Ok<CourseTableJson>(:final data) =>
        CourseTableOk(data: _toCourseTable(data)),
      Stale<CourseTableJson>(:final data, :final reason) => CourseTableStale(
          data: _toCourseTable(data),
          reason: _toFailure(reason),
        ),
      Failed<CourseTableJson>(:final reason) =>
        CourseTableFailed(reason: _toFailure(reason)),
    };
  }

  @override
  Future<ScoreResult> getScore() async {
    final result = await NtustRepository.instance.getScoreRank();
    return switch (result) {
      Ok<ScoreRankJson>(:final data) => ScoreOk(data: _toSummary(data)),
      Stale<ScoreRankJson>(:final data, :final reason) => ScoreStale(
          data: _toSummary(data),
          reason: _toFailure(reason),
        ),
      Failed<ScoreRankJson>(:final reason) =>
        ScoreFailed(reason: _toFailure(reason)),
    };
  }

  @override
  AppLaunch launch() {
    final locale = LanguageUtils.savedLocale();
    return AppLaunch(
      account: Model.instance.getAccount(),
      language: locale == null ? null : _toAppLanguage(locale),
    );
  }

  @override
  Future<bool> needsPrivacyAgreement() async =>
      !(await Model.instance.getAgreeContributor());

  @override
  Future<void> agreePrivacyPolicy() => Model.instance.setAgreeContributor(true);

  @override
  Future<void> setLanguage(AppLanguage language) =>
      LanguageUtils.loadWithoutUi(LanguageUtils.getSupportLocale[switch (language) {
        AppLanguage.en => LangEnum.en.index,
        AppLanguage.zhTW => LangEnum.zh.index,
      }]);

  AppLanguage _toAppLanguage(Locale locale) =>
      LanguageUtils.getSupportLocale.indexOf(locale) == LangEnum.en.index
          ? AppLanguage.en
          : AppLanguage.zhTW;

  @override
  SavedCredentials credentials() => SavedCredentials(
        account: Model.instance.getAccount(),
        password: Model.instance.getPassword(),
      );

  @override
  Future<void> saveCredentials(String account, String password) async {
    Model.instance.setAccount(account);
    Model.instance.setPassword(password);
    // 上面兩支只改記憶體。
    await Model.instance.saveUserData();
  }

  @override
  Future<String> debugInteractiveSignIn(bool moodle) async {
    final account = Model.instance.getAccount();
    final password = Model.instance.getPassword();
    final gateway = InteractiveLoginGateway.instance;
    if (moodle) {
      final token =
          await gateway.signInMoodle(account: account, password: password);
      return token == null ? 'null' : 'token ${token.token.length} 字';
    }
    final result =
        await gateway.signInNtust(account: account, password: password);
    return result == null
        ? 'null（使用者取消）'
        : '${result.status.name} ${result.message ?? ''}';
  }

  ScoreSummary _toSummary(ScoreRankJson score) {
    final latest = score.info.isEmpty ? null : score.info.first.semester;
    return ScoreSummary(
      semesterCount: score.info.length,
      itemCount:
          score.info.fold(0, (sum, s) => sum + s.item.length),
      latestSemester:
          latest == null ? null : '${latest.year}-${latest.semester}',
    );
  }

  /// `"115-1"` → `SemesterJson`，格式不對回 null。
  SemesterJson? _parseSemester(String semester) {
    final parts = semester.split('-');
    if (parts.length != 2) return null;
    return SemesterJson(year: parts[0], semester: parts[1]);
  }

  CoreFailure _toFailure(FailureReason reason) => switch (reason) {
        Offline() => CoreFailureOffline(),
        NotSignedIn() => CoreFailureNotSignedIn(),
        LoginFailed(:final detail) => CoreFailureLoginFailed(detail: detail),
        FetchFailed(:final detail) => CoreFailureFetchFailed(detail: detail),
        UnsupportedCourse() => CoreFailureUnsupportedCourse(),
      };

  /// `Map<Day, Map<SectionNumber, CourseInfoJson>>` 攤平成 cell 清單。
  CourseTable _toCourseTable(CourseTableJson table) {
    final cells = <CourseCell>[];
    table.courseInfoMap.forEach((day, sections) {
      sections.forEach((section, info) {
        if (info.isEmpty) return;
        final main = info.main;
        cells.add(CourseCell(
          day: day.name,
          section: section.name,
          courseId: main.course.id,
          courseName: main.course.name,
          classroom: main.classroom.isEmpty ? null : main.classroom.first.name,
          teacher: main.teacher.isEmpty ? null : main.teacher.first.name,
        ));
      });
    });
    return CourseTable(
      studentId: table.studentId,
      semester: '${table.courseSemester.year}-${table.courseSemester.semester}',
      cells: cells,
    );
  }
}
