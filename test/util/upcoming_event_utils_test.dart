import 'package:flutter_app/src/model/moodle_webapi/moodle_core_calendar_action_events.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/util/upcoming_event_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// 待辦清單的純函式：課名前綴、依截止時間分組、時間格式。
void main() {
  int secondsOf(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

  MoodleActionEvent at(int id, DateTime due) =>
      MoodleActionEvent(id: id, name: 'e$id', timesort: secondsOf(due));

  group('stripCoursePrefix', () {
    test('去掉 NTUST 的 <學年>.<學期>【課號】 前綴', () {
      expect(
          UpcomingEventUtils.stripCoursePrefix('115.1【AT1001301】軟體工程'), '軟體工程');
    });

    test('沒有「.」與多餘空白也認得', () {
      expect(
          UpcomingEventUtils.stripCoursePrefix('1151【AT1001301】 軟體工程'), '軟體工程');
      expect(UpcomingEventUtils.stripCoursePrefix('  115.H【AT1001301】暑期課 '),
          '暑期課');
    });

    test('沒有前綴就原樣回傳', () {
      expect(UpcomingEventUtils.stripCoursePrefix('軟體工程'), '軟體工程');
    });

    test('去完是空字串就退回原字串，永遠不回空', () {
      expect(UpcomingEventUtils.stripCoursePrefix('115.1【AT1001301】'),
          '115.1【AT1001301】');
      expect(UpcomingEventUtils.stripCoursePrefix(''), '');
    });
  });

  group('courseLabelOf', () {
    MoodleActionEvent withCourse(String shortname, String fullname) =>
        MoodleActionEvent(
          course:
              MoodleActionEventCourse(shortname: shortname, fullname: fullname),
        );

    test('shortname 優先', () {
      expect(
          UpcomingEventUtils.courseLabelOf(
              withCourse('115.1【AT1001301】軟工', '115.1【AT1001301】軟體工程')),
          '軟工');
    });

    test('shortname 空的退 fullname', () {
      expect(
          UpcomingEventUtils.courseLabelOf(
              withCourse('', '115.1【AT1001301】軟體工程')),
          '軟體工程');
    });

    test('兩者皆空回 null；站台事件沒有 course 也回 null', () {
      expect(UpcomingEventUtils.courseLabelOf(withCourse('', '')), isNull);
      expect(UpcomingEventUtils.courseLabelOf(MoodleActionEvent()), isNull);
    });
  });

  group('groupByDeadline', () {
    // 2026-09-09 是星期三。
    final now = DateTime(2026, 9, 9, 10, 0);

    test('分界：逾期 / 今天 / 本週（到星期日 24:00）/ 之後', () {
      final groups = UpcomingEventUtils.groupByDeadline([
        at(1, now.subtract(const Duration(seconds: 1))),
        at(2, now),
        at(3, DateTime(2026, 9, 9, 23, 59)),
        at(4, DateTime(2026, 9, 10, 0, 0)),
        at(5, DateTime(2026, 9, 13, 23, 59)),
        at(6, DateTime(2026, 9, 14, 0, 0)),
      ], now);

      expect(groups.map((g) => g.bucket), [
        DeadlineBucket.overdue,
        DeadlineBucket.today,
        DeadlineBucket.thisWeek,
        DeadlineBucket.later,
      ]);
      expect(groups[0].events.map((e) => e.id), [1]);
      expect(groups[1].events.map((e) => e.id), [2, 3],
          reason: '正好是現在不算逾期；今天 23:59 還是今天');
      expect(groups[2].events.map((e) => e.id), [4, 5],
          reason: '明天 00:00 進本週；星期日 23:59 也是本週');
      expect(groups[3].events.map((e) => e.id), [6], reason: '下週一 00:00 就是之後');
    });

    test('空的組不出現，順序照 enum', () {
      final groups = UpcomingEventUtils.groupByDeadline([
        at(1, DateTime(2026, 9, 20)),
        at(2, DateTime(2026, 9, 1)),
      ], now);

      expect(groups.map((g) => g.bucket),
          [DeadlineBucket.overdue, DeadlineBucket.later]);
    });

    test('輸入亂序，組內依 timesort 升冪', () {
      final groups = UpcomingEventUtils.groupByDeadline([
        at(3, DateTime(2026, 9, 12, 12)),
        at(1, DateTime(2026, 9, 10, 8)),
        at(2, DateTime(2026, 9, 11, 9)),
      ], now);

      expect(groups.single.bucket, DeadlineBucket.thisWeek);
      expect(groups.single.events.map((e) => e.id), [1, 2, 3]);
    });

    test('今天是星期日時本週組是空的，下週六算之後', () {
      final sunday = DateTime(2026, 9, 13, 10, 0);
      final groups = UpcomingEventUtils.groupByDeadline([
        at(1, DateTime(2026, 9, 13, 23, 59)),
        at(2, DateTime(2026, 9, 19, 12)),
      ], sunday);

      expect(groups.map((g) => g.bucket),
          [DeadlineBucket.today, DeadlineBucket.later]);
    });

    test('空輸入回空清單', () {
      expect(UpcomingEventUtils.groupByDeadline([], now), isEmpty);
    });

    test('只看 timesort：伺服器匯出時還沒逾期，快取拿出來時早就過了也要落在逾期', () {
      final stale = MoodleActionEvent(
        id: 1,
        timesort: secondsOf(DateTime(2026, 9, 8, 23, 59)),
      );
      final groups = UpcomingEventUtils.groupByDeadline([stale], now);

      expect(groups.single.bucket, DeadlineBucket.overdue);
    });
  });

  group('formatDueTime', () {
    final now = DateTime(2026, 9, 9, 10, 0);

    test('同一年：MM/dd HH:mm，補零', () {
      expect(UpcomingEventUtils.formatDueTime(DateTime(2026, 9, 3, 7, 5), now),
          '09/03 07:05');
      expect(
          UpcomingEventUtils.formatDueTime(DateTime(2026, 12, 25, 23, 59), now),
          '12/25 23:59');
    });

    test('跨年才加年份：清單沒有 timesortto，「之後」可以排到下個學年', () {
      expect(
          UpcomingEventUtils.formatDueTime(DateTime(2027, 1, 15, 23, 59), now),
          '2027/01/15 23:59');
      expect(
          UpcomingEventUtils.formatDueTime(DateTime(2025, 12, 31, 8, 0), now),
          '2025/12/31 08:00');
    });
  });

  group('targetOf', () {
    MoodleActionEvent event({
      String? modulename = 'assign',
      int? instance = 55123,
      String url = 'https://moodle2.ntust.edu.tw/mod/assign/view.php?id=354220',
      String idnumber = '1151AT1001301',
      String fullname = '115.1【資工系】CS3039701 網路生活與應用程式',
      String shortname = '[TaiwanTech] 網路生活與應用程式 (1151CS3039701)',
      bool withCourse = true,
    }) =>
        MoodleActionEvent(
          id: 1,
          name: '作業一 到期',
          activityname: '作業一',
          modulename: modulename,
          instance: instance,
          timesort: 1757952000,
          url: url,
          course: withCourse
              ? MoodleActionEventCourse(
                  fullname: fullname,
                  shortname: shortname,
                  idnumber: idnumber,
                )
              : null,
        );

    test('課號來自 idnumber，cmid 來自網址', () {
      for (final name in ['assign', 'quiz', 'forum']) {
        final target = UpcomingEventUtils.targetOf(event(modulename: name));
        expect(target, isNotNull, reason: name);
        expect(target!.cmid, 354220);
        expect(target.courseId, 'AT1001301');
      }
    });

    test('idnumber 是空的就從課名認課號——【】裡是系所，課號在後面', () {
      final target = UpcomingEventUtils.targetOf(event(idnumber: ''));
      expect(target?.courseId, 'CS3039701');
    });

    test('【】裡直接放課號的課也認得', () {
      final target = UpcomingEventUtils.targetOf(event(
        idnumber: '',
        fullname: '115.1【AT1001301】軟體工程',
        shortname: '115.1【AT1001301】軟體工程',
      ));
      expect(target?.courseId, 'AT1001301');
    });

    test('課名只剩簡稱時，從結尾括號的 1151CS3039701 認課號', () {
      final target = UpcomingEventUtils.targetOf(event(
        idnumber: '',
        fullname: '網路生活與應用程式',
      ));
      expect(target?.courseId, 'CS3039701');
    });

    test('站台事件：沒有課，回 null', () {
      expect(
          UpcomingEventUtils.targetOf(
              event(modulename: null, instance: null, withCourse: false)),
          isNull);
    });

    test('網址認不出 cmid 就退回 instance；兩個都沒有才回 null', () {
      expect(UpcomingEventUtils.targetOf(event(url: ''))?.cmid, 55123);
      expect(
          UpcomingEventUtils.targetOf(event(url: '', instance: null)), isNull);
      expect(UpcomingEventUtils.targetOf(event(url: '', instance: 0)), isNull);
    });

    test('九個字母的全大寫英文字不是課號，不能拿去配課', () {
      // NETWORKED 剛好九碼、又是 2-3 個大寫字母開頭；假課號會被 matchCourseId
      // 的課名模糊比對配到別門課。
      expect(
          UpcomingEventUtils.targetOf(event(
            idnumber: '',
            fullname: '115.1【電資學院】NETWORKED 概論',
            shortname: 'NETWORKED 概論',
          )),
          isNull);
    });

    test('課號認不出來就回 null，不能拿系所或亂數去查課', () {
      expect(
          UpcomingEventUtils.targetOf(
              event(idnumber: '', fullname: '軟體工程', shortname: '軟體工程')),
          isNull);
    });

    test('拿的是 cmid 不是 instance：NTUST 這兩個欄位對不起來', () {
      // 實測站台：期中報告的事件 instance 回 354220（那是 cmid），
      // assign 自己的 id 是 54556。所以只信網址上的 id。
      expect(UpcomingEventUtils.targetOf(event())!.cmid, 354220);
      expect(UpcomingEventUtils.cmidOf(event()), 354220);
    });

    group('moduleOf', () {
      List<MoodleCoreCourseGetContents> sections() => [
            MoodleCoreCourseGetContents(
              id: 1,
              name: '一般',
              modules: [
                Modules(id: 345802, instance: 27979, modname: 'forum'),
                Modules(id: 354220, instance: 54556, modname: 'assign'),
                Modules(id: 999001, instance: 12, modname: 'feedback'),
              ],
            ),
          ];

      test('cmid 對到哪一個就拿哪一個的 instance', () {
        final module = UpcomingEventUtils.moduleOf(sections(), 354220);
        expect(module?.modname, 'assign');
        expect(module?.instance, 54556);
      });

      test('沒有 App 內頁面的模組不回傳，對不到的 cmid 也是', () {
        expect(UpcomingEventUtils.moduleOf(sections(), 999001), isNull);
        expect(UpcomingEventUtils.moduleOf(sections(), 424242), isNull);
        expect(UpcomingEventUtils.moduleOf([], 354220), isNull);
      });
    });
  });
}
