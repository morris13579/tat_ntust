import 'package:flutter_app/src/config/section_time.dart';
import 'package:flutter_app/src/model/classroom/classroom_usage_json.dart';

/// 一間教室在某一節次上的可用性。
///
/// 借用系統給的是「每一間教室的一整天」，這裡把它翻成使用者真正要問的
/// 那句話：**這一節空不空、可以待多久、幾點被趕**。
class ClassroomVacancy {
  const ClassroomVacancy({
    required this.room,
    required this.section,
    required this.freeSections,
    required this.nextBusySection,
  });

  final ClassroomRowJson room;

  /// 查的是第幾節（索引，與 [sectionTimes] 對齊）。
  final int section;

  /// 從 [section] 起連續空著幾節。0 代表這一節本來就有人用。
  final int freeSections;

  /// 連續空堂之後第一個有人用的節次，到放學都空著就是 null。
  final int? nextBusySection;

  bool get isFree => freeSections > 0;

  /// 這一天一節課都沒有。
  bool get isFreeAllDay => room.isFreeAllDay;

  /// 佔用下一節的是什麼。到放學都空著就是 null。
  ClassroomSlotJson? get nextBusySlot =>
      nextBusySection == null ? null : room.slots[nextBusySection!];

  /// 下一個佔用是「借出」而不是排課：站台標了記號、但沒有課名。
  bool get nextIsBooking {
    final slot = nextBusySlot;
    return slot != null && slot.marked && slot.course.isEmpty;
  }

  /// 空到幾點——連續空堂裡最後一節的結束時刻。沒空著就是 null。
  SectionTime? get freeUntil => isFree
      ? sectionTimes[(section + freeSections - 1).clamp(0, sectionTimes.length - 1)]
      : null;

  /// 幾點被趕——下一個佔用的開始時刻。到放學都空著就是 null。
  SectionTime? get nextBusyAt =>
      nextBusySection == null ? null : sectionTimes[nextBusySection!];

  /// 樓層。教室編號一律是「大樓-三位數房號」（`IB-501`、`IB-602-1`），
  /// 房號的第一碼就是樓層。解不出來就回 null，呼叫端把它們收在一組。
  int? get floor {
    final parts = room.name.split('-');
    if (parts.length < 2) return null;
    final digits = RegExp(r'^\d+').stringMatch(parts[1]);
    if (digits == null || digits.length < 3) return null;
    return int.tryParse(digits.substring(0, digits.length - 2));
  }
}

/// 連續空堂的長度篩選。清單檢視用；一整天檢視自己就看得到長度，不需要篩。
enum ClassroomRunFilter {
  /// 不限：這一節空著就算。
  any(1),

  /// 至少連續兩節。
  twoSections(2),

  /// 至少連續三節。
  threeSections(3),

  /// 一整天都沒人用。
  allDay(0);

  const ClassroomRunFilter(this.minSections);

  /// [allDay] 不是用節數判斷的，它看的是 [ClassroomVacancy.isFreeAllDay]。
  final int minSections;

  bool accepts(ClassroomVacancy vacancy) => this == ClassroomRunFilter.allDay
      ? vacancy.isFreeAllDay
      : vacancy.freeSections >= minSections;
}

/// 把一次查詢的結果翻成可用性。
class ClassroomAvailability {
  const ClassroomAvailability._();

  /// 每一間教室在第 [section] 節的可用性，順序照站台給的順序。
  static List<ClassroomVacancy> of(ClassroomUsageJson usage, int section) {
    final result = <ClassroomVacancy>[];
    for (final room in usage.rooms) {
      result.add(_vacancy(room, section));
    }
    return result;
  }

  static ClassroomVacancy _vacancy(ClassroomRowJson room, int section) {
    final slots = room.slots;
    // 查的節次超出站台給的欄位數時當成沒資料，不要讓索引爆掉。
    if (section < 0 || section >= slots.length || !slots[section].isFree) {
      return ClassroomVacancy(
        room: room,
        section: section,
        freeSections: 0,
        nextBusySection:
            section >= 0 && section < slots.length ? section : null,
      );
    }

    var run = 0;
    var index = section;
    while (index < slots.length && slots[index].isFree) {
      run++;
      index++;
    }
    return ClassroomVacancy(
      room: room,
      section: section,
      freeSections: run,
      nextBusySection: index < slots.length ? index : null,
    );
  }

  /// 依樓層分組，樓層由小到大；同一層裡照站台的順序。
  ///
  /// 解不出樓層的教室收在最後一組，key 是 null——**不要把它們丟掉**，
  /// 站台哪天換了編號格式時，使用者看到的應該是「多了一組沒有標題的教室」
  /// 而不是「教室憑空變少」。
  static Map<int?, List<ClassroomVacancy>> byFloor(
      List<ClassroomVacancy> vacancies) {
    final grouped = <int?, List<ClassroomVacancy>>{};
    for (final vacancy in vacancies) {
      grouped.putIfAbsent(vacancy.floor, () => []).add(vacancy);
    }
    final keys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == null) return 1;
        if (b == null) return -1;
        return a.compareTo(b);
      });
    return {for (final key in keys) key: grouped[key]!};
  }

  /// 一整天檢視的排序：空得最久的排前面，同長度照教室編號。
  static List<ClassroomVacancy> byRunLength(List<ClassroomVacancy> vacancies) {
    final sorted = [...vacancies];
    sorted.sort((a, b) {
      final run = b.freeSections.compareTo(a.freeSections);
      return run != 0 ? run : a.room.name.compareTo(b.room.name);
    });
    return sorted;
  }

  /// 課表上的「星期幾」對應到最近的哪一天。今天就是那一天時回今天。
  ///
  /// [weekday] 是 `Day` 的索引（0 = 星期一）。課表是一張沒有日期的週表，
  /// 而借用系統要的是具體日期，這一行就是兩者之間的換算。
  ///
  /// `Day.unKnown`（索引 7）沒有對應的日子，呼叫端要先擋掉——這裡回 null
  /// 而不是硬湊一天，免得使用者查到一個與那一格無關的日期。
  static DateTime? dateForWeekday(int weekday, {DateTime? from}) {
    if (weekday < 0 || weekday > 6) return null;
    final now = from ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // DateTime.weekday 是 1..7（週一到週日），Day 的索引是 0..6。
    final delta = (weekday + 1 - today.weekday) % 7;
    return today.add(Duration(days: delta));
  }

  /// 現在是第幾節、哪一天。
  ///
  /// 回傳的日期不一定是今天：最後一節下課之後「現在」已經沒有意義，這時候
  /// 給的是明天的第一節。節次與節次之間的下課時間算「下一節」——正在走去
  /// 找教室的人要的是待會那一節，不是剛結束的那一節。
  static (DateTime date, int section) nowSection(DateTime now) {
    for (var i = 0; i < sectionTimes.length; i++) {
      if (now.isBefore(sectionTimes[i].endOn(now))) {
        return (DateTime(now.year, now.month, now.day), i);
      }
    }
    final tomorrow = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));
    return (tomorrow, 0);
  }
}
