import 'package:flutter_app/src/config/section_time.dart';
import 'package:flutter_app/src/model/classroom/classroom_usage_json.dart';
import 'package:flutter_app/src/util/classroom_availability.dart';
import 'package:flutter_test/flutter_test.dart';

/// 借用系統給的是「每一間教室的一整天」，這裡驗的是把它翻成
/// 「這一節空不空、可以待多久、幾點被趕」這段翻譯。
void main() {
  /// `busy` 裡的索引有課，其餘空著。`booked` 是站台標了記號但沒有課名的格子。
  ClassroomRowJson room(String name,
      {List<int> busy = const [], List<int> booked = const []}) {
    return ClassroomRowJson(
      name: name,
      slots: List.generate(
        ClassroomUsageJson.sectionCount,
        (i) => busy.contains(i)
            ? const ClassroomSlotJson(course: '微積分', teacher: '呂老師')
            : booked.contains(i)
                ? const ClassroomSlotJson(marked: true)
                : const ClassroomSlotJson(),
      ),
    );
  }

  ClassroomUsageJson usage(List<ClassroomRowJson> rooms) => ClassroomUsageJson(
        campusCode: 'HQ',
        buildingCode: 'IB',
        date: DateTime(2026, 9, 9),
        rooms: rooms,
        fetchedAt: DateTime(2026, 9, 9, 10, 36),
      );

  ClassroomVacancy only(ClassroomRowJson r, int section) =>
      ClassroomAvailability.of(usage([r]), section).single;

  group('空到幾點', () {
    test('連續空堂算到最後一節的下課時刻', () {
      // 第 3 節（索引 2）起空著，索引 6 有課 → 空到索引 5 的下課 14:10。
      final v = only(room('IB-501', busy: [6, 7, 8]), 2);
      expect(v.isFree, isTrue);
      expect(v.freeSections, 4);
      expect(v.freeUntil!.end, '14:10');
      expect(v.nextBusySection, 6);
      expect(v.nextBusyAt!.start, '14:20');
    });

    test('中午那一節也是空堂的一部分，不會被跳過', () {
      // 索引 4 是 12:20–13:10。它常常沒課，但它確實是一格，
      // 連續節數少算一節的話「空到幾點」會早一小時。
      final v = only(room('IB-501', busy: [5]), 3);
      expect(v.freeSections, 2, reason: '索引 3 與 4');
      expect(v.freeUntil!.end, '13:10');
    });

    test('到放學都空著就沒有下一堂', () {
      final v = only(room('IB-501', busy: [0]), 1);
      expect(v.nextBusySection, isNull);
      expect(v.nextBusySlot, isNull);
      expect(v.freeSections, ClassroomUsageJson.sectionCount - 1);
      expect(v.freeUntil!.end, sectionTimes.last.end);
    });

    test('那一節本來就有人用', () {
      final v = only(room('IB-401', busy: [2]), 2);
      expect(v.isFree, isFalse);
      expect(v.freeSections, 0);
      expect(v.freeUntil, isNull);
    });
  });

  group('整天空著', () {
    test('一節課都沒有', () {
      expect(only(room('IB-507'), 0).freeSections,
          ClassroomUsageJson.sectionCount);
      // freeSections 是「從查的那一節起」算的，所以從第三節問只會是 12；
      // 「整天空著」看的是整列，與問哪一節無關。
      final v = only(room('IB-507'), 2);
      expect(v.isFreeAllDay, isTrue);
      expect(v.freeSections, ClassroomUsageJson.sectionCount - 2);
    });

    test('只是這一節之後都空著，不算整天空著', () {
      // 早上上過課的教室下午空著是「空到放學」，不是「今天沒有課」。
      // 兩者混為一談的話畫面會對已經用過的教室說「今天沒有安排」。
      final v = only(room('IB-501', busy: [0, 1]), 2);
      expect(v.isFreeAllDay, isFalse);
      expect(v.nextBusySection, isNull);
    });
  });

  group('已借出', () {
    test('下一個佔用是借出而不是排課', () {
      final v = only(room('IB-508', booked: [7, 8]), 2);
      expect(v.nextBusySection, 7);
      expect(v.nextIsBooking, isTrue);
      expect(v.freeUntil!.end, '15:10');
    });

    test('有課名就是排課，不是借出', () {
      final v = only(room('IB-501', busy: [7]), 2);
      expect(v.nextIsBooking, isFalse);
    });

    test('被借出的那一節不算空堂', () {
      final v = only(room('IB-508', booked: [2]), 2);
      expect(v.isFree, isFalse);
    });
  });

  group('樓層', () {
    test('房號的第一碼就是樓層', () {
      expect(only(room('IB-501'), 0).floor, 5);
      expect(only(room('TR-209'), 0).floor, 2);
      expect(only(room('IB-602-1'), 0).floor, 6);
      expect(only(room('E1-306'), 0).floor, 3);
    });

    test('解不出來回 null，而且那些教室不會被丟掉', () {
      // 站台換了編號格式時，使用者該看到「多了一組沒有標題的教室」，
      // 不是「教室憑空變少」。
      final rooms = [room('IB-501'), room('怪教室'), room('IB-12')];
      final grouped =
          ClassroomAvailability.byFloor(ClassroomAvailability.of(usage(rooms), 0));
      expect(grouped.keys.toList(), [5, null]);
      expect(grouped[null]!.length, 2);
    });

    test('樓層由小到大，沒有樓層的排最後', () {
      final rooms = [room('IB-601'), room('IB-301'), room('X'), room('IB-501')];
      final grouped =
          ClassroomAvailability.byFloor(ClassroomAvailability.of(usage(rooms), 0));
      expect(grouped.keys.toList(), [3, 5, 6, null]);
    });
  });

  group('連續節數篩選', () {
    test('依連續節數過濾', () {
      final v2 = only(room('A', busy: [4]), 2); // 連 2 節
      final v4 = only(room('B', busy: [6]), 2); // 連 4 節
      expect(ClassroomRunFilter.any.accepts(v2), isTrue);
      expect(ClassroomRunFilter.twoSections.accepts(v2), isTrue);
      expect(ClassroomRunFilter.threeSections.accepts(v2), isFalse);
      expect(ClassroomRunFilter.threeSections.accepts(v4), isTrue);
    });

    test('「整天」看的是整天沒課，不是連續節數', () {
      // 從第一節起空到放學的教室連續節數是滿的，但它今天上過課——
      // 用節數判斷的話「整天」會把它也列進來。
      final allDay = only(room('C'), 0);
      final longRun = only(room('D', busy: [13]), 0);
      expect(ClassroomRunFilter.allDay.accepts(allDay), isTrue);
      expect(ClassroomRunFilter.allDay.accepts(longRun), isFalse);
      expect(ClassroomRunFilter.threeSections.accepts(longRun), isTrue);
    });
  });

  group('一整天檢視的排序', () {
    test('空得最久的排前面，同長度照編號', () {
      final list = ClassroomAvailability.of(
          usage([
            room('IB-509', busy: [3]),
            room('IB-501'),
            room('IB-401', busy: [3]),
          ]),
          2);
      expect(ClassroomAvailability.byRunLength(list).map((e) => e.room.name),
          ['IB-501', 'IB-401', 'IB-509']);
    });
  });

  group('現在是第幾節', () {
    test('上課中', () {
      final (date, section) =
          ClassroomAvailability.nowSection(DateTime(2026, 9, 9, 10, 36));
      expect(section, 2, reason: '10:20–11:10 是索引 2');
      expect(date, DateTime(2026, 9, 9));
    });

    test('下課時間算下一節', () {
      // 正在走去找教室的人要的是待會那一節，不是剛結束的那一節。
      final (_, section) =
          ClassroomAvailability.nowSection(DateTime(2026, 9, 9, 11, 15));
      expect(section, 3, reason: '11:10 已下課，11:20 那一節才是要找的');
    });

    test('上學前是第一節', () {
      final (_, section) =
          ClassroomAvailability.nowSection(DateTime(2026, 9, 9, 6, 0));
      expect(section, 0);
    });

    test('最後一節下課之後，「現在」是明天第一節', () {
      // 深夜的「現在」沒有意義，停在今天最後一節只會給一份已經過去的答案。
      final (date, section) =
          ClassroomAvailability.nowSection(DateTime(2026, 9, 9, 23, 30));
      expect(date, DateTime(2026, 9, 10));
      expect(section, 0);
    });
  });
}
