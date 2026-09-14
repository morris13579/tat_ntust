import 'dart:io';

import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_calendar_action_events.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/util/moodle_course_name_utils.dart';
import 'package:flutter_app/src/native/calendar_bridge.dart';
import 'package:flutter_app/src/repository/calendar_repository.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/util/school_calendar_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

const _ics = [
  'BEGIN:VCALENDAR',
  'VERSION:2.0',
  'PRODID:-//NTUST//Calendar//TW',
  'BEGIN:VEVENT',
  'DTSTART;VALUE=DATE:20260913',
  'SUMMARY:1.開學  2.加退選開始',
  'END:VEVENT',
  'BEGIN:VEVENT',
  'DTSTART;VALUE=DATE:20260928',
  'SUMMARY:12、教師節 放假',
  'END:VEVENT',
  'END:VCALENDAR',
];

class _FakeCalendar extends CalendarRepository {
  _FakeCalendar(this.path);

  final String? path;
  final List<bool> forced = [];

  @override
  Future<Result<String>> getCalendarFile({bool forceUpdate = false}) async {
    forced.add(forceUpdate);
    final path = this.path;
    return path == null ? const Failed(FetchFailed()) : Ok(path);
  }
}

class _FakeMoodle extends MoodleRepository {
  Result<List<MoodleActionEvent>> next = const Ok([]);
  final List<bool> backgrounds = [];
  Result<List<MoodleCoreCourseGetContents>> directory =
      const Failed(FetchFailed());

  @override
  Future<Result<List<MoodleCoreCourseGetContents>>> getCourseDirectory(
          String courseId) async =>
      directory;

  @override
  Future<Result<List<MoodleActionEvent>>> getUpcomingEvents(
      {bool background = false}) async {
    backgrounds.add(background);
    return next;
  }
}

MoodleActionEvent event(int id, DateTime due,
        {String? module, String url = ''}) =>
    MoodleActionEvent(
      id: id,
      name: '待辦 $id',
      modulename: module,
      timesort: due.millisecondsSinceEpoch ~/ 1000,
      url: url,
    );

/// 原生版行事曆拿到的東西。.ics 怎麼拆、待辦怎麼分組、點下去開哪個網址都在 Dart，
/// Swift 只照著畫——這些壞了，原生版會把逾期的作業排進「之後」，或開錯網址。
void main() {
  setUpAll(() async => loadTestL10n());

  late _FakeMoodle moodle;

  setUp(() {
    resetAppStatics();
    AuthSession.instance = FakeAuthSession();
    moodle = _FakeMoodle();
    MoodleRepository.instance = moodle;
  });

  tearDown(() {
    MoodleRepository.instance = MoodleRepository();
    CalendarRepository.instance = CalendarRepository();
  });

  group('學校行事曆', () {
    test('.ics：同一天的幾件事拆開、編號前綴剝掉', () {
      final days = SchoolCalendarUtils.parse(_ics);

      expect(days[DateTime.utc(2026, 9, 13)], ['開學', '加退選開始']);
      expect(days[DateTime.utc(2026, 9, 28)], ['教師節放假']);
    });

    test('日期字串給原生端對格子；重新整理才強制重抓', () async {
      final dir = Directory.systemTemp.createTempSync('tat_calendar');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/calendar.ics')
        ..writeAsStringSync(_ics.join('\n'));
      final repo = _FakeCalendar(file.path);
      CalendarRepository.instance = repo;

      final days = await CalendarBridge().schoolCalendar(false);
      await CalendarBridge().schoolCalendar(true);

      expect(days.map((d) => d.date), ['2026-09-13', '2026-09-28']);
      expect(days.first.events, ['開學', '加退選開始']);
      expect(repo.forced, [false, true]);
    });

    test('沒有檔案時回空清單', () async {
      CalendarRepository.instance = _FakeCalendar(null);

      expect(await CalendarBridge().schoolCalendar(false), isEmpty);
    });
  });

  group('待辦', () {
    test('依截止時間分組、組內照時間排；進頁是背景載入', () async {
      final wednesday = DateTime(2026, 9, 9, 10);
      moodle.next = Ok([
        event(4, DateTime(2026, 9, 20, 9)),
        event(1, DateTime(2026, 9, 8, 12)),
        event(2, DateTime(2026, 9, 9, 18), module: 'assign'),
        event(3, DateTime(2026, 9, 12, 23, 59)),
        event(5, DateTime(2026, 10, 3, 9)),
      ]);

      final upcoming =
          await CalendarBridge(clock: () => wednesday).upcoming(false);

      expect(moodle.backgrounds, [true]);
      expect(upcoming.groups.map((g) => g.kind), [
        DeadlineKind.overdue,
        DeadlineKind.today,
        DeadlineKind.thisWeek,
        DeadlineKind.later,
      ]);
      expect(upcoming.groups.last.events.map((e) => e.id), [4, 5]);
      final today = upcoming.groups[1].events.single;
      expect((today.module, today.due),
          ('assign', DateTime(2026, 9, 9, 18).millisecondsSinceEpoch));
      expect(upcoming.error, isNull);
    });

    test('失敗時帶訊息與登入狀態；重新整理不是背景載入', () async {
      AuthSession.instance = FakeAuthSession(isSignedIn: false);
      moodle.next = const Failed(NotSignedIn());

      final upcoming = await CalendarBridge().upcoming(true);

      expect(moodle.backgrounds, [false]);
      expect(upcoming.groups, isEmpty);
      expect(upcoming.error, isNotNull);
      expect(upcoming.signedIn, isFalse);
    });

    test('開一筆：不是 Moodle 的網址原樣開、沒有退路；找不到回 null', () async {
      moodle.next = Ok([
        event(7, DateTime(2026, 9, 20), url: 'https://www.ntust.edu.tw/p/1'),
      ]);
      final bridge = CalendarBridge();
      await bridge.upcoming(false);

      final link = await bridge.eventLink(7);

      expect((link?.url, link?.fallbackUrl),
          ('https://www.ntust.edu.tw/p/1', null));
      expect(await bridge.eventLink(99), isNull);
    });

    test('只有停在 autologin.php 本身才算鑰匙被拒', () {
      final bridge = CalendarBridge();
      const host = MoodleWebApiConnector.host;

      expect(
          bridge.isAutologinScript(
              '$host${MoodleWebApiConnector.autologinScriptPath}?key=x'),
          isTrue);
      expect(bridge.isAutologinScript('$host/course/view.php?id=1'), isFalse);
    });
  });

  group('在 App 內開', () {
    MoodleActionEvent assignment(String modname) => MoodleActionEvent(
          id: 1,
          name: 'HW1',
          modulename: modname,
          timesort: DateTime(2026, 9, 10).millisecondsSinceEpoch ~/ 1000,
          url: 'https://moodle2.ntust.edu.tw/mod/$modname/view.php?id=77',
          course: MoodleActionEventCourse(
              fullname: '資料結構', shortname: '資料結構', idnumber: '1151CS3039701'),
        );

    test('作業：課號從 idnumber 來，模組照網址裡的 cmid 對到，instance 是作業自己的 id', () async {
      moodle.next = Ok([assignment('assign')]);
      moodle.directory = Ok([
        MoodleCoreCourseGetContents(modules: [
          Modules(id: 76, instance: 1, modname: 'resource', name: '講義'),
          Modules(id: 77, instance: 54556, modname: 'assign', name: 'HW1'),
        ]),
      ]);
      final bridge = CalendarBridge(clock: () => DateTime(2026, 9, 9));
      await bridge.upcoming(false);

      final target = (await bridge.eventTarget(1))!;

      expect(target.courseId,
          MoodleCourseNameUtils.courseIdOfIdNumber('1151CS3039701'));
      expect(target.module.kind, CourseModuleKind.assign);
      expect(target.module.instance, 54556);
    });

    test('App 內開不了的模組或抓不到模組表：回 null，照舊開網頁', () async {
      moodle.next = Ok([assignment('lesson')]);
      moodle.directory = Ok([
        MoodleCoreCourseGetContents(modules: [
          Modules(id: 77, instance: 9, modname: 'lesson', name: 'HW1'),
        ]),
      ]);
      final bridge = CalendarBridge(clock: () => DateTime(2026, 9, 9));
      await bridge.upcoming(false);
      expect(await bridge.eventTarget(1), isNull);

      moodle.next = Ok([assignment('assign')]);
      moodle.directory = const Failed(FetchFailed());
      await bridge.upcoming(false);
      expect(await bridge.eventTarget(1), isNull);
    });
  });
}
