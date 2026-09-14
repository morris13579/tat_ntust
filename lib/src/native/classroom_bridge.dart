import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/config/section_time.dart';
import 'package:flutter_app/src/enum/classroom_view.dart';
import 'package:flutter_app/src/model/classroom/classroom_option.dart';
import 'package:flutter_app/src/model/classroom/classroom_usage_json.dart';
import 'package:flutter_app/src/repository/ntust_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/store/settings_store.dart';
import 'package:flutter_app/src/util/classroom_availability.dart';

/// 原生版的空教室，照 `ClassroomController`：一次只查一棟，每一棟每一天的結果各自留著，
/// 同一天換節次、換篩選都不必再打網路。
class ClassroomBridge implements TatClassroomApi {
  ClassroomBridge({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// `日期|大樓代號` → 那一棟那一天的結果。
  final Map<String, Result<ClassroomUsageJson>> _usage = {};

  static void install() => TatClassroomApi.setUp(ClassroomBridge());

  @override
  Future<ClassroomSetup> start() async {
    final layout = await SettingsStore.instance.classroomView;
    final result = await NtustRepository.instance.getClassroomCampuses();
    final campuses = result.dataOrNull ?? const <ClassroomCampusJson>[];
    final selection = ClassroomAvailability.initialBuilding(
        campuses, await SettingsStore.instance.classroomBuilding);
    return ClassroomSetup(
      campuses: [
        for (final campus in campuses)
          ClassroomCampus(
            code: campus.code,
            name: campus.name,
            buildings: [
              for (final building
                  in ClassroomAvailability.orderedBuildings(campus.buildings))
                ClassroomBuilding(code: building.code, name: building.name),
            ],
          ),
      ],
      campusCode: selection?.$1,
      buildingCode: selection?.$2,
      layout: ClassroomLayout.values.byName(layout.name),
      now: now(),
      sections: [
        for (var i = 0; i < sectionTimes.length; i++)
          ClassSection(
            label: sectionLabels[i],
            start: sectionTimes[i].start,
            end: sectionTimes[i].end,
          ),
      ],
      error: switch (result) {
        Failed(:final reason) => reason.message,
        _ => null,
      },
      signedIn: AuthSession.instance.isSignedIn,
    );
  }

  @override
  ClassroomNow now() {
    final (date, section) = ClassroomAvailability.nowSection(_clock());
    return ClassroomNow(date: dateKey(date), section: section);
  }

  @override
  Future<ClassroomDay> day(String campusCode, String buildingCode, String date,
      int section, ClassroomRun run, bool refresh) async {
    final key = '$date|$buildingCode';
    if (refresh || _usage[key]?.hasData != true) {
      _usage[key] = await NtustRepository.instance.getClassroomUsage(
        campusCode: campusCode,
        date: _parseDate(date),
        buildingCode: buildingCode,
      );
    }
    return _dayOf(
        _usage[key]!, section, ClassroomRunFilter.values.byName(run.name));
  }

  @override
  Future<void> rememberBuilding(String code) =>
      SettingsStore.instance.setClassroomBuilding(code);

  @override
  Future<void> rememberLayout(ClassroomLayout layout) => SettingsStore.instance
      .setClassroomView(ClassroomView.values.byName(layout.name));

  static ClassroomDay _dayOf(
      Result<ClassroomUsageJson> result, int section, ClassroomRunFilter run) {
    final data = result.dataOrNull;
    final vacancies = data == null
        ? const <ClassroomVacancy>[]
        : ClassroomAvailability.of(data, section);
    final free = vacancies.where((v) => v.isFree).toList();
    final busy = vacancies.where((v) => !v.isFree).toList();
    return ClassroomDay(
      error: switch (result) {
        Failed(:final reason) => reason.message,
        _ => null,
      },
      closed: data != null && data.rooms.isEmpty,
      fetchedAt: data?.fetchedAt.millisecondsSinceEpoch,
      roomCount: data?.rooms.length ?? 0,
      freeCount: free.length,
      floors: [
        for (final MapEntry(key: floor, value: rooms)
            in ClassroomAvailability.byFloor(
                    vacancies.where(run.accepts).toList())
                .entries)
          ClassroomFloor(
              floor: floor, rooms: [for (final v in rooms) _room(v)]),
      ],
      free: [for (final v in ClassroomAvailability.byRunLength(free)) _room(v)],
      busy: [for (final v in ClassroomAvailability.byRunLength(busy)) _room(v)],
    );
  }

  static ClassroomRoom _room(ClassroomVacancy vacancy) => ClassroomRoom(
        name: vacancy.room.name,
        slots: [
          for (final slot in vacancy.room.slots)
            ClassroomSlot(
              free: slot.isFree,
              course: slot.course,
              teacher: slot.teacher,
              booked: slot.course.isEmpty && slot.marked,
            ),
        ],
        freeSections: vacancy.freeSections,
        freeAllDay: vacancy.isFreeAllDay,
        freeUntil: vacancy.freeUntil?.end,
        nextBusyAt: vacancy.nextBusyAt?.start,
        nextIsBooking: vacancy.nextIsBooking,
        nextCourse: vacancy.nextBusySlot?.course,
      );

  static String dateKey(DateTime day) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${day.year}-${two(day.month)}-${two(day.day)}';
  }

  static DateTime _parseDate(String date) {
    final parts = date.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }
}
