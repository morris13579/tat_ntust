import 'dart:convert';

import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/store/extra_table_store.dart';
import 'package:flutter_app/src/store/key_value_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// 草稿與他人課表的持久化。這兩份刻意不進 `course_table_list`。
void main() {
  late InMemoryKeyValueStore store;
  late ExtraTableStore subject;

  setUp(() {
    store = InMemoryKeyValueStore();
    subject = ExtraTableStore(store);
  });

  CourseTableJson tableOf(String id) {
    final table = CourseTableJson(
      courseSemester: SemesterJson(year: '115', semester: '1'),
      studentId: 'B11000001',
    );
    table.addCourseDetailByCourseInfo(CourseMainInfoJson(
      course: CourseMainJson(
        id: id,
        name: id,
        time: {for (final day in Day.values) day: day == Day.monday ? '3' : ''},
      ),
    ));
    return table;
  }

  ExtraTable draftOf(String id, {String label = '加退選草稿', int at = 1000}) =>
      ExtraTable(
        id: id,
        label: label,
        table: tableOf('CS3003302'),
        savedAt: DateTime.fromMillisecondsSinceEpoch(at),
      );

  group('草稿', () {
    test('存了讀得回來，課表內容也還在', () async {
      await subject.upsertDraft(draftOf('d1'));
      final reloaded = ExtraTableStore(store);
      await reloaded.load();
      final draft = reloaded.findDraft('d1');
      expect(draft, isNotNull);
      expect(draft!.label, '加退選草稿');
      expect(draft.table.getCourseIdList(), ['CS3003302']);
    });

    test('同一個 id 再存一次是取代，不是變兩筆', () async {
      await subject.upsertDraft(draftOf('d1', label: '舊'));
      await subject.upsertDraft(draftOf('d1', label: '新'));
      expect(subject.drafts, hasLength(1));
      expect(subject.drafts.single.label, '新');
    });

    test('同一學期可以有好幾份草稿——主鍵是 id 不是學期', () async {
      await subject.upsertDraft(draftOf('d1', label: 'A'));
      await subject.upsertDraft(draftOf('d2', label: 'B'));
      expect(subject.drafts, hasLength(2));
    });

    test('新到舊排序', () async {
      await subject.upsertDraft(draftOf('old', label: '舊', at: 1000));
      await subject.upsertDraft(draftOf('new', label: '新', at: 9000));
      expect(subject.drafts.map((e) => e.id).toList(), ['new', 'old']);
    });

    test('刪掉就不見了', () async {
      await subject.upsertDraft(draftOf('d1'));
      await subject.removeDraft('d1');
      expect(subject.drafts, isEmpty);
      expect(subject.findDraft('d1'), isNull);
    });
  });

  group('他人課表', () {
    test('payload 存得下來——那是真相來源，之後要靠它重新還原', () async {
      await subject.upsertShared(ExtraTable(
        id: 's1',
        label: 'B10000000',
        table: tableOf('CS3003302'),
        savedAt: DateTime.fromMillisecondsSinceEpoch(1000),
        payload: 'TAT21151B10000000CS3003302.434',
      ));
      final reloaded = ExtraTableStore(store);
      await reloaded.load();
      expect(
          reloaded.findShared('s1')?.payload, 'TAT21151B10000000CS3003302.434');
    });

    test('草稿與他人課表是兩份清單，不會互相污染', () async {
      await subject.upsertDraft(draftOf('d1'));
      await subject.upsertShared(draftOf('s1'));
      expect(subject.drafts.map((e) => e.id).toList(), ['d1']);
      expect(subject.shared.map((e) => e.id).toList(), ['s1']);
      expect(store.raw.containsKey(ExtraTableStore.draftListKey), isTrue);
      expect(store.raw.containsKey(ExtraTableStore.sharedListKey), isTrue);
    });

    test('兩份都不寫進 course_table_list', () async {
      await subject.upsertDraft(draftOf('d1'));
      await subject.upsertShared(draftOf('s1'));
      expect(store.raw.containsKey('course_table_list'), isFalse);
    });
  });

  group('壞資料', () {
    test('一筆解不開不會讓整份清單消失', () async {
      await store.writeStringList(ExtraTableStore.draftListKey, [
        'not json at all',
        json.encode(draftOf('good').toJson()),
      ]);
      await subject.load();
      expect(subject.drafts.map((e) => e.id).toList(), ['good']);
    });

    test('沒有這個 key 時是空清單，不是拋例外', () async {
      await subject.load();
      expect(subject.drafts, isEmpty);
      expect(subject.shared, isEmpty);
    });
  });

  test('clear 把兩份都清掉', () async {
    await subject.upsertDraft(draftOf('d1'));
    await subject.upsertShared(draftOf('s1'));
    await subject.clear();
    expect(subject.drafts, isEmpty);
    expect(subject.shared, isEmpty);

    final reloaded = ExtraTableStore(store);
    await reloaded.load();
    expect(reloaded.drafts, isEmpty);
    expect(reloaded.shared, isEmpty);
  });
}
