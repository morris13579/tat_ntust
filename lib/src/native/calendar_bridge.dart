import 'dart:io';

import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart'
    show MoodleWebApiConnector;
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_calendar_action_events.dart';
import 'package:flutter_app/src/native/course_moodle_bridge.dart';
import 'package:flutter_app/src/repository/calendar_repository.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/util/school_calendar_utils.dart';
import 'package:flutter_app/src/util/upcoming_event_utils.dart';

/// 原生版的行事曆頁。學校行事曆與 Moodle 待辦照 `CalendarController`；待辦怎麼分組照
/// `UpcomingEventUtils.groupByDeadline`，組名、日期與剩餘時間由原生端依語系排。
class CalendarBridge implements TatCalendarApi {
  CalendarBridge({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// 最近一次拿到的待辦。開某一筆時要它的原始網址。
  List<MoodleActionEvent> _events = [];

  static void install() => TatCalendarApi.setUp(CalendarBridge());

  @override
  Future<List<CalendarDay>> schoolCalendar(bool refresh) async {
    final result =
        await CalendarRepository.instance.getCalendarFile(forceUpdate: refresh);
    final path = result.dataOrNull;
    if (path == null) return [];
    final days = SchoolCalendarUtils.parse(await File(path).readAsLines());
    return [
      for (final MapEntry(key: day, value: events) in days.entries)
        CalendarDay(date: _dateKey(day), events: events),
    ];
  }

  @override
  Future<UpcomingEvents> upcoming(bool refresh) async {
    final result =
        await MoodleRepository.instance.getUpcomingEvents(background: !refresh);
    _events = result.dataOrNull ?? const [];
    return UpcomingEvents(
      groups: [
        for (final group
            in UpcomingEventUtils.groupByDeadline(_events, _clock()))
          UpcomingGroup(
            kind: DeadlineKind.values.byName(group.bucket.name),
            events: [for (final event in group.events) _event(event)],
          ),
      ],
      error: switch (result) {
        Failed(:final reason) => reason.message,
        _ => null,
      },
      notice: switch (result) {
        Stale(:final reason) => reason.message,
        _ => null,
      },
      signedIn: AuthSession.instance.isSignedIn,
    );
  }

  @override
  Future<WebLink?> eventLink(int eventId) async {
    final event = _events.where((e) => e.id == eventId).firstOrNull;
    if (event == null) return null;
    final raw = event.openUrl;
    final url = await MoodleWebApiConnector.autologinUrl(raw);
    return WebLink(url: url, fallbackUrl: url == raw ? null : raw);
  }

  @override
  bool isAutologinScript(String url) =>
      MoodleWebApiConnector.isAutologinScript(Uri.tryParse(url));

  @override
  Future<ModuleTarget?> eventTarget(int eventId) async {
    final event = _events.where((e) => e.id == eventId).firstOrNull;
    final target = event == null ? null : UpcomingEventUtils.targetOf(event);
    if (target == null) return null;
    final sections =
        (await MoodleRepository.instance.getCourseDirectory(target.courseId))
            .dataOrNull;
    final module = sections == null
        ? null
        : UpcomingEventUtils.moduleOf(sections, target.cmid);
    if (module == null) return null;
    return ModuleTarget(
      courseId: target.courseId,
      courseName: target.courseName,
      module: CourseMoodleBridge.moduleItem(module),
    );
  }

  static UpcomingEvent _event(MoodleActionEvent event) => UpcomingEvent(
        id: event.id,
        title: event.title,
        course: UpcomingEventUtils.courseLabelOf(event),
        due: event.dueTime.millisecondsSinceEpoch,
        module: event.modulename,
      );

  static String _dateKey(DateTime day) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${day.year}-${two(day.month)}-${two(day.day)}';
  }
}
