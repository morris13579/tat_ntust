import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_colors.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:get/get.dart';

class CourseTableControl {
  bool isHideSaturday = false;
  bool isHideSunday = false;
  bool isHideUnKnown = false;
  bool isHideN = false;
  bool isHideA = false;
  bool isHideB = false;
  bool isHideC = false;
  bool isHideD = false;
  CourseTableJson? courseTable;
  List<String> dayStringList = [
    R.current.Monday,
    R.current.Tuesday,
    R.current.Wednesday,
    R.current.Thursday,
    R.current.Friday,
    R.current.Saturday,
    R.current.Sunday,
    R.current.UnKnown
  ];
  List<String> timeList = [
    "08:10 - 09:00",
    "09:10 - 10:00",
    "10:20 - 11:10",
    "11:20 - 12:10",
    "12:20 - 13:10",
    "13:20 - 14:10",
    "14:20 - 15:10",
    "15:30 - 16:20",
    "16:30 - 17:20",
    "17:30 - 18:20",
    "18:25 - 19:15",
    "19:20 - 20:10",
    "20:15 - 21:05",
    "21:00 - 22:00"
  ];
  List<String> sectionStringList = [
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "10",
    "A",
    "B",
    "C",
    "D"
  ];
  static int dayLength = 8;
  static int sectionLength = 14;
  late Map<String, Color> colorMap;

  void set(CourseTableJson value) {
    courseTable = value;
    isHideSaturday = !courseTable!.isDayInCourseTable(Day.saturday);
    isHideSunday = !courseTable!.isDayInCourseTable(Day.sunday);
    isHideUnKnown = !courseTable!.isDayInCourseTable(Day.unKnown);
    isHideN = !courseTable!.isSectionNumberInCourseTable(SectionNumber.t_N);
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
      if (isHideN && i == 4) continue;
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
}
