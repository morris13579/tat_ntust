import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_department.dart';
import 'package:flutter_app/src/model/course/course_query_filter.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course/course_search_json.dart';
import 'package:flutter_app/src/model/course/course_semester.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/util/language_utils.dart';

import 'core/connector_parameter.dart';

class CourseMainInfo {
  List<CourseMainInfoJson> json;
  String studentName;

  CourseMainInfo({required this.json, required this.studentName});
}

class CourseConnector {
  // 不要再走 courseselection.ntust.edu.tw：App 對那台主機的每一次請求都停在
  // ssoam2 的登入表單，OIDC 交握不會完成，取不到任何資料。量測留在
  // NtustRepository.getSemesterList 的註解裡。
  static const queryHost = "https://querycourse.ntust.edu.tw";
  static const _courseDetailUrl = "$queryHost/querycourse/api/coursedetials";
  static const _courseSearchUrl = "$queryHost/querycourse/api/courses";
  static const _courseSemestersUrl = "$queryHost/querycourse/api/semestersinfo";
  static const _collegesUrl = "$queryHost/querycourse/api/Colleges/";
  static const _departmentsUrl = "$queryHost/querycourse/api/departments";

  static List<Day> dayEnum = [
    Day.monday,
    Day.tuesday,
    Day.wednesday,
    Day.thursday,
    Day.friday,
    Day.saturday,
    Day.sunday,
  ];

  static List<String> timeEnum = [
    "1",
    "2",
    "3",
    "4",
    "N",
    "5",
    "6",
    "7",
    "8",
    "9",
    "A",
    "B",
    "C",
    "D"
  ];

  static var dayString = ["M", "T", "W", "R", "F", "S", "U"];

  /// 把 querycourse API 的 node 欄位（例如 "M3,M4,W2"）填進 courseMain.time。
  ///
  /// **索引不合法一律跳過該 token、其餘照常。** 外層的 try 包住整個 courseIds
  /// 迴圈、catch 直接 return null，所以一個節次爆掉就會讓整張課表（或整批搜尋
  /// 結果）消失，使用者只看到「取得課表失敗」。會爆的有兩處：`dayString.indexOf`
  /// 找不到時回 -1，以及中午節次 'N' 落在 timeEnum 之外。
  ///
  /// **數字分支的 `parsed - 1` 是對的，不要「順手修正」。** Node 的節次是
  /// 「第幾格」，而 querycourse 前端那張 `1 2 3 4 5 6 7 8 9 10 A B C D` 與
  /// timeEnum 都是 14 格、逐格對位，所以 API 的 "5" 就是 timeEnum[4]。
  ///
  /// timeEnum 第 5 格寫成 `N` **只是內部代號**：`CourseTableJson.string2Time`
  /// 用 `contains` 逐字比對 [SectionNumber] 的名稱，每一格必須是單一字元，
  /// 塞得下「10」就會讓第 1 節被誤判。學校自己的叫法是第五節（12:20–13:10），
  /// 畫面上顯示什麼由 `CourseTableControl.sectionStringList` 決定，不是這裡。
  ///
  /// 那一格確實是午休：全量回應裡同一天相鄰兩格一起開課，3→4 有 1459 次、
  /// 6→7 有 1242 次，但 4→5 只有 142 次、5→6 只有 161 次。
  static void fillCourseTime(CourseMainJson courseMain, String node) {
    for (var t in node.split(",")) {
      // querycourse 真的回過小寫的 Node（課號 CS2028701 是 "w7,w8,w9"）。
      // 大小寫敏感的 indexOf 會讓那三節整批被當成 unknown day 丟掉，
      // 課表上那門課一格都不會出現，所以先正規化再查表。
      final token = t.toUpperCase();
      if (token.length < 2) {
        continue;
      }
      final dayIndex = dayString.indexOf(token.substring(0, 1));
      if (dayIndex < 0 || dayIndex >= dayEnum.length) {
        Log.e("unknown day token: $t");
        continue;
      }
      int timeIndex;
      final parsed = int.tryParse(token.substring(1));
      if (parsed != null) {
        timeIndex = parsed - 1;
      } else {
        // 查表而不是字元算術，'N' 才會正確對到 timeEnum[4]。
        timeIndex = timeEnum.indexOf(token.substring(1));
      }
      if (timeIndex < 0 || timeIndex >= timeEnum.length) {
        Log.e("unknown section token: $t");
        continue;
      }
      final day = dayEnum[dayIndex];
      courseMain.time[day] = "${courseMain.time[day]!}${timeEnum[timeIndex]} ";
    }
  }

  /// 把 querycourse `/api/courses` 的一筆結果轉成 CourseMainInfoJson。
  ///
  /// searchCourse 與 getCourseMainInfoListByCourseId 的唯一差別是課號要用
  /// 回應裡的 CourseNo 還是呼叫端查詢用的那個，用 overrideId 參數化，其餘共用。
  static CourseMainInfoJson parseCourseSearchItem(
    Map<String, dynamic> item, {
    String? overrideId,
  }) {
    final info = CourseSearchJson.fromJson(item);
    final courseMain = CourseMainJson(
      id: overrideId ?? info.courseNo,
      href: "",
      name: info.courseName,
      credits: info.creditPoint,
      // RequireOption 只有 R / E 兩個值（實測 1151 學期 1222 / 3060 門）。
      // 這裡放原始碼、不放在地化字串：model 不 import R.dart（那是上行邊）。
      category: info.requireOption,
      note: info.contents,
      hours: "",
      time: {},
    );
    for (int j = 0; j < 7; j++) {
      courseMain.time[dayEnum[j]] = "";
    }
    fillCourseTime(courseMain, info.node);
    final courseMainInfo = CourseMainInfoJson();
    courseMainInfo.classroom
        .add(ClassroomJson(name: dedupeClassroom(info.classRoomNo), href: ''));
    courseMainInfo.teacher.add(TeacherJson(name: info.courseTeacher, href: ""));
    courseMainInfo.course = courseMain;
    return courseMainInfo;
  }

  /// querycourse 的 `ClassRoomNo` **一節列一次教室**：同一間教室連上兩節就回
  /// 「公館 Ｅ101、公館 Ｅ101」。照字串印出來會看到同一間教室重複好幾次。
  ///
  /// 只去重、不改順序，也不合併不同的教室——一門課真的分兩間上課時那是資訊。
  @visibleForTesting
  static String dedupeClassroom(String raw) {
    final seen = <String>[];
    for (final part in raw.split(RegExp(r'[、,]'))) {
      final name = part.trim();
      if (name.isEmpty || seen.contains(name)) continue;
      seen.add(name);
    }
    return seen.join('、');
  }

  /// `/api/courses` 整包回應的轉換。同一個課程代碼若開在不同教室會有多筆，
  /// 這裡不合併，維持一筆一個 CourseMainInfoJson。
  static List<CourseMainInfoJson> parseSearchResult(
    List<dynamic> items, {
    String? overrideId,
  }) {
    return items
        .map((e) => parseCourseSearchItem(e as Map<String, dynamic>,
            overrideId: overrideId))
        .toList();
  }

  /// `/api/semestersinfo` 的回應轉成目前學期。
  ///
  /// 回應由新到舊排序，只取第一筆。學期字串固定四碼，前三碼是學年、
  /// 第四碼是學期別，而且不一定是數字——暑期是 "114H"。
  static List<SemesterJson> parseCourseSemesters(List<dynamic> items) {
    final courseSemester = items
        .map((e) => CourseSemesterJson.fromJson(e as Map<String, dynamic>))
        .toList();
    final semester = SemesterJson(
      year: courseSemester[0].semester.substring(0, 3),
      semester: courseSemester[0].semester.substring(3, 4),
    );
    return [semester];
  }

  /// `/api/semestersinfo` 的完整清單，由新到舊。
  ///
  /// 模擬排課要用它、而不是使用者自己的學期：自己的學期是從成績與選課紀錄
  /// 推出來的，新學期要等紀錄出現才排得進去，那時候選課早就開始了。
  ///
  /// 第四碼不一定是數字（暑期是 "114H"），所以只切字串、不做數字轉換；長度
  /// 不是四碼的就跳過，避免一筆壞資料讓整份清單消失。
  static List<SemesterJson> parseCourseSemesterList(List<dynamic> items) =>
      items
          .map((e) => CourseSemesterJson.fromJson(e as Map<String, dynamic>))
          .where((e) => e.semester.length == 4)
          .map((e) => SemesterJson(
                year: e.semester.substring(0, 3),
                semester: e.semester.substring(3, 4),
              ))
          .toList();

  /// 查不到就回空清單：呼叫端自己決定退路，這一層不丟例外也不開對話框。
  static Future<List<SemesterJson>> getCourseSemesterList() async {
    try {
      final result = await Connector.getDataByGetResponse(
          ConnectorParameter(_courseSemestersUrl));
      return parseCourseSemesterList(result.data as List);
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return [];
    }
  }

  /// `/api/coursedetials` 固定回一個陣列，要的資料在第一筆。
  static CourseExtraInfoJson parseCourseExtraInfo(List<dynamic> items) {
    return CourseExtraInfoJson.fromJson(items[0] as Map<String, dynamic>);
  }

  /// 以課號逐一向課程查詢 API 取得課程資訊。
  ///
  /// courseIds 由呼叫端提供（見 `NtustRepository.getCourseTable`）。connector
  /// 刻意不自己去拿：那會造成 connector 反向依賴上層的匯入環，並且讓網路層
  /// 間接彈出進度框與錯誤對話框。
  static Future<CourseMainInfo?> getCourseMainInfoListByCourseId(
      SemesterJson semester, List<String> courseIds) async {
    ConnectorParameter parameter;

    try {
      List<CourseMainInfoJson> courseMainInfoList = [];
      for (var courseId in courseIds) {
        Map<String, dynamic> data = {
          "CourseName": "",
          "CourseNo": courseId,
          "CourseNotes": "",
          "CourseTeacher": "",
          "Dimension": "",
          "ForeignLanguage": 0,
          "language":
              (LanguageUtils.getLangIndex() == LangEnum.zh) ? "zh" : "en",
          "OnleyNTUST": 0,
          "OnlyGeneral": 0,
          "OnlyMaster": 0,
          "OnlyNode": 0,
          "OnlyUnderGraduate": 0,
          "Semester": "${semester.year}${semester.semester}"
        };
        parameter = ConnectorParameter(_courseSearchUrl, data: data);
        var json = await Connector.getDataByPostResponse(parameter);
        if (json.data.length == 0) continue;
        // 同一個課號在不同教室／節次會回多筆，要整批收，不能只取第一筆。
        // 課號用呼叫端查的那個而不是回應裡的 CourseNo：課表要對回 courseIds。
        courseMainInfoList
            .addAll(parseSearchResult(json.data, overrideId: courseId));
      }
      var info = CourseMainInfo(
        studentName: "",
        json: courseMainInfoList,
      );
      return info;
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  static Future<CourseExtraInfoJson?> getCourseExtraInfo(
      String courseId, SemesterJson semester) async {
    try {
      ConnectorParameter parameter;
      Map<String, String> data = {
        "semester": "${semester.year}${semester.semester}",
        "course_no": courseId,
        "language": (LanguageUtils.getLangIndex() == LangEnum.zh) ? "zh" : "en"
      };
      parameter = ConnectorParameter(_courseDetailUrl);
      parameter.data = data;
      Response result = await Connector.getDataByGetResponse(parameter);
      return parseCourseExtraInfo(result.data);
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  /// 系統層級的學期 metadata，**不是**使用者的學期清單。
  ///
  /// 這個端點免憑證，所以回的是「querycourse 知道哪些學期」（實測 61 筆），
  /// 與呼叫者是誰無關。拿它當學期選單的來源會讓晚入學的學生選得到入學前的
  /// 學年。使用者自己的歷年學期只能從成績記錄推得，當前學期問 Moodle，
  /// 見 `NtustRepository.getSemesterList`。
  ///
  /// 目前無呼叫端。留著是因為它是唯一能回答「哪些學期還開放選課」
  /// （`LoginEnable`）與「哪一個是當前學期」（`CurrentSemester`）的來源。
  static Future<List<SemesterJson>?> getCourseSemesters() async {
    try {
      ConnectorParameter parameter;
      parameter = ConnectorParameter(_courseSemestersUrl);
      Response result = await Connector.getDataByGetResponse(parameter);
      return parseCourseSemesters(result.data as List);
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  /// 不屬於任何學院、但確實開課的課號前綴。
  ///
  /// `/api/departments` 把七個學院底下的系所都列了，**就是沒有這些**——體育
  /// 1151 有 139 門課，卻在系所選單裡永遠選不到。querycourse 官方前端也是這樣
  /// 繞的：體育是一個獨立分頁，硬寫 `CourseNo: "PE"` 送出去。
  ///
  /// 這裡把它們補成一個假的「其他」學院，篩選頁那條既有的兩層路徑就通了，
  /// 不必為它多做一個入口。
  static const _extraCollegeNo = '__extra';

  /// 名稱直接寫死，不走 l10n：`DepartmentJson` 的 name/engName 本來就是
  /// 伺服器給的兩份資料，`displayName` 會依語言挑一份，這裡照同一個形狀補齊。
  static const _extraDepartments = [
        DepartmentJson(
            no: 'PE', name: '體育', engName: 'Physical Education'),
      ];

  /// 學院清單。系所篩選的第一層。
  static Future<List<CollegeJson>?> getColleges() async {
    try {
      final result = await Connector.getDataByGetResponse(
          ConnectorParameter(_collegesUrl));
      return [
        ...(result.data as List)
            .map((e) => CollegeJson.fromJson(e as Map<String, dynamic>)),
        const CollegeJson(no: _extraCollegeNo, name: '其他', engName: 'Other'),
      ];
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  /// 一個學院底下的系所。`DeptNo` 就是課號前兩碼，所以拿它當 CourseNo 送出去
  /// 就是「這個系開的課」，不需要另一個查詢參數。
  static Future<List<DepartmentJson>?> getDepartments(String collegeNo) async {
    if (collegeNo == _extraCollegeNo) return _extraDepartments;
    try {
      final parameter = ConnectorParameter(_departmentsUrl)
        ..data = {"collegeNo": collegeNo};
      final result = await Connector.getDataByGetResponse(parameter);
      return (result.data as List)
          .map((e) => DepartmentJson.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  /// 課程查詢。[filter] 沒填任何條件時回空清單——`/api/courses` 對空條件會回整
  /// 個學期（實測 1151 學期 4282 門），那不是使用者要的，也不該讓它進畫面。
  ///
  /// 兩段式查詢：先當課號查，沒有結果再當課名查。這是為了讓使用者在同一個輸入
  /// 框裡打「CS3」或「離散數學」都問得到，而不必先選欄位。
  static Future<List<CourseMainInfoJson>?> searchCourse(
      SemesterJson semester, CourseQueryFilter filter) async {
    if (filter.isEmpty) return [];
    try {
      final semesterCode = "${semester.year}${semester.semester}";
      final language =
          (LanguageUtils.getLangIndex() == LangEnum.zh) ? "zh" : "en";
      var json = await _postCourses(
          filter.toRequestBody(semesterCode: semesterCode, language: language));
      // 當課號查不到、而且使用者本來就沒有指定課名時，把關鍵字改當課名再問一次。
      if (json.data.length == 0 &&
          filter.courseNo.trim().isNotEmpty &&
          filter.courseName.trim().isEmpty) {
        json = await _postCourses(filter
            .copyWith(courseNo: '', courseName: filter.courseNo)
            .toRequestBody(semesterCode: semesterCode, language: language));
      }
      return parseSearchResult(json.data);
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  static Future<Response> _postCourses(Map<String, dynamic> body) =>
      Connector.getDataByPostResponse(
          ConnectorParameter(_courseSearchUrl, data: body));
}
