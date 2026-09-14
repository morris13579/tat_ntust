import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/controller/course_table/course_model.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/native/course_table_bridge.dart';
import 'package:flutter_app/src/native/simulation_sessions.dart';
import 'package:flutter_app/src/repository/ntust_repository.dart';
import 'package:flutter_app/src/store/extra_table_store.dart';
import 'package:flutter_app/src/util/course_table_control.dart';
import 'package:flutter_app/src/util/simulation_draft.dart';

/// 原生版的模擬排課。開哪一份照 `course_table_page.dart` 的 `_openSimulation`，
/// 畫面照 `simulation_page.dart`，規則在 [SimulationDraft]。
class SimulationBridge implements TatSimulationApi {
  SimulationBridge(
    this._sessions, {
    CourseModel? model,
    ExtraTableStore? store,
    Future<List<SemesterJson>> Function()? querySemesters,
  })  : _model = model ?? CourseModel(),
        _extras = store,
        _querySemesters = querySemesters ??
            (() => NtustRepository.instance.getQueryCourseSemesters());

  final SimulationSessions _sessions;
  final CourseModel _model;
  final ExtraTableStore? _extras;
  final Future<List<SemesterJson>> Function() _querySemesters;

  ExtraTableStore get _store => _extras ?? ExtraTableStore.instance;

  static void install(SimulationSessions sessions) =>
      TatSimulationApi.setUp(SimulationBridge(sessions));

  @override
  Future<List<DraftTableInfo>> drafts() async {
    await _store.load();
    final current = _current();
    return [
      for (final draft in _store.drafts)
        DraftTableInfo(
          id: draft.id,
          label: draft.label,
          summary: SimulationDraft.listSummary(current, draft.table),
        ),
    ];
  }

  /// 學期清單來自 querycourse 而不是使用者自己的紀錄：新學期在選課開始前就查得到。
  @override
  Future<List<String>> semesters() async {
    var list = await _querySemesters();
    if (list.isEmpty) {
      list = await _model.getSemesterList(refreshIfIncomplete: true);
    }
    return [for (final s in list) '${s.year}-${s.semester}'];
  }

  @override
  Future<SimulationState> open(String semester) async {
    await _store.load();
    final parsed = CourseTableBridge.parseSemester(semester) ?? SemesterJson();
    final studentId = _current()?.studentId ?? '';
    final draft =
        _store.findDraft(SimulationDraft.idOf(studentId, parsed)) ??
            SimulationDraft.create(studentId, parsed);
    return stateOf(_register(draft));
  }

  @override
  Future<SimulationState?> draft(String id) async {
    final session = _sessions.open[id];
    if (session != null) return stateOf(session);
    await _store.load();
    final draft = _store.findDraft(id);
    return draft == null ? null : stateOf(_register(draft));
  }

  @override
  Future<SimulationState?> removeCourse(String id, String courseId) async {
    final session = _sessions.open[id];
    if (session == null) return null;
    SimulationDraft.removeCourse(session.draft.table, courseId);
    await SimulationDraft.save(session.draft, _store);
    return stateOf(session);
  }

  @override
  Future<void> deleteDraft(String id) async {
    await _store.load();
    await _store.removeDraft(id);
    _sessions.open.remove(id);
  }

  SimulationSession _register(ExtraTable draft) {
    final session = SimulationSession(
        draft, SimulationDraft.baseOf(draft, _model.getCacheCourseTableList()));
    _sessions.open[draft.id] = session;
    return session;
  }

  CourseTableJson? _current() {
    final table = _model.getCourseSettingInfo();
    return table == null || table.isEmpty ? null : table;
  }

  static SimulationState stateOf(SimulationSession session) {
    final draft = session.draft.table;
    final base = session.base;
    final merged = SimulationDraft.merged(base, draft);
    final control = CourseTableControl()..set(merged);
    final conflicts = SimulationDraft.conflictsOf(base, draft);
    final ids = merged.getCourseIdList();
    final clashing = {for (final c in conflicts) c.overlay.main.course.id};
    SimCourse? course(CourseInfoJson? info) => info == null || info.isEmpty
        ? null
        : SimCourse(
            id: info.main.course.id,
            name: info.main.course.name,
            order: ids.indexOf(info.main.course.id),
          );
    final days = control.getDayIntList;
    final sections = control.getSectionIntList;
    return SimulationState(
      id: session.draft.id,
      label: session.draft.label,
      conflictBanner: conflicts.isEmpty
          ? null
          : SimulationDraft.conflictBanner(control, conflicts),
      days: [
        for (final d in days)
          CourseGridDay(index: d, label: control.getDayString(d)),
      ],
      sections: [
        for (final s in sections)
          CourseGridSection(
            index: s,
            label: control.getSectionString(s),
            time: control.getTimeString(s),
          ),
      ],
      cells: [
        for (final d in days)
          for (final s in sections)
            if (_cell(d, s,
                    real: course(base?.courseInfoMap[Day.values[d]]
                        ?[SectionNumber.values[s]]),
                    planned: course(draft.courseInfoMap[Day.values[d]]
                        ?[SectionNumber.values[s]]))
                case final cell?)
              cell,
      ],
      draftSummary: SimulationDraft.draftSummary(draft),
      detail: SimulationDraft.isEmpty(draft)
          ? R.current.simulationEmptyHint
          : SimulationDraft.totalLine(base, draft, conflicts),
      hasConflicts: conflicts.isNotEmpty,
      courses: [
        for (final c in SimulationDraft.coursesOf(draft))
          DraftCourseRow(
            id: c.course.id,
            name: c.course.name,
            supporting: SimulationDraft.courseSupporting(control, c),
            clashes: clashing.contains(c.course.id),
          ),
      ],
    );
  }

  /// 同一門課同時在實際課表與草稿裡不算衝堂——那只是「這門課我已經在修了」，
  /// 判定與 `CourseTableConflict.findConflicts` 一致。
  static SimCell? _cell(int day, int section,
      {required SimCourse? real, required SimCourse? planned}) {
    if (real == null && planned == null) return null;
    return SimCell(
      day: day,
      section: section,
      real: real,
      draft: planned,
      conflict: real != null && planned != null && real.id != planned.id,
    );
  }
}
