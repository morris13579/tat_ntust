import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/connector/course_connector.dart'
    show CourseConnector;
import 'package:flutter_app/src/controller/course_table/course_model.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_department.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course/course_query_filter.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/native/course_table_bridge.dart';
import 'package:flutter_app/src/native/simulation_sessions.dart';
import 'package:flutter_app/src/store/extra_table_store.dart';
import 'package:flutter_app/src/util/course_search_merge.dart';
import 'package:flutter_app/src/util/course_table_conflict.dart';
import 'package:flutter_app/src/util/course_table_control.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:flutter_app/src/util/simulation_draft.dart';

typedef CourseQuery = Future<List<CourseMainInfoJson>> Function(
    SemesterJson semester, CourseQueryFilter filter);

/// 原生版的「導入其他課程」與模擬排課的搜尋。畫面照 `course_search_page.dart`：導入時加課與移除照
/// `CourseController.addCustomCourse`／`removeCourseById`、衝堂對目前這張課表算；模擬排課時加進草稿、
/// 衝堂對同一學期的實際課表加草稿算。
class CourseSearchBridge implements TatCourseSearchApi {
  CourseSearchBridge({
    SimulationSessions? sessions,
    ExtraTableStore? store,
    CourseModel? model,
    CourseQuery? query,
    Future<List<CollegeJson>?> Function()? loadColleges,
    Future<List<DepartmentJson>?> Function(String collegeNo)? loadDepartments,
  })  : _sessions = sessions,
        _extras = store,
        _model = model ?? CourseModel(),
        _query = query,
        _loadColleges = loadColleges ?? CourseConnector.getColleges,
        _loadDepartments = loadDepartments ?? CourseConnector.getDepartments;

  final SimulationSessions? _sessions;
  final ExtraTableStore? _extras;
  final CourseModel _model;
  final CourseQuery? _query;
  final Future<List<CollegeJson>?> Function() _loadColleges;
  final Future<List<DepartmentJson>?> Function(String collegeNo)
      _loadDepartments;

  List<CourseMainInfoJson> _results = [];
  int _generation = 0;
  String? _draftId;

  static void install(SimulationSessions sessions) =>
      TatCourseSearchApi.setUp(CourseSearchBridge(sessions: sessions));

  /// 模擬排課時，這一趟加課加進哪一份草稿；導入其他課程時是 null。
  SimulationSession? get _draft =>
      _draftId == null ? null : _sessions?.open[_draftId];

  @override
  CourseSearchStart? start(String? draftId) {
    _draftId = draftId;
    final draft = _draft;
    if (draftId != null && draft == null) return null;
    final table = _table();
    if (table == null) return null;
    _generation++;
    _results = [];
    final control = CourseTableControl();
    return CourseSearchStart(
      semester: '${table.courseSemester.year}-${table.courseSemester.semester}',
      keyword: CourseQueryFilter.homeDepartmentOf([
        ...?draft?.base?.getCourseIdList(),
        ...table.getCourseIdList(),
      ]),
      days: [
        for (final day in CourseTableConflict.days)
          CourseGridDay(
              index: day.index, label: control.getDayString(day.index)),
      ],
      sections: [
        for (final section in CourseTableConflict.sections)
          CourseGridSection(
            index: section.index,
            label: control.getSectionString(section.index),
            time: control.getTimeString(section.index),
          ),
      ],
    );
  }

  @override
  Future<CourseSearchResults?> search(
      CourseFilter filter, bool hideConflict, List<TimeSlot> slots) async {
    final table = _table();
    if (table == null) return null;
    final generation = ++_generation;
    final query = _query ?? _model.getQueryCourse;
    final found = await query(table.courseSemester, _toQuery(filter));
    if (generation != _generation) return null;
    _results = CourseSearchMerge.byCourseId(found);
    return results(hideConflict, slots);
  }

  @override
  CourseSearchResults results(bool hideConflict, List<TimeSlot> slots) {
    final table = _table();
    final ids = table?.getCourseIdList() ?? const <String>[];
    final wanted = <CourseSlot>{
      for (final slot in slots)
        if (slot.day >= 0 &&
            slot.day < CourseTableConflict.days.length &&
            slot.section >= 0 &&
            slot.section < SectionNumber.values.length)
          (Day.values[slot.day], SectionNumber.values[slot.section]),
    };
    final control = CourseTableControl();
    var clashes = 0;
    final courses = <SearchCourse>[];
    final base = _draft?.base;
    for (final course in _results) {
      final conflicts = [
        if (base != null) ...CourseTableConflict.conflictsOf(base, course),
        if (table != null) ...CourseTableConflict.conflictsOf(table, course),
      ];
      if (conflicts.isNotEmpty) clashes++;
      if (hideConflict && conflicts.isNotEmpty) continue;
      if (!CourseTableConflict.fitsSlots(course, wanted)) continue;
      courses.add(_item(course, conflicts, ids, control));
    }
    return CourseSearchResults(
        total: _results.length, clashes: clashes, courses: courses);
  }

  @override
  Future<CourseSearchChange> add(String courseId) async {
    final table = _table();
    final course = _results.where((c) => c.course.id == courseId).firstOrNull;
    if (table == null || course == null) {
      return CourseSearchChange(applied: false, grid: _grid(table));
    }
    if (_draft case final session?) {
      // 模擬排課就是要先排進去再看哪裡撞，衝堂不擋。
      SimulationDraft.addCourse(session.draft.table, course);
      await SimulationDraft.save(session.draft, _extras);
      return CourseSearchChange(applied: true);
    }
    course.course.select = false;
    if (!table.addCourseDetailByCourseInfo(course)) {
      return CourseSearchChange(applied: false, grid: _grid(table));
    }
    await _model.saveCourse(table);
    return CourseSearchChange(applied: true, grid: _grid(table));
  }

  @override
  Future<CourseSearchChange> remove(String courseId) async {
    final table = _table();
    if (table == null) return CourseSearchChange(applied: false);
    if (_draft case final session?) {
      SimulationDraft.removeCourse(session.draft.table, courseId);
      await SimulationDraft.save(session.draft, _extras);
      return CourseSearchChange(applied: true);
    }
    table.removeCourseByCourseId(courseId);
    await _model.saveCourse(table);
    return CourseSearchChange(applied: true, grid: _grid(table));
  }

  @override
  Future<List<CourseSearchOption>> colleges() async => [
        for (final college in await _loadColleges() ?? const <CollegeJson>[])
          CourseSearchOption(
              no: college.no,
              name: _displayName(college.name, college.engName)),
      ];

  @override
  Future<List<CourseSearchOption>> departments(String collegeNo) async => [
        for (final department
            in await _loadDepartments(collegeNo) ?? const <DepartmentJson>[])
          CourseSearchOption(
              no: department.no,
              name: _displayName(department.name, department.engName)),
      ];

  /// 加課的對象：模擬排課時是草稿，否則是目前的課表。
  CourseTableJson? _table() {
    if (_draftId != null) return _draft?.draft.table;
    final table = _model.getCourseSettingInfo();
    return table == null || table.isEmpty ? null : table;
  }

  static CourseGrid? _grid(CourseTableJson? table) =>
      table == null ? null : CourseTableBridge.toGrid(table);

  static CourseQueryFilter _toQuery(CourseFilter filter) => CourseQueryFilter(
        courseNo: filter.keyword,
        department: switch (filter.department) {
          final department? => DepartmentJson(
              no: department.no,
              name: department.name,
              engName: department.name),
          null => null,
        },
        dimension: switch (filter.dimension) {
          final dimension? => CourseDimension.values.byName(dimension.name),
          null => null,
        },
        level: switch (filter.level) {
          ProgramLevel.all => CourseProgramLevel.any,
          ProgramLevel.underGraduate => CourseProgramLevel.underGraduate,
          ProgramLevel.master => CourseProgramLevel.master,
        },
        foreignLanguageOnly: filter.foreignLanguageOnly,
        generalOnly: filter.generalOnly,
        intensiveOnly: filter.intensiveOnly,
        ntustOnly: filter.ntustOnly,
      );

  static SearchCourse _item(
      CourseMainInfoJson course,
      List<ConflictCell> conflicts,
      List<String> ids,
      CourseTableControl control) {
    final byCourse = <String, List<ConflictCell>>{};
    for (final cell in conflicts) {
      byCourse.putIfAbsent(cell.base.main.course.id, () => []).add(cell);
    }
    return SearchCourse(
      id: course.course.id,
      name: course.course.name,
      credits: _nonEmpty(course.course.credits.trim()),
      // querycourse 的 RequireOption 只有 R／E，認不得的不要硬猜。
      requirement: switch (course.course.category.trim().toUpperCase()) {
        'R' => CourseRequirement.compulsory,
        'E' => CourseRequirement.elective,
        _ => null,
      },
      teacher: _nonEmpty(course.getTeacherName().trim()),
      slots: _nonEmpty(control.slotLabel(course)),
      classroom: _nonEmpty(course.getClassroomName().trim()),
      conflicts: [
        for (final cells in byCourse.values)
          SearchConflict(
            courseName: cells.first.base.main.course.name,
            slots: control.conflictSlotsLabel(cells),
          ),
      ],
      added: ids.contains(course.course.id),
    );
  }

  static String _displayName(String name, String engName) =>
      LanguageUtils.getLangIndex() == LangEnum.zh ? name : engName;

  static String? _nonEmpty(String value) => value.isEmpty ? null : value;
}
