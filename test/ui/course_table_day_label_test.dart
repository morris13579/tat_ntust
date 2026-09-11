import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_time.dart';
import 'package:flutter_app/src/util/course_table_control.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_app/generated/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_l10n.dart';

/// 星期標籤的來源字串。
///
/// 第八格（Day.unKnown）要用兩個語系都有翻譯的 titleOther（其它／Other）。
/// 換成沒有翻譯的 key，課表會多出一整欄沒有標題的格子，getTime() 也會吐出
/// 開頭是底線、沒有星期名稱的字串。
void main() {
  setUpAll(() async {
    await loadTestL10n();
  });

  group('CourseTableControl 的星期標籤', () {
    test('八欄標題都不是空字串（舊行為：第八欄是空字串，畫成無標題的欄）', () {
      final control = CourseTableControl();

      expect(control.dayStringList.length, CourseTableControl.dayLength);
      for (int i = 0; i < CourseTableControl.dayLength; i++) {
        expect(
          control.getDayString(i).trim(),
          isNotEmpty,
          reason: '第 $i 欄（${Day.values[i]}）沒有標題',
        );
      }
    });

    test('切換語言之後標籤跟著換——不可以凍在建立時的語言', () async {
      // dayStringList 存成欄位的話，整張課表換了語言，只有這排星期不會換。
      final control = CourseTableControl();
      await S.load(const Locale('zh', 'TW'));
      final zh = control.getDayString(0);

      await S.load(const Locale('en'));
      final en = control.getDayString(0);

      await S.load(const Locale('zh', 'TW'));
      expect(en, isNot(zh), reason: '同一個 control 實例的標籤沒有跟著語言換');
      expect(control.getDayString(0), zh, reason: '換回去也要跟著換回去');
    });

    test('第八欄對應 Day.unKnown，索引與 Day 列舉一致', () {
      final control = CourseTableControl();

      // getDayIntList 用硬編碼的 7 來判斷 unKnown 欄，所以順序是 load-bearing。
      expect(Day.values.length, CourseTableControl.dayLength);
      expect(Day.unKnown.index, 7);
      expect(control.getDayString(7), isNot(control.getDayString(6)));
    });
  });

  group('courseTimeString()', () {
    test('沒有星期的課不會輸出開頭是底線的時間字串（舊行為："_1 2 3 "）', () {
      final info = CourseMainInfoJson(
        course: CourseMainJson(
          id: 'X1',
          name: '無星期課程',
          time: {Day.unKnown: '1 2 3 '},
        ),
      );

      final time = courseTimeString(info.course.time);

      expect(time, isNotEmpty);
      expect(time.startsWith('_'), isFalse, reason: '星期名稱不見了，只剩分隔用的底線');
      expect(time, contains('_1 2 3 '));
    });

    test('一般星期的輸出格式維持「星期_節次 」不變', () {
      final info = CourseMainInfoJson(
        course: CourseMainJson(
          id: 'X2',
          name: '星期一的課',
          time: {Day.monday: '1 2 '},
        ),
      );

      // loadTestL10n 預設載 zh_TW，intl_zh_TW.arb 的 Monday 是「一」。
      expect(courseTimeString(info.course.time), '一_1 2  ');
    });
  });
}
