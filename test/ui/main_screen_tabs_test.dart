import 'dart:io';

import 'package:flutter_app/src/controller/main_page/main_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// 底部導覽列的三份清單必須逐項對齊：`MainScreen.items`（圖示與標籤）、
/// `MainScreen._pages`（畫面）與 [MainTab]（分析事件的 screen name）。三者
/// 只靠索引對應，錯位不會有任何編譯錯誤，只會讓使用者按「成績」跳到行事曆、
/// 讓報表把課表記成成績。
///
/// 用掃原始碼而不是 widget test：把 MainScreen 真的 pump 起來會連帶建出課表頁，
/// 那需要整套登入與網路替身，成本遠高於這裡要守的東西。
void main() {
  final source = File('lib/ui/screen/main_screen.dart').readAsStringSync();

  /// 取出 `name` 那個清單常值裡，以逗號分隔的項目。
  List<String> listItems(String name, String open, String close) {
    final start = source.indexOf(name);
    expect(start, isNot(-1), reason: '找不到 $name');
    final from = source.indexOf(open, start);
    final to = source.indexOf(close, from);
    expect(to, isNot(-1), reason: '$name 的清單沒有結尾');
    return source
        .substring(from + open.length, to)
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && !e.startsWith('//'))
        .toList();
  }

  test('只有四個分頁，而且順序固定', () {
    final pages = listItems('static const _pages', '[', '];');
    expect(pages, [
      'CourseTablePage()',
      'CalendarPage(openInApp: RouteUtils.tryOpenUpcomingEvent)',
      'ScoreViewerPage()',
      'OtherPage()',
    ]);
  });

  test('MainTab 的個數與順序要跟分頁清單一致', () {
    final pages = listItems('static const _pages', '[', '];');
    expect(MainTab.values.length, pages.length);
    // 名稱會直接送進 Analytics 當 screen name，改名等於改掉既有的報表維度。
    expect(MainTab.values.map((e) => e.name).toList(),
        ['courseTable', 'calendar', 'score', 'other']);
  });

  test('導覽列的圖示與標籤照同一個順序排', () {
    final items = listItems('get items =>', '[', '];');
    // 一項是 `{"icon": X, "name": Y}`，逗號切完會變成兩半。
    expect(items.length, MainTab.values.length * 2);
    final labels = <String>[];
    for (var i = 1; i < items.length; i += 2) {
      labels.add(items[i].split(':').last.trim().replaceAll('}', ''));
    }
    expect(labels, [
      'R.current.titleCourse',
      'R.current.calendar',
      'R.current.titleScore',
      'R.current.titleMore',
    ]);
  });

  test('資訊系統已經不在底部導覽列上', () {
    expect(source.contains('SubSystemPage'), isFalse);
  });

  test('選取狀態的顏色與尺寸交給 NavigationBarThemeData', () {
    // 在 NavigationDestination 裡自己塗色會蓋掉主題，看起來像主題壞掉。
    expect(source.contains('onSecondaryContainer'), isFalse);
    expect(source.contains('Get.theme'), isFalse);
  });
}
