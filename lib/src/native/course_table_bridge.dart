import 'dart:async';

import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/R.dart';
import 'package:sprintf/sprintf.dart';
import 'package:flutter_app/src/controller/course_table/course_model.dart';
import 'package:flutter_app/src/config/section_time.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/native/classroom_bridge.dart';
import 'package:flutter_app/src/repository/ntust_repository.dart';
import 'package:flutter_app/src/service/store_review_service.dart';
import 'package:flutter_app/src/store/extra_table_store.dart';
import 'package:flutter_app/src/util/classroom_availability.dart';
import 'package:flutter_app/src/util/course_table_control.dart';
import 'package:flutter_app/src/util/empty_slot_text.dart';
import 'package:flutter_app/src/util/course_table_share_codec.dart';
import 'package:flutter_app/src/util/shared_table_builder.dart';
import 'package:flutter_app/src/version/app_version.dart';

/// 原生版課表頁的資料。流程照 Flutter 版的 `CourseController` 與 `course_table_page.dart`：
/// 先顯示上次那一張，沒有才去抓；抓到的一律經 `CourseModel.saveCourse` 寫回兩份副本。
class CourseTableBridge implements TatCourseTableApi {
  CourseTableBridge(
      [CourseModel? model,
      ExtraTableStore? extras,
      void Function(TransferProgress progress)? onProgress])
      : _model = model ?? CourseModel(),
        _extras = extras,
        _onProgress = onProgress ?? TatTransferHost().onProgress;

  final CourseModel _model;
  final ExtraTableStore? _extras;
  final void Function(TransferProgress progress) _onProgress;

  ExtraTableStore get _store => _extras ?? ExtraTableStore.instance;

  /// 匯入前的預覽最多列幾門，同 `import_confirm_sheet.dart`。
  static const int _previewLimit = 3;

  static void install() => TatCourseTableApi.setUp(CourseTableBridge());

  @override
  CourseGrid? current() {
    final table = _model.getCourseSettingInfo();
    if (table == null || table.isEmpty) return null;
    _tableShown();
    return toGrid(table);
  }

  @override
  Future<CourseGrid?> load(String? semester, bool refresh) async {
    try {
      final table = await _model.getCourseTable(
        semesterSetting: semester == null ? null : parseSemester(semester),
        refresh: refresh,
      );
      await _model.saveCourse(table);
      if (table.isEmpty) return null;
      _tableShown();
      return toGrid(table);
    } catch (e, stack) {
      // CourseModel 的失敗出口都是沒有訊息的 throw；錯誤對話框 run() 已經問過。
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  @override
  Future<List<String>> semesters() async => [
        for (final s in await _model.getSemesterList(refreshIfIncomplete: true))
          _semester(s),
      ];

  @override
  Future<void> preloadSemesters() => _model.preloadSemesterList();

  @override
  List<MyTable> myTables() => [
        for (final table in _model.getCacheCourseTableList())
          MyTable(
            studentId: table.studentId,
            semester: _semester(table.courseSemester),
            courseCount: table.getCourseIdList().length,
            credits: table.getTotalCredit(),
          ),
      ];

  @override
  Future<CourseGrid?> applyMyTable(String studentId, String semester) async {
    final table = _mine(studentId, semester);
    if (table == null) return null;
    await _model.saveFavoriteCourse(table);
    _tableShown();
    return toGrid(table);
  }

  @override
  Future<void> deleteMyTable(String studentId, String semester) async {
    final table = _mine(studentId, semester);
    if (table != null) await _model.removeFavoriteCourse(table);
  }

  @override
  TableShare? share() {
    final table = _model.getCourseSettingInfo();
    if (table == null || table.isEmpty) return null;
    return TableShare(
      qr: CourseTableShareCodec.encode(table),
      code: CourseTableShareCodec.encodePayload(table),
      studentId: table.studentId,
      semester: _semester(table.courseSemester),
      courseCount: table.getCourseIdList().length,
      credits: table.getTotalCredit(),
    );
  }

  @override
  Future<List<SharedTableInfo>> sharedTables() async {
    await _store.load();
    return [for (final table in _store.shared) _sharedInfo(table)];
  }

  @override
  Future<CourseGrid?> sharedTable(String id) async {
    await _store.load();
    final shared = _store.findShared(id);
    return shared == null ? null : toGrid(shared.table);
  }

  @override
  Future<void> deleteSharedTable(String id) async {
    await _store.load();
    await _store.removeShared(id);
  }

  @override
  SharePreview? previewShareCode(String raw) {
    final payload = CourseTableShareCodec.decode(raw);
    if (payload == null) return null;
    final control = CourseTableControl();
    return SharePreview(
      studentId: payload.studentId,
      semester: '${payload.year}-${payload.semester}',
      courseCount: payload.courses.length,
      courses: [
        for (final course in payload.courses.take(_previewLimit))
          SharePreviewCourse(
            id: course.id,
            slots: control.sharedSlotsLabel(course.slots),
          ),
      ],
    );
  }

  @override
  Future<List<SharedCourseInfo>> lookupPreview(String raw) async {
    final payload = CourseTableShareCodec.decode(raw);
    if (payload == null) return [];
    final lookups = await NtustRepository.instance.lookupSharedCourses(
      SemesterJson(year: payload.year, semester: payload.semester),
      [for (final course in payload.courses.take(_previewLimit)) course.id],
    );
    return [
      for (final lookup in lookups)
        SharedCourseInfo(
          id: lookup.id,
          name: _nonEmpty(lookup.courses.firstOrNull?.course.name.trim() ?? ''),
          classroom: _nonEmpty(
              lookup.courses.firstOrNull?.getClassroomName().trim() ?? ''),
        ),
    ];
  }

  @override
  Future<SharedTableInfo?> importShareCode(String raw) async {
    final payload = CourseTableShareCodec.decode(raw);
    if (payload == null) return null;
    final table = SharedTableBuilder.build(payload);
    final shared = ExtraTable(
      id: 'shared-${payload.studentId}-${payload.semesterCode}',
      label: payload.studentId,
      table: table,
      savedAt: DateTime.now(),
      payload: CourseTableShareCodec.encodePayload(table),
    );
    await _store.load();
    await _store.upsertShared(shared);
    return _sharedInfo(shared);
  }

  @override
  Future<CourseGrid?> restoreSharedTable(String id) async {
    await _store.load();
    final shared = _store.findShared(id);
    if (shared == null) return null;
    final ids = shared.table.getCourseIdList();
    // 一門課一個請求，照 `SharedTablePage` 報「補課名 x/y」。
    void report(int done) => _onProgress(TransferProgress(
          key: 'restore-$id',
          progress: ids.isEmpty ? null : done / ids.length,
          label: sprintf(R.current.importRestoring, [done, ids.length]),
          phase: TransferPhase.download,
        ));
    report(0);
    final courses = await NtustRepository.instance.restoreSharedCourses(
      shared.table.courseSemester,
      ids,
      onProgress: (done, _) => report(done),
    );
    SharedTableBuilder.enrich(shared.table, courses);
    await _store.upsertShared(shared);
    return toGrid(shared.table);
  }

  @override
  Future<CourseGrid?> removeCourse(int day, int section) async {
    final table = _model.getCourseSettingInfo();
    final info = table == null ? null : _infoAt(table, day, section);
    if (table == null || info == null) return null;
    table.removeCourseByCourseId(info.main.course.id);
    await _model.saveCourse(table);
    return toGrid(table);
  }

  @override
  Future<CourseGrid?> editCourseId(int day, int section, String courseId) async {
    final table = _model.getCourseSettingInfo();
    final info = table == null ? null : _infoAt(table, day, section);
    if (table == null || info == null) return null;
    final oldId = info.main.course.id;
    final name = info.main.course.name;
    // 一門課佔的每一格讀回硬碟之後各是一份，只改點到的那一格，其餘幾格會留著舊課號。
    for (final cells in table.courseInfoMap.values) {
      for (final cell in cells.values) {
        final course = cell.main.course;
        if (course.id == oldId && course.name == name) {
          course.id = courseId.trim();
        }
      }
    }
    await _model.saveCourse(table);
    return toGrid(table);
  }

  @override
  EmptySlot? emptySlot(int day, int section) {
    final date = ClassroomAvailability.dateForWeekday(day);
    if (date == null || section < 0 || section >= sectionTimes.length) {
      return null;
    }
    return EmptySlot(
      title: EmptySlotText.title(date, section),
      subtitle: EmptySlotText.subtitle(section),
      date: ClassroomBridge.dateKey(date),
      section: section,
    );
  }

  /// 課表畫出來的這一刻是 App 最有用的時候，評分要問就問在這裡，照 `CourseController._showCourseTable`。
  /// 它自己會判斷次數與間隔，多半什麼都不做。
  static void _tableShown() => unawaited(_recordReviewSuccess());

  static Future<void> _recordReviewSuccess() async {
    try {
      await StoreReviewService.instance
          .recordSuccess(await APPVersion.getAppVersion());
    } catch (e) {
      Log.d('store review: $e');
    }
  }

  static CourseInfoJson? _infoAt(CourseTableJson table, int day, int section) {
    if (day < 0 ||
        day >= CourseTableControl.dayLength ||
        section < 0 ||
        section >= CourseTableControl.sectionLength) {
      return null;
    }
    final info = (CourseTableControl()..set(table)).getCourseInfo(day, section);
    return info == null || info.isEmpty ? null : info;
  }

  static CourseGrid toGrid(CourseTableJson table) {
    final control = CourseTableControl()..set(table);
    final ids = table.getCourseIdList();
    final days = control.getDayIntList;
    final sections = control.getSectionIntList;
    return CourseGrid(
      studentId: table.studentId,
      semester: _semester(table.courseSemester),
      courseCount: ids.length,
      credits: table.getTotalCredit(),
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
            if (control.getCourseInfo(d, s) case final info? when !info.isEmpty)
              CourseGridCell(
                day: d,
                section: s,
                courseId: info.main.course.id,
                name: info.main.course.name,
                classroom: _nonEmpty(info.main.getClassroomName()),
                teacher: _nonEmpty(info.main.getTeacherName()),
                selected: info.main.course.select,
                order: ids.indexOf(info.main.course.id),
              ),
      ],
    );
  }

  /// 「115-1」→ [SemesterJson]，格式不對回 null。
  static SemesterJson? parseSemester(String semester) {
    final parts = semester.split('-');
    if (parts.length != 2) return null;
    return SemesterJson(year: parts[0], semester: parts[1]);
  }

  CourseTableJson? _mine(String studentId, String semester) {
    for (final table in _model.getCacheCourseTableList()) {
      if (table.studentId == studentId &&
          _semester(table.courseSemester) == semester) {
        return table;
      }
    }
    return null;
  }

  static SharedTableInfo _sharedInfo(ExtraTable table) => SharedTableInfo(
        id: table.id,
        label: table.label,
        semester: _semester(table.table.courseSemester),
        courseCount: table.table.getCourseIdList().length,
        savedAt: table.savedAt.millisecondsSinceEpoch,
      );

  static String _semester(SemesterJson semester) =>
      '${semester.year}-${semester.semester}';

  static String? _nonEmpty(String value) => value.isEmpty ? null : value;
}
