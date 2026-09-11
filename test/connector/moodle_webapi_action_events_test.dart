import 'dart:convert';
import 'dart:io';

import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_calendar_action_events.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/reset_statics.dart';

/// `core_calendar_get_action_events_by_timesort` 這一份回應的本機判讀規格，
/// 以及翻頁。
///
/// 判讀抽成公開純函式 `actionEventsOf` / `actionEventsPageOf`（與
/// `userGradesOf` 同慣例）；翻頁那段用 `wsPost` 換掉傳輸層，不碰網路。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> fixture;

  setUpAll(() {
    fixture = json.decode(File(
            'test/fixtures/moodle/core_calendar_get_action_events_by_timesort.json')
        .readAsStringSync()) as Map<String, dynamic>;
  });

  setUp(resetAppStatics);
  tearDown(resetAppStatics);

  /// [count] 筆 id 從 [firstId] 起連號的事件，`lastid` 照伺服器規則帶著。
  Map<String, dynamic> page(int firstId, int count) => {
        'events': [
          for (var i = 0; i < count; i++)
            {'id': firstId + i, 'name': 'e${firstId + i}', 'timesort': i},
        ],
        'firstid': count == 0 ? null : firstId,
        'lastid': count == 0 ? null : firstId + count - 1,
      };

  /// 依序回 [responses]；回傳的清單記錄每一次送出的參數。
  List<ConnectorParameter> stubWs(List<dynamic> responses) {
    final captured = <ConnectorParameter>[];
    final queue = List<dynamic>.from(responses);
    MoodleWebApiConnector.wsPost = (parameter) async {
      captured.add(parameter);
      return queue.removeAt(0);
    };
    return captured;
  }

  group('actionEventsOf', () {
    test('正常回應剝出 events', () {
      final events = MoodleWebApiConnector.actionEventsOf(fixture);

      expect(events, isNotNull);
      expect(events!.map((e) => e.id), [90211, 90212]);
    });

    test('name 與 activityname 的 HTML 實體會被還原（format_string 會寫成 &amp;）', () {
      final events = MoodleWebApiConnector.actionEventsOf({
        'events': [
          {
            'id': 1,
            'name': 'C &amp; D 到期',
            'activityname': 'C &amp; D',
            'timesort': 1,
          },
          {'id': 2, 'name': 'x &lt; y', 'activityname': null, 'timesort': 2},
        ],
        'firstid': 1,
        'lastid': 2,
      })!;

      expect(events[0].name, 'C & D 到期');
      expect(events[0].activityname, 'C & D');
      expect(events[0].title, 'C & D');
      expect(events[1].name, 'x < y');
      expect(events[1].activityname, isNull, reason: 'null 不該被還原成字串');
    });

    test(
        'course 的 fullname / shortname 也還原（course_summary_exporter 的 PARAM_TEXT）',
        () {
      final events = MoodleWebApiConnector.actionEventsOf({
        'events': [
          {
            'id': 1,
            'name': 'x',
            'timesort': 1,
            'course': {
              'fullname': 'Design &amp; Analysis',
              'shortname': '115.1【AT1】Design &amp; Analysis',
            },
          },
        ],
      })!;

      expect(events.single.course!.fullname, 'Design & Analysis');
      expect(events.single.course!.shortname, '115.1【AT1】Design & Analysis');
    });

    test('空的 events 是合法結果，回空清單而不是 null', () {
      // 沒有作業的學生不該看到錯誤頁。
      final events = MoodleWebApiConnector.actionEventsOf(
          {'events': <dynamic>[], 'firstid': null, 'lastid': null});

      expect(events, isNotNull);
      expect(events, isEmpty);
    });

    test('形狀不對一律回 null', () {
      // captive portal 回的 HTML。
      expect(
          MoodleWebApiConnector.actionEventsOf('<html>login</html>'), isNull);
      // 沒被 _callWs 攔到的錯誤包（理論上不會發生，但判讀不該依賴那一層）。
      expect(
          MoodleWebApiConnector.actionEventsOf({
            'exception': 'moodle_exception',
            'errorcode': 'invalidtoken',
            'message': 'Invalid token',
          }),
          isNull);
      // events 不是 List。
      expect(MoodleWebApiConnector.actionEventsOf({'events': 'x'}), isNull);
      expect(MoodleWebApiConnector.actionEventsOf(null), isNull);
      expect(MoodleWebApiConnector.actionEventsOf(<dynamic>[]), isNull);
    });
  });

  group('actionEventsTimesortFrom', () {
    test('是當天 00:00 往前 14 天的 Unix 秒（本地時間，跨月照樣正確）', () {
      final from = MoodleWebApiConnector.actionEventsTimesortFrom(
          DateTime(2026, 9, 6, 15, 30));

      expect(from, DateTime(2026, 8, 23).millisecondsSinceEpoch ~/ 1000);
    });

    test('跨年', () {
      final from = MoodleWebApiConnector.actionEventsTimesortFrom(
          DateTime(2027, 1, 5, 8));

      expect(from, DateTime(2026, 12, 22).millisecondsSinceEpoch ~/ 1000);
    });
  });

  group('nextActionEventsPage', () {
    MoodleCoreCalendarActionEvents parse(Map<String, dynamic> json) =>
        MoodleCoreCalendarActionEvents.fromJson(json);

    test('回滿一頁才有下一頁，游標是這一頁的 lastid', () {
      expect(MoodleWebApiConnector.nextActionEventsPage(parse(page(1, 50)), 50),
          50);
      expect(MoodleWebApiConnector.nextActionEventsPage(parse(page(1, 49)), 50),
          isNull);
      expect(MoodleWebApiConnector.nextActionEventsPage(parse(page(1, 0)), 50),
          isNull);
    });

    test('滿頁但伺服器沒給 lastid 就停，不會拿 null 去翻', () {
      final full = page(1, 50)..['lastid'] = null;
      expect(
          MoodleWebApiConnector.nextActionEventsPage(parse(full), 50), isNull);
    });
  });

  group('getActionEvents 翻頁', () {
    test('第一頁沒滿就只打一次，也不帶 aftereventid', () async {
      final captured = stubWs([page(1, 3)]);

      final events = await MoodleWebApiConnector.getActionEvents(
          timesortFrom: 100, limitnum: 50);

      expect(events!.map((e) => e.id), [1, 2, 3]);
      expect(captured, hasLength(1));
      final data = captured.single.data as Map;
      expect(data['wsfunction'], 'core_calendar_get_action_events_by_timesort');
      expect(data['timesortfrom'], '100');
      expect(data['limitnum'], '50');
      expect(data['limittononsuspendedevents'], '1');
      expect(data.containsKey('aftereventid'), isFalse);
      expect(data.containsKey('timesortto'), isFalse);
    });

    test('回滿一頁就帶 aftereventid 再翻，直到不滿為止', () async {
      final captured = stubWs([page(1, 50), page(51, 50), page(101, 7)]);

      final events = await MoodleWebApiConnector.getActionEvents(
          timesortFrom: 100, limitnum: 50);

      expect(events, hasLength(107));
      expect(events!.first.id, 1);
      expect(events.last.id, 107);
      expect(captured, hasLength(3));
      expect((captured[1].data as Map)['aftereventid'], '50');
      expect((captured[2].data as Map)['aftereventid'], '100');
      // 每一頁的視窗起點都一樣，游標只靠 aftereventid。
      for (final c in captured) {
        expect((c.data as Map)['timesortfrom'], '100');
      }
    });

    test('最多翻 actionEventsMaxPages 頁，再多就放掉', () async {
      final pages = [
        for (var i = 0; i < MoodleWebApiConnector.actionEventsMaxPages + 2; i++)
          page(1 + i * 50, 50),
      ];
      final captured = stubWs(pages);

      final events = await MoodleWebApiConnector.getActionEvents(
          timesortFrom: 100, limitnum: 50);

      expect(captured, hasLength(MoodleWebApiConnector.actionEventsMaxPages));
      expect(
          events, hasLength(MoodleWebApiConnector.actionEventsMaxPages * 50));
    });

    test('第一頁失敗就是失敗（null）', () async {
      stubWs([
        {
          'exception': 'moodle_exception',
          'errorcode': 'invalidtoken',
          'message': 'Invalid token',
        }
      ]);

      expect(
          await MoodleWebApiConnector.getActionEvents(timesortFrom: 1), isNull);
    });

    test('第二頁失敗就回第一頁的：少幾筆最遠的，好過整份清單不見', () async {
      stubWs([
        page(1, 50),
        {'exception': 'moodle_exception', 'message': 'boom'},
      ]);

      final events = await MoodleWebApiConnector.getActionEvents(
          timesortFrom: 1, limitnum: 50);

      expect(events, hasLength(50));
    });

    test('翻到空頁（剛好整除）回前面累積的', () async {
      stubWs([page(1, 50), page(51, 0)]);

      final events = await MoodleWebApiConnector.getActionEvents(
          timesortFrom: 1, limitnum: 50);

      expect(events, hasLength(50));
    });
  });

  group('常數', () {
    test('function 名稱與伺服器上限', () {
      expect(MoodleWebApiConnector.actionEventsFunction,
          'core_calendar_get_action_events_by_timesort');
      // calendar/classes/local/api.php：limitnum 超過 50 直接回錯。
      expect(MoodleWebApiConnector.actionEventsLimit, 50);
      expect(MoodleWebApiConnector.actionEventsLookbackDays, 14);
      expect(MoodleWebApiConnector.actionEventsMaxPages, 4);
    });
  });
}
