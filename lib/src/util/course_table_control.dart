import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/section_time.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/util/course_table_conflict.dart';
import 'package:flutter_app/src/util/ui_utils.dart';

/// 課表用的星期名稱，索引對齊 [Day] 的順序。
///
/// 第八個是 Day.unKnown，收容查不到星期的課（見 course_time.dart）。
/// 兩個 ARB 都沒有「未知」這一類的 key，硬補一個等於多一組要維護的翻譯；
/// titleOther（其它／Other）兩個語系都有翻譯，語意也正好是「不屬於前面七天」。
/// 這是 titleOther 在 App 內唯一與「更多」無關的讀取點，換掉它之前先看這裡。
List<String> courseDayNames() => [
      R.current.Monday,
      R.current.Tuesday,
      R.current.Wednesday,
      R.current.Thursday,
      R.current.Friday,
      R.current.Saturday,
      R.current.Sunday,
      R.current.titleOther,
    ];

/// 把一門課的上課時間組成「星期_節次 」的顯示字串。
///
/// 放在這裡而不是 model 上：model 為了組在地化字串 import `R.dart` 會是
/// `tool/deps.py` 的 model -> config 上行邊。
String courseTimeString(Map<Day, String> time) {
  final names = courseDayNames();
  final buffer = StringBuffer();
  for (final day in time.keys) {
    if (time[day]!.replaceAll(RegExp('[|\n]'), "").isEmpty) continue;
    buffer.write("${names[day.index]}_${time[day]} ");
  }
  return buffer.toString();
}

class CourseTableControl {
  bool isHideSaturday = false;
  bool isHideSunday = false;
  bool isHideUnKnown = false;
  bool isHideNoon = false;
  bool isHideA = false;
  bool isHideB = false;
  bool isHideC = false;
  bool isHideD = false;
  CourseTableJson? courseTable;

  /// getter 而不是欄位：這個物件是 CourseController 的欄位，而 GetX 的
  /// controller 不會被 forceAppUpdate 重建，存成欄位會凍在建立時的語言。
  List<String> get dayStringList => courseDayNames();
  /// 節次的顯示時間，與 [sectionStringList] 逐格對位。
  ///
  /// 時刻本身在 `lib/src/config/section_time.dart`，那是全 App 唯一一份
  /// ——空教室要算「空到幾點」，需要分開的起訖，不能只有這串顯示字串。
  List<String> get timeList =>
      sectionTimes.map((t) => "${t.start} - ${t.end}").toList();

  /// 畫面上顯示的節次名稱，與 [timeList] 逐格對位。
  ///
  /// **這是顯示用的，不是內部代號。** 內部那一套（[SectionNumber] 的名稱、
  /// `CourseConnector.timeEnum`、分享碼的 `1234N56789ABCD`）為了讓
  /// `CourseTableJson.string2Time` 能逐字比對，每一格必須是單一字元，所以中午
  /// 那格在內部叫 `N`。但臺科自己不是這樣叫的：中午 12:20–13:10 就是**第五
  /// 節**，之後依序往下，17:30 那格是第十節——與 querycourse 前端那張
  /// `1…10 A…D` 的表一致。兩套不會相等，別再把它們斷言成同一個列表。
  List<String> get sectionStringList => sectionLabels;

  static int dayLength = 8;
  static int sectionLength = 14;
  late Map<String, Color> colorMap;

  void set(CourseTableJson value) {
    courseTable = value;
    isHideSaturday = !courseTable!.isDayInCourseTable(Day.saturday);
    isHideSunday = !courseTable!.isDayInCourseTable(Day.sunday);
    isHideUnKnown = !courseTable!.isDayInCourseTable(Day.unKnown);
    isHideNoon = !courseTable!.isSectionNumberInCourseTable(SectionNumber.t_N);
    isHideA = (!courseTable!.isSectionNumberInCourseTable(SectionNumber.t_A));
    isHideB = (!courseTable!.isSectionNumberInCourseTable(SectionNumber.t_B));
    isHideC = (!courseTable!.isSectionNumberInCourseTable(SectionNumber.t_C));
    isHideD = (!courseTable!.isSectionNumberInCourseTable(SectionNumber.t_D));
    isHideA &= (isHideB & isHideC & isHideD);
    isHideB &= (isHideC & isHideD);
    isHideC &= isHideD;
    _initColorList();
  }

  List<int> get getDayIntList {
    List<int> intList = [];
    for (int i = 0; i < dayLength; i++) {
      if (isHideSaturday && i == 5) continue;
      if (isHideSunday && i == 6) continue;
      if (isHideUnKnown && i == 7) continue;
      intList.add(i);
    }
    return intList;
  }

  CourseInfoJson? getCourseInfo(int intDay, int intNumber) {
    Day day = Day.values[intDay];
    SectionNumber number = SectionNumber.values[intNumber];
    //Log.d( day.toString()  + " " + number.toString() );
    return courseTable?.courseInfoMap[day]?[number];
  }

  Color getCourseInfoColor(int intDay, int intNumber) {
    CourseInfoJson? courseInfo = getCourseInfo(intDay, intNumber);
    for (String key in colorMap.keys) {
      if (courseInfo != null) {
        if (key == courseInfo.main.course.id) {
          return colorMap[key]!;
        }
      }
    }
    return Colors.white;
  }

  void _initColorList() {
    colorMap = {};
    List<String> courseInfoList = courseTable!.getCourseIdList();
    int colorCount = courseInfoList.length;

    final colors = UIUtils.generateHarmoniousColors(12)..shuffle();

    for (int i = 0; i < colorCount; i++) {
      colorMap[courseInfoList[i]] = colors[i % colors.length];
    }
  }

  List<int> get getSectionIntList {
    List<int> intList = [];
    for (int i = 0; i < sectionLength; i++) {
      if (isHideNoon && i == 4) continue;
      if (isHideA && i == 10) continue;
      if (isHideB && i == 11) continue;
      if (isHideC && i == 12) continue;
      if (isHideD && i == 13) continue;
      intList.add(i);
    }
    return intList;
  }

  String getDayString(int day) {
    return dayStringList[day];
  }

  String getTimeString(int time) {
    return timeList[time];
  }

  String getSectionString(int section) {
    return sectionStringList[section];
  }

  /// 一門課的上課時段，「三 8　四 3·4」。
  ///
  /// `courseTimeString` 給的是「三_8 四_34 」那種內部格式，直接印出來會看到
  /// 底線，而且連在一起的節次分不出是 34 還是 3 跟 4。
  String slotLabel(CourseMainInfoJson course) {
    final days = <String>[];
    for (final day in CourseTableConflict.days) {
      final sections = CourseTableConflict.sectionsOf(course.course.time[day]);
      if (sections.isEmpty) continue;
      final labels = sections.map((s) => getSectionString(s.index)).join('·');
      days.add('${getDayString(day.index)} $labels');
    }
    return days.join('　');
  }
}
