import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:sprintf/sprintf.dart';

part 'course_table_json.g.dart';

enum Day {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday,
  unKnown
}

enum SectionNumber {
  t_1,
  t_2,
  t_3,
  t_4,
  t_N,
  t_5,
  t_6,
  t_7,
  t_8,
  t_9,
  t_A,
  t_B,
  t_C,
  t_D,
  t_UnKnown
}

@JsonSerializable()
class CourseTableJson {
  late SemesterJson courseSemester; //課程學期資料
  String studentId;
  String studentName;
  late Map<Day, Map<SectionNumber, CourseInfoJson>> courseInfoMap;

  CourseTableJson(
      {SemesterJson? courseSemester,
      Map<Day, Map<SectionNumber, CourseInfoJson>>? courseInfoMap,
      this.studentId = "",
      this.studentName = ""}) {
    this.courseSemester = courseSemester ?? SemesterJson();
    if (courseInfoMap == null) {
      this.courseInfoMap = {};
      for (Day value in Day.values) {
        this.courseInfoMap[value] = {};
      }
    } else {
      this.courseInfoMap = courseInfoMap;
    }
  }

  int getTotalCredit() {
    int credit = 0;
    List<String> courseIdList = getCourseIdList();
    for (String courseId in courseIdList) {
      credit += getCreditByCourseId(courseId);
    }
    return credit;
  }

  int getCreditByCourseId(String courseId) {
    for (Day day in Day.values) {
      for (SectionNumber number in SectionNumber.values) {
        CourseInfoJson? courseDetail = courseInfoMap[day]![number];
        if (courseDetail != null) {
          if (courseDetail.main.course.id == courseId) {
            String creditString = courseDetail.main.course.credits;
            try {
              return double.parse(creditString).toInt();
            } catch (e) {
              return 0;
            }
          }
        }
      }
    }
    return 0;
  }

  bool isDayInCourseTable(Day day) {
    bool pass = false;
    for (SectionNumber number in SectionNumber.values) {
      if (courseInfoMap[day]![number] != null) {
        pass = true;
        break;
      }
    }
    return pass;
  }

  bool isSectionNumberInCourseTable(SectionNumber number) {
    bool pass = false;
    for (Day day in Day.values) {
      if (courseInfoMap[day]!.containsKey(number)) {
        pass = true;
        break;
      }
    }
    return pass;
  }

  factory CourseTableJson.fromJson(Map<String, dynamic> json) =>
      _$CourseTableJsonFromJson(json);

  Map<String, dynamic> toJson() => _$CourseTableJsonToJson(this);

  @override
  String toString() {
    String courseInfoString = "";
    for (Day day in Day.values) {
      for (SectionNumber number in SectionNumber.values) {
        courseInfoString += "$day  $number\n";
        courseInfoString += "${courseInfoMap[day]![number]}\n";
      }
    }
    return sprintf(
        "studentId :%s \n "
        "---------courseSemester-------- \n%s \n"
        "---------courseInfo--------     \n%s \n",
        [studentId, courseSemester.toString(), courseInfoString]);
  }

  bool get isEmpty {
    return studentId.isEmpty && courseSemester.isEmpty;
  }

  CourseInfoJson getCourseDetailByTime(Day day, SectionNumber sectionNumber) {
    return courseInfoMap[day]![sectionNumber]!;
  }

  void setCourseDetailByTime(
      Day day, SectionNumber sectionNumber, CourseInfoJson courseInfo) {
    if (day == Day.unKnown) {
      for (SectionNumber value in SectionNumber.values) {
        if (courseInfo.main.course.id.isEmpty) {
          continue;
        }
        if (!courseInfoMap[day]!.containsKey(value)) {
          courseInfoMap[day]![value] = courseInfo;
          //Log.d( day.toString() + value.toString() + courseInfo.toString() );
          break;
        }
      }
    }
    /* else if (courseInfoMap[day].containsKey(sectionNumber)) {
      throw Exception("衝堂");
    } */
    else {
      courseInfoMap[day]![sectionNumber] = courseInfo;
    }
  }

  bool setCourseDetailByTimeString(
      Day day, String sectionNumber, CourseInfoJson courseInfo) {
    bool add = false;
    for (SectionNumber value in SectionNumber.values) {
      String time = value.toString().split("_")[1];
      if (sectionNumber.contains(time)) {
        setCourseDetailByTime(day, value, courseInfo);
        add = true;
      }
    }
    return add;
  }

  SectionNumber? string2Time(String sectionNumber) {
    for (SectionNumber value in SectionNumber.values) {
      String time = value.toString().split("_")[1];
      if (sectionNumber.contains(time)) {
        return value;
      }
    }
    return null;
  }

  bool addCourseDetailByCourseInfo(CourseMainInfoJson info) {
    bool add = false;
    CourseInfoJson courseInfo = CourseInfoJson();
    for (int i = 0; i < 7; i++) {
      Day day = Day.values[i];
      String time = info.course.time[day]!;
      courseInfo.main = info;
      if (courseInfoMap[day]![string2Time(time)] != null) {
        return false;
      }
    }
    for (int i = 0; i < 7; i++) {
      Day day = Day.values[i];
      String time = info.course.time[day]!;
      courseInfo.main = info;
      add |= setCourseDetailByTimeString(day, time, courseInfo);
    }
    if (!add) {
      //代表課程沒有時間
      setCourseDetailByTime(Day.unKnown, SectionNumber.t_UnKnown, courseInfo);
    }
    return true;
  }

  List<String> getCourseIdList() {
    List<String> courseIdList = [];
    for (Day day in Day.values) {
      for (SectionNumber number in SectionNumber.values) {
        CourseInfoJson? courseInfo = courseInfoMap[day]![number];
        if (courseInfo != null) {
          String id = courseInfo.main.course.id;
          if (!courseIdList.contains(id)) {
            courseIdList.add(id);
          }
        }
      }
    }
    return courseIdList;
  }

  String? getCourseNameByCourseId(String courseId) {
    for (Day day in Day.values) {
      for (SectionNumber number in SectionNumber.values) {
        CourseInfoJson? courseDetail = courseInfoMap[day]![number];
        if (courseDetail != null) {
          if (courseDetail.main.course.id == courseId) {
            return courseDetail.main.course.name;
          }
        }
      }
    }
    return null;
  }

  CourseInfoJson? getCourseInfoByCourseName(String courseName) {
    for (Day day in Day.values) {
      for (SectionNumber number in SectionNumber.values) {
        CourseInfoJson? courseDetail = courseInfoMap[day]![number];
        if (courseDetail != null) {
          if (courseDetail.main.course.name == courseName) {
            return courseDetail;
          }
        }
      }
    }
    return null;
  }

  void removeCourseByCourseId(String courseId) {
    for (Day day in Day.values) {
      for (SectionNumber number in SectionNumber.values) {
        CourseInfoJson? courseDetail = courseInfoMap[day]![number];
        if (courseDetail != null) {
          if (courseDetail.main.course.id == courseId) {
            courseInfoMap[day]!.remove(number);
          }
        }
      }
    }
  }
}

@JsonSerializable()
class CourseInfoJson {
  late CourseMainInfoJson main = CourseMainInfoJson();

  CourseInfoJson({CourseMainInfoJson? main}) {
    this.main = main ?? CourseMainInfoJson();
  }

  bool get isEmpty {
    return main.isEmpty;
  }

/*
  @override
  bool operator ==(dynamic  o) {
    if( isEmpty || o.isEmpty || !(o is CourseInfoJson) ){
      return false;
    }else{
      return ( main.course.id == o.main.course.id );
    }
  }

  int get hashCode => hash2(main.hashCode, extra.hashCode);
*/

  @override
  String toString() {
    return sprintf("---------main--------  \n%s", [main.toString()]);
  }

  factory CourseInfoJson.fromJson(Map<String, dynamic> json) =>
      _$CourseInfoJsonFromJson(json);

  Map<String, dynamic> toJson() => _$CourseInfoJsonToJson(this);
}
