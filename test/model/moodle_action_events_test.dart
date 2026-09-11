import 'dart:convert';
import 'dart:io';

import 'package:flutter_app/src/model/moodle_webapi/moodle_core_calendar_action_events.dart';
import 'package:flutter_test/flutter_test.dart';

/// `core_calendar_get_action_events_by_timesort` 回應的解析契約。
///
/// fixture 的形狀照 MOODLE_405_STABLE 的 events_exporter / event_exporter /
/// event_action_exporter / course_summary_exporter：帶著所有 TAT 不建模的欄位
/// （icon、subscription、editurl、instance、eventtype、overdue…），解析時必須
/// 被忽略而不是拋。
void main() {
  late Map<String, dynamic> fixture;

  setUpAll(() {
    fixture = json.decode(File(
            'test/fixtures/moodle/core_calendar_get_action_events_by_timesort.json')
        .readAsStringSync()) as Map<String, dynamic>;
  });

  group('fixture 解析', () {
    test('兩筆事件、lastid、未建模的欄位不會拋', () {
      final parsed = MoodleCoreCalendarActionEvents.fromJson(fixture);

      expect(parsed.events, hasLength(2));
      expect(parsed.lastid, 90212);
    });

    test('模組事件：每個保留的欄位都對得上', () {
      final e = MoodleCoreCalendarActionEvents.fromJson(fixture).events[0];

      expect(e.id, 90211);
      expect(e.name, '作業一 到期');
      expect(e.activityname, '作業一');
      expect(e.modulename, 'assign');
      expect(e.timesort, 1757952000);
      expect(
          e.url, 'https://moodle2.ntust.edu.tw/mod/assign/view.php?id=55123');

      final course = e.course!;
      expect(course.fullname, '115.1【AT1001301】軟體工程');
      expect(course.shortname, '115.1【AT1001301】軟體工程');

      final action = e.action!;
      expect(action.name, '新增繳交');
      expect(action.url, endsWith('action=editsubmission'));
      expect(action.actionable, isTrue);
    });

    test('站台事件：沒有 course key、沒有活動名，標題退回事件名', () {
      final e = MoodleCoreCalendarActionEvents.fromJson(fixture).events[1];

      expect(e.course, isNull);
      expect(e.activityname, isNull);
      expect(e.modulename, isNull);
      expect(e.title, e.name);
      expect(e.openUrl, e.action!.url);
    });
  });

  group('getters', () {
    test('title：活動名優先，null 或空白才退回事件名', () {
      expect(MoodleActionEvent(name: 'A 到期', activityname: 'A').title, 'A');
      expect(MoodleActionEvent(name: 'A 到期').title, 'A 到期');
      expect(MoodleActionEvent(name: 'A 到期', activityname: '  ').title, 'A 到期');
    });

    test('openUrl：action.url 優先，沒有 action 或 url 為空才退回活動頁', () {
      final withAction = MoodleActionEvent(
        url: 'https://m/view',
        action: MoodleActionEventAction(url: 'https://m/do'),
      );
      expect(withAction.openUrl, 'https://m/do');

      expect(
          MoodleActionEvent(url: 'https://m/view').openUrl, 'https://m/view');
      expect(
        MoodleActionEvent(
          url: 'https://m/view',
          action: MoodleActionEventAction(url: ''),
        ).openUrl,
        'https://m/view',
      );
    });

    test('dueTime 是 timesort 換成本地時間', () {
      final e = MoodleActionEvent(timesort: 1757952000);
      expect(e.dueTime, DateTime.fromMillisecondsSinceEpoch(1757952000 * 1000));
    });
  });

  group('寬鬆解析', () {
    test('欄位缺席一律退回預設值', () {
      final e = MoodleActionEvent.fromJson({'id': 1});

      expect(e.id, 1);
      expect(e.name, '');
      expect(e.timesort, 0);
      expect(e.url, '');
      expect(e.course, isNull);
      expect(e.action, isNull);
    });

    test('欄位明確為 null 也退回預設值', () {
      final e = MoodleActionEvent.fromJson({
        'id': null,
        'name': null,
        'course': null,
        'action': null,
      });

      expect(e.id, 0);
      expect(e.name, '');
      expect(e.course, isNull);
    });

    test('PARAM_BOOL 容忍 1/0 與 "1"/"0"', () {
      bool actionable(dynamic v) =>
          MoodleActionEventAction.fromJson({'actionable': v}).actionable;
      expect(actionable(true), isTrue);
      expect(actionable(1), isTrue);
      expect(actionable('1'), isTrue);
      expect(actionable('true'), isTrue);
      expect(actionable(0), isFalse);
      expect(actionable('0'), isFalse);
      expect(actionable(null), isFalse);
    });

    test('空物件不會拋', () {
      final parsed = MoodleCoreCalendarActionEvents.fromJson({});
      expect(parsed.events, isEmpty);
      expect(parsed.lastid, isNull);
    });
  });

  group('快取路徑', () {
    test('toJson 只有畫面讀的 key：eventtype / timestart / overdue 不進快取', () {
      final e = MoodleCoreCalendarActionEvents.fromJson(fixture).events[0];

      // instance 與 course.idnumber 要進快取：待辦點下去要靠它們決定開哪一頁。
      expect(e.toJson().keys, {
        'id',
        'name',
        'activityname',
        'modulename',
        'instance',
        'timesort',
        'url',
        'course',
        'action',
      });
      expect(e.course!.toJson().keys, {'fullname', 'shortname', 'idnumber'});
      expect(e.action!.toJson().keys, {'name', 'url', 'actionable'});
    });

    test('toJson → jsonEncode → jsonDecode → fromJson 保留標題、網址與課名', () {
      // CacheStore.write 就是 jsonEncode 一整包 List，這裡走同一條路。
      final original = MoodleCoreCalendarActionEvents.fromJson(fixture).events;
      final encoded = json.encode(original);
      final decoded = (json.decode(encoded) as List)
          .map((e) =>
              MoodleActionEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      expect(decoded, hasLength(2));
      for (var i = 0; i < original.length; i++) {
        expect(decoded[i].id, original[i].id);
        expect(decoded[i].title, original[i].title);
        expect(decoded[i].openUrl, original[i].openUrl);
        expect(decoded[i].timesort, original[i].timesort);
        expect(decoded[i].course?.shortname, original[i].course?.shortname);
        expect(decoded[i].action?.actionable, original[i].action?.actionable);
      }
      // 只有 course 存在時才會有巢狀物件；explicitToJson 要把它變成 Map。
      final firstJson = (json.decode(encoded) as List).first as Map;
      expect(firstJson['course'], isA<Map>());
      expect(firstJson['action'], isA<Map>());
      expect((json.decode(encoded) as List)[1]['course'], isNull);
    });

    test('舊快取 blob 帶著已移除的欄位（overdue、instance…）照樣解得開', () {
      final e = MoodleActionEvent.fromJson({
        'id': 1,
        'name': 'x',
        'instance': 5,
        'eventtype': 'due',
        'timestart': 1,
        'timesort': 1,
        'overdue': '1',
        'course': {'id': 2, 'shortname': 's', 'idnumber': 'n'},
        'action': {'name': 'a', 'url': 'u', 'itemcount': 1, 'actionable': 1},
      });
      expect(e.course!.shortname, 's');
      expect(e.action!.actionable, isTrue);
    });
  });
}
