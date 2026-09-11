import 'package:flutter_app/src/controller/course_table/course_model.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/repository/ntust_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 學期下拉選單「只剩一個學期」那個 bug 的迴歸測試。
///
/// 歷年學期只有成績系統答得出來。它一次沒答（逾時、SSO 剛登入子系統 session
/// 還沒建立）就會產出一份「只有當前學期」的清單，而那份清單非空——所以
/// [CourseModel.getSemesterList] 的快取閘門不能只問「清單是不是空的」，
/// 否則殘缺的清單永遠不會被重抓。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => loadTestL10n());

  late _FakeNtustRepository repo;

  SemesterJson sem(String year, String semester) =>
      SemesterJson(year: year, semester: semester);

  final complete = [sem('115', '1'), sem('114', '2'), sem('114', '1')];
  final degraded = [sem('115', '1')];

  setUp(() {
    resetAppStatics();
    repo = _FakeNtustRepository();
    NtustRepository.instance = repo;
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
  });

  tearDown(() {
    NtustRepository.instance = NtustRepository();
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
  });

  test('殘缺的清單會在使用者打開下拉選單時重抓——這就是回報的那個 bug', () async {
    // 第一次只拿到當前學期（成績系統沒答），第二次拿到完整的。
    repo.results = [
      Stale(degraded, const FetchFailed('成績系統逾時')),
      Ok(complete),
    ];
    final model = CourseModel();

    final first = await model.getSemesterList(refreshIfIncomplete: true);
    expect(first.length, 1, reason: '第一次就只有這麼多，這一步不是 bug');

    final second = await model.getSemesterList(refreshIfIncomplete: true);
    expect(second.length, 3, reason: '再打開一次選單應該重抓，而不是回一樣的殘缺清單');
    expect(repo.calls, 2);
  });

  test('完整的清單只抓一次', () async {
    repo.results = [Ok(complete)];
    final model = CourseModel();

    await model.getSemesterList(refreshIfIncomplete: true);
    final second = await model.getSemesterList(refreshIfIncomplete: true);

    expect(second.length, 3);
    expect(repo.calls, 1, reason: '拿到完整清單之後不該再打網路');
  });

  test('課表內部的呼叫不重抓——那條路只需要 semesterAt(0)，不值得多一顆進度框', () async {
    repo.results = [Stale(degraded, const FetchFailed('成績系統逾時')), Ok(complete)];
    final model = CourseModel();

    await model.getSemesterList();
    await model.getSemesterList();

    expect(repo.calls, 1);
  });

  test('重抓失敗時安靜留著舊清單，不再問一次要選哪個學期', () async {
    repo.results = [
      Stale(degraded, const FetchFailed('成績系統逾時')),
      const Failed(Offline()),
    ];
    final ui = _CountingUiDelegate();
    TaskUiDelegate.instance = ui;
    final model = CourseModel();

    await model.getSemesterList(refreshIfIncomplete: true);
    final second = await model.getSemesterList(refreshIfIncomplete: true);

    expect(second.length, 1, reason: '重抓失敗就留著上一次那份，總比清單變空好');
    expect(ui.chooseSemesterCalls, 0,
        reason: '手上已經有清單了。離線時每開一次選單就被問一次要選哪個學期是很煩的');
  });

  group('啟動後的背景預載', () {
    test('清單是空的就抓，而且一定是 background 模式', () async {
      // background: true 是「不要把登入頁蓋在使用者畫面上」的保證。
      // retry: none 擋不掉那件事——互動式登入的升級在 ensure() 裡面，
      // 而 run() 在看 retry 之前就已經呼叫過它了。
      repo.results = [Ok(complete)];
      final model = CourseModel();

      await model.preloadSemesterList();

      expect(repo.calls, 1);
      expect(repo.backgroundCalls, [true]);
      expect(Model.instance.getSemesterList().length, 3);
    });

    test('已經有清單就完全不碰網路', () async {
      repo.results = [Ok(complete)];
      Model.instance.setSemesterJsonList(degraded);

      await CourseModel().preloadSemesterList();

      expect(repo.calls, 0);
    });

    test('失敗就安靜失敗，不彈手動選學期', () async {
      repo.results = [const Failed(Offline())];
      final ui = _CountingUiDelegate();
      TaskUiDelegate.instance = ui;

      await CourseModel().preloadSemesterList();

      expect(ui.chooseSemesterCalls, 0, reason: '使用者沒有要求任何東西');
      expect(Model.instance.getSemesterList(), isEmpty);
    });

    test('預載拿到殘缺清單時標成不完整，下次打開選單還是會重抓', () async {
      repo.results = [
        Stale(degraded, const FetchFailed('成績系統逾時')),
        Ok(complete),
      ];
      final model = CourseModel();

      await model.preloadSemesterList();
      expect(Model.instance.isSemesterListComplete(), isFalse);

      final list = await model.getSemesterList(refreshIfIncomplete: true);
      expect(list.length, 3);
    });
  });

  test('一開始就全部失敗才彈手動選學期', () async {
    repo.results = [const Failed(Offline())];
    final ui = _CountingUiDelegate(answer: sem('113', '2'));
    TaskUiDelegate.instance = ui;
    final model = CourseModel();

    final list = await model.getSemesterList();

    expect(ui.chooseSemesterCalls, 1);
    expect(list.single.year, '113');
    // 手動選的視為完整：那是使用者明確的選擇，不該每次打開選單都重問。
    expect(Model.instance.isSemesterListComplete(), isTrue);
  });
}

class _FakeNtustRepository extends NtustRepository {
  List<Result<List<SemesterJson>>> results = [];
  int calls = 0;

  /// 每一次呼叫的 background 旗標。預載必須是 true。
  final List<bool> backgroundCalls = [];

  @override
  Future<Result<List<SemesterJson>>> getSemesterList(
      {bool background = false}) async {
    backgroundCalls.add(background);
    final r = results[calls < results.length ? calls : results.length - 1];
    calls++;
    return r;
  }
}

class _CountingUiDelegate extends NoopTaskUiDelegate {
  _CountingUiDelegate({this.answer});

  final SemesterJson? answer;
  int chooseSemesterCalls = 0;

  @override
  Future<SemesterJson?> chooseSemester({bool allowNull = false}) async {
    chooseSemesterCalls++;
    return answer;
  }
}
