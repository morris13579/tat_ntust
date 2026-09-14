import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/enum/classroom_view.dart';
import 'package:flutter_app/src/model/classroom/classroom_option.dart';
import 'package:flutter_app/src/model/classroom/classroom_usage_json.dart';
import 'package:flutter_app/src/native/classroom_bridge.dart';
import 'package:flutter_app/src/repository/ntust_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/store/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

class _FakeNtust extends NtustRepository {
  Result<List<ClassroomCampusJson>> campuses = const Ok([]);
  final Map<String, Result<ClassroomUsageJson>> usage = {};
  final List<String> calls = [];

  @override
  Future<Result<List<ClassroomCampusJson>>> getClassroomCampuses() async =>
      campuses;

  @override
  Future<Result<ClassroomUsageJson>> getClassroomUsage({
    required String campusCode,
    required DateTime date,
    String? buildingCode,
  }) async {
    calls.add('$buildingCode ${date.month}/${date.day}');
    return usage[buildingCode] ?? const Failed(FetchFailed());
  }
}

/// 一個字元一節：`.` 空、`C` 有課、`B` 借出。
ClassroomRowJson room(String name, String slots) => ClassroomRowJson(
      name: name,
      slots: [
        for (final c in slots.split(''))
          switch (c) {
            'C' => const ClassroomSlotJson(course: '微積分', teacher: '王老師'),
            'B' => const ClassroomSlotJson(marked: true),
            _ => const ClassroomSlotJson(),
          },
      ],
    );

ClassroomUsageJson usageOf(List<ClassroomRowJson> rooms) => ClassroomUsageJson(
      campusCode: 'HQ',
      buildingCode: 'TR',
      date: DateTime(2026, 9, 14),
      rooms: rooms,
      fetchedAt: DateTime(2026, 9, 14, 10, 36),
    );

/// 原生版空教室拿到的東西：開場選哪一棟、這一節哪些空著、空到幾點、樓層怎麼分。
void main() {
  setUpAll(() async => loadTestL10n());

  late _FakeNtust ntust;
  final monday = DateTime(2026, 9, 14, 10, 30);

  setUp(() {
    resetAppStatics();
    AuthSession.instance = FakeAuthSession();
    ntust = _FakeNtust();
    NtustRepository.instance = ntust;
  });

  tearDown(() => NtustRepository.instance = NtustRepository());

  group('開場', () {
    const hq = ClassroomCampusJson(code: 'HQ', name: '校本部', buildings: [
      ClassroomOptionJson(code: 'IB', name: '國際大樓'),
      ClassroomOptionJson(code: 'TR', name: '研揚大樓'),
      ClassroomOptionJson(code: 'EE', name: '電資館'),
    ]);
    const hh = ClassroomCampusJson(code: 'HH', name: '華夏校區', buildings: [
      ClassroomOptionJson(code: 'H1', name: '華夏一館'),
    ]);

    test('沒記住的大樓時開在大樓最多的校區，研揚排第一個；現在是第幾節', () async {
      ntust.campuses = const Ok([hh, hq]);

      final setup = await ClassroomBridge(clock: () => monday).start();

      expect((setup.campusCode, setup.buildingCode), ('HQ', 'TR'));
      expect(
          setup.campuses[1].buildings.map((b) => b.code), ['TR', 'IB', 'EE']);
      expect((setup.now.date, setup.now.section), ('2026-09-14', 2));
      expect(setup.sections, hasLength(14));
      expect(setup.layout, ClassroomLayout.list);
    });

    test('記住的大樓與檢視還在就用它們', () async {
      ntust.campuses = const Ok([hh, hq]);
      final bridge = ClassroomBridge(clock: () => monday);
      await bridge.rememberBuilding('H1');
      await bridge.rememberLayout(ClassroomLayout.day);

      final setup = await bridge.start();

      expect((setup.campusCode, setup.buildingCode), ('HH', 'H1'));
      expect(setup.layout, ClassroomLayout.day);
      expect(await SettingsStore.instance.classroomView, ClassroomView.day);
    });
  });

  group('一棟一天', () {
    test('空到幾點、下一堂、樓層分組與一整天檢視的排序', () async {
      ntust.usage['TR'] = Ok(usageOf([
        room('TR-301', '.....C........'),
        room('TR-201', '..C...........'),
        room('TR-502', '..............'),
        room('TR-B01', '...B..........'),
      ]));

      final day = await ClassroomBridge()
          .day('HQ', 'TR', '2026-09-14', 2, ClassroomRun.any, false);

      expect((day.roomCount, day.freeCount, day.closed), (4, 3, false));
      expect(day.floors.map((f) => f.floor), [3, 5, null]);
      final tr301 = day.floors.first.rooms.single;
      expect((
        tr301.freeSections,
        tr301.freeUntil,
        tr301.nextBusyAt,
        tr301.nextCourse
      ), (
        3,
        '13:10',
        '13:20',
        '微積分'
      ));
      final basement = day.floors.last.rooms.single;
      expect((basement.freeSections, basement.nextIsBooking), (1, true));
      expect(day.free.map((r) => r.name), ['TR-502', 'TR-301', 'TR-B01']);
      expect(day.busy.map((r) => r.name), ['TR-201']);
      expect(day.free.first.freeAllDay, isTrue);
    });

    test('連續節數篩選只影響清單，摘要的空教室數不變', () async {
      ntust.usage['TR'] = Ok(usageOf([
        room('TR-301', '.....C........'),
        room('TR-502', '..............'),
        room('TR-B01', '...B..........'),
      ]));
      final bridge = ClassroomBridge();

      final three = await bridge.day(
          'HQ', 'TR', '2026-09-14', 2, ClassroomRun.threeSections, false);
      final allDay = await bridge.day(
          'HQ', 'TR', '2026-09-14', 2, ClassroomRun.allDay, false);

      expect(three.floors.expand((f) => f.rooms).map((r) => r.name),
          ['TR-301', 'TR-502']);
      expect(
          allDay.floors.expand((f) => f.rooms).map((r) => r.name), ['TR-502']);
      expect(three.freeCount, 3);
    });

    test('同一棟同一天只抓一次；重新整理或換一天才再抓', () async {
      ntust.usage['TR'] = Ok(usageOf([room('TR-301', '..............')]));
      final bridge = ClassroomBridge();

      await bridge.day('HQ', 'TR', '2026-09-14', 2, ClassroomRun.any, false);
      await bridge.day('HQ', 'TR', '2026-09-14', 5, ClassroomRun.any, false);
      await bridge.day('HQ', 'TR', '2026-09-14', 5, ClassroomRun.any, true);
      await bridge.day('HQ', 'TR', '2026-09-15', 5, ClassroomRun.any, false);

      expect(ntust.calls, ['TR 9/14', 'TR 9/14', 'TR 9/15']);
    });

    test('站台一列都沒回是非上課日，不是錯誤；抓不到才是錯誤', () async {
      ntust.usage['TR'] = Ok(usageOf([]));
      final bridge = ClassroomBridge();

      final closed = await bridge.day(
          'HQ', 'TR', '2026-09-13', 0, ClassroomRun.any, false);
      final failed = await bridge.day(
          'HQ', 'IB', '2026-09-13', 0, ClassroomRun.any, false);

      expect((closed.closed, closed.error), (true, null));
      expect((failed.closed, failed.error == null, failed.roomCount),
          (false, false, 0));
    });
  });
}
