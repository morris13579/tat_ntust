import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/controller/course_table/course_model.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/native/course_search_bridge.dart';
import 'package:flutter_app/src/native/simulation_bridge.dart';
import 'package:flutter_app/src/native/simulation_sessions.dart';
import 'package:flutter_app/src/store/extra_table_store.dart';
import 'package:flutter_app/src/store/key_value_store.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/simulation_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

CourseMainInfoJson course(String id, String name, Map<Day, String> time) {
  final full = {for (final d in Day.values) d: ''}..addAll(time);
  return CourseMainInfoJson(
    course: CourseMainJson(id: id, name: name, credits: '3', time: full),
  );
}

CourseFilter filter(String keyword) => CourseFilter(
      keyword: keyword,
      level: ProgramLevel.all,
      foreignLanguageOnly: false,
      generalOnly: false,
      intensiveOnly: false,
      ntustOnly: false,
    );

/// 原生版的模擬排課。草稿與實際課表分開存、衝堂照樣排進去、id 沿用 Flutter 版——
/// 壞了，使用者會在試排的時候動到真的課表，或是找不到已經排好的草稿。
void main() {
  setUpAll(() async => loadTestL10n());

  late SimulationSessions sessions;
  late ExtraTableStore store;
  late SimulationBridge bridge;
  late CourseSearchBridge search;
  late List<CourseMainInfoJson> found;
  final semester = SemesterJson(year: '115', semester: '1');

  setUp(() async {
    resetAppStatics();
    Model.instance.setAccount('B11230223');
    final real = CourseTableJson(courseSemester: semester, studentId: 'B11230223');
    expect(
        real.addCourseDetailByCourseInfo(
            course('CS3039701', '資料結構', {Day.monday: '34'})),
        isTrue);
    await CourseModel().saveCourse(real);
    sessions = SimulationSessions();
    store = ExtraTableStore(SharedPrefsKeyValueStore());
    ExtraTableStore.instance = store;
    found = [];
    bridge = SimulationBridge(
      sessions,
      store: store,
      querySemesters: () async =>
          [semester, SemesterJson(year: '114', semester: '2')],
    );
    search = CourseSearchBridge(
      sessions: sessions,
      store: store,
      query: (semester, filter) async => found,
    );
  });

  test('新增：學期照 querycourse，id 沿用 Flutter 版的格式，還沒加課不存', () async {
    expect(await bridge.semesters(), ['115-1', '114-2']);

    final state = await bridge.open('115-1');

    expect(state.id, SimulationDraft.idOf('B11230223', semester));
    expect(state.label, '115-1 加退選草稿');
    expect(state.detail, '還沒加任何課。按下面的「搜尋課程」開始排。');
    expect(state.cells.where((c) => c.real != null), isNotEmpty);
    expect(state.cells.where((c) => c.draft != null), isEmpty);
    expect(await bridge.drafts(), isEmpty);
  });

  test('搜尋頁加進草稿：衝堂照樣排進去、對實際課表加草稿算，實際課表不動', () async {
    final state = await bridge.open('115-1');
    final start = search.start(state.id)!;
    expect(start.semester, '115-1');
    found = [course('CS1001001', '演算法', {Day.monday: '3'})];

    final results = (await search.search(filter('CS'), false, const []))!;
    expect(results.courses.single.conflicts, isNotEmpty);
    final change = await search.add('CS1001001');

    expect(change.applied, isTrue);
    expect(change.grid, isNull);
    final updated = (await bridge.draft(state.id))!;
    expect(updated.hasConflicts, isTrue);
    expect(updated.conflictBanner, startsWith('1 處衝堂'));
    expect(updated.cells.where((c) => c.conflict), hasLength(1));
    expect(updated.courses.single.clashes, isTrue);
    expect(CourseModel().getCourseSettingInfo()!.getCourseIdList(),
        ['CS3039701']);
    final drafts = await bridge.drafts();
    expect(drafts.single.summary, '1 門課 · 3 學分 · 1 處衝堂');
  });

  test('移除草稿的課；刪掉整份草稿', () async {
    final state = await bridge.open('115-1');
    search.start(state.id);
    found = [course('CS1001001', '演算法', {Day.tuesday: '5'})];
    await search.search(filter('CS'), false, const []);
    await search.add('CS1001001');

    final removed = (await bridge.removeCourse(state.id, 'CS1001001'))!;
    expect(removed.courses, isEmpty);

    await bridge.deleteDraft(state.id);
    expect(await bridge.drafts(), isEmpty);
    expect(await bridge.draft(state.id), isNull);
  });

  test('沒有下載過的學期從空白課表排', () async {
    final state = await bridge.open('114-2');

    expect(state.cells, isEmpty);
  });
}
