import 'package:flutter_app/src/model/moodle_webapi/moodle_core_calendar_action_events.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/util/moodle_course_name_utils.dart';

/// 待辦清單的分組。順序就是畫面順序。
enum DeadlineBucket { overdue, today, thisWeek, later }

class DeadlineGroup {
  const DeadlineGroup(this.bucket, this.events);

  final DeadlineBucket bucket;
  final List<MoodleActionEvent> events;
}

/// 一筆待辦在 App 內對應的東西：哪一門課、課程裡的哪一個模組（cmid）。
///
/// 課號而不是 Moodle 內部 id：課程頁吃的是課號，內部 id 由 `MoodleRepository`
/// 自己查。這裡也刻意不帶模組的 instance——那要拿 cmid 去課程模組表對，見
/// [UpcomingEventUtils.cmidOf]。
class UpcomingEventTarget {
  const UpcomingEventTarget({
    required this.cmid,
    required this.courseId,
    required this.courseName,
  });

  final int cmid;
  final String courseId;
  final String courseName;
}

/// 待辦清單的純函式：分組與時間格式。沒有任何 UI 與網路。
class UpcomingEventUtils {
  UpcomingEventUtils._();

  /// App 內有頁面可以開的模組。名單是封閉的：清單上會出現 lesson、scorm、
  /// choice、feedback 這些沒有對應頁面的模組，漏接就變成點了沒反應。
  static const Set<String> inAppModules = {'assign', 'quiz', 'forum'};

  /// 這筆待辦指到的 course module id。
  ///
  /// **不可以拿 `event.instance` 當模組自己的 id 用。** NTUST 的站台在這個欄位
  /// 回的是 cmid，不是 Moodle 文件寫的模組 instance：實測「期中報告」的事件
  /// `instance` 是 354220，但那是它的 cmid，assign 自己的 id 是 54556。拿它當
  /// assignId 會查到一個不存在的作業。
  ///
  /// `view.php?id=` 在 Moodle 一律是 cmid，所以以網址為準，`instance` 只在網址
  /// 認不出來時當備援。
  static final RegExp _cmidInUrl = RegExp(r'[?&]id=(\d+)');

  static int? cmidOf(MoodleActionEvent event) {
    for (final url in [event.url, event.openUrl]) {
      final match = _cmidInUrl.firstMatch(url);
      final cmid = int.tryParse(match?.group(1) ?? '');
      if (cmid != null && cmid > 0) return cmid;
    }
    final instance = event.instance;
    return (instance != null && instance > 0) ? instance : null;
  }

  /// 這筆待辦是哪一門課的哪一個模組？認不出來回 null，呼叫端就照舊開 WebView。
  ///
  /// 這裡不看 `modulename`：真正要開哪一頁是拿 cmid 去課程模組表對出來的，
  /// 以那一份為準，模組類型的過濾在 [moduleOf]。
  static UpcomingEventTarget? targetOf(MoodleActionEvent event) {
    final cmid = cmidOf(event);
    if (cmid == null) return null;
    final course = event.course;
    if (course == null) return null;
    final courseId =
        MoodleCourseNameUtils.courseIdOfIdNumber(course.idnumber) ??
            MoodleCourseNameUtils.courseCodeOf(course.fullname) ??
            MoodleCourseNameUtils.courseCodeOf(course.shortname);
    if (courseId == null || courseId.isEmpty) return null;
    return UpcomingEventTarget(
      cmid: cmid,
      courseId: courseId,
      courseName: courseLabelOf(event) ?? courseId,
    );
  }

  /// 課程模組表裡 cmid 對得上、而且 App 內開得起來的那一個模組。
  static Modules? moduleOf(
      List<MoodleCoreCourseGetContents> sections, int cmid) {
    for (final section in sections) {
      for (final module in section.modules) {
        if (module.id == cmid && inAppModules.contains(module.modname)) {
          return module;
        }
      }
    }
    return null;
  }

  /// 課名前綴的實作在 [MoodleCourseNameUtils]：課程總分那一頁也要用同一套規則。
  static String stripCoursePrefix(String name) =>
      MoodleCourseNameUtils.stripCoursePrefix(name);

  /// 顯示用課名：shortname 優先、空的退 fullname；站台事件沒有 course 回 null。
  static String? courseLabelOf(MoodleActionEvent event) {
    final course = event.course;
    if (course == null) return null;
    for (final raw in [course.shortname, course.fullname]) {
      final label = stripCoursePrefix(raw);
      if (label.isNotEmpty) return label;
    }
    return null;
  }

  /// 依 timesort 相對於 [now] 分組（本週到這個星期日 24:00）。不看 overdue
  /// 旗標：那是伺服器匯出當下算的，Stale 快取顯示時早就過時。
  static List<DeadlineGroup> groupByDeadline(
      List<MoodleActionEvent> events, DateTime now) {
    final startOfTomorrow = DateTime(now.year, now.month, now.day + 1);
    // weekday：Mon=1 .. Sun=7，所以 8 - weekday 就是到下週一還有幾天。
    final startOfNextWeek =
        DateTime(now.year, now.month, now.day + (8 - now.weekday));

    final buckets = {
      for (final bucket in DeadlineBucket.values) bucket: <MoodleActionEvent>[],
    };
    final sorted = [...events]
      ..sort((a, b) => a.timesort.compareTo(b.timesort));
    for (final event in sorted) {
      final due = event.dueTime;
      final bucket = due.isBefore(now)
          ? DeadlineBucket.overdue
          : due.isBefore(startOfTomorrow)
              ? DeadlineBucket.today
              : due.isBefore(startOfNextWeek)
                  ? DeadlineBucket.thisWeek
                  : DeadlineBucket.later;
      buckets[bucket]!.add(event);
    }
    return [
      for (final bucket in DeadlineBucket.values)
        if (buckets[bucket]!.isNotEmpty)
          DeadlineGroup(bucket, buckets[bucket]!),
    ];
  }

  /// 本地時間 `MM/dd HH:mm`，跨年才補年份。刻意不跟語系走：這格是 tile 右側的
  /// 固定欄，標題要留寬，純數字兩個語系都讀得懂。
  static String formatDueTime(DateTime due, DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    final day =
        '${two(due.month)}/${two(due.day)} ${two(due.hour)}:${two(due.minute)}';
    return due.year == now.year ? day : '${due.year}/$day';
  }
}
