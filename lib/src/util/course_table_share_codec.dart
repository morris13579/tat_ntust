import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/util/course_table_conflict.dart';

/// QR 上那一份課表：學號、學期，以及每一門課的課號與上課時間。
class SharedTablePayload {
  const SharedTablePayload({
    required this.studentId,
    required this.year,
    required this.semester,
    required this.courses,
  });

  final String studentId;

  /// 學年三碼（`115`）。
  final String year;

  /// 學期一碼（`1`、`2`、`H`）。
  final String semester;

  final List<SharedCourse> courses;

  String get semesterCode => '$year$semester';
}

/// 一門課：課號，加上它佔到的每一個 (星期, 節次)。
class SharedCourse {
  const SharedCourse({required this.id, required this.slots});

  final String id;

  /// 這門課上課的格子。空的代表這門課沒有時間。
  final List<SharedSlot> slots;
}

class SharedSlot {
  const SharedSlot(this.day, this.section);

  final Day day;
  final SectionNumber section;
}

/// 課表分享碼的編解碼。純函式：沒有 UI、沒有網路、沒有儲存。
///
/// **格式**（全大寫，刻意的）：
/// ```
/// HTTPS://NTUST-TAT.WEB.APP/S/TAT2 1151 B11000001 CS3039701.467 -CS3003302.434
/// └────────── 前綴 28 ──────────┘└magic4┘└學期4┘└─學號9─┘└──── 課程，以 - 分隔 ────┘
/// ```
/// - URL 的 scheme 與 host 依 RFC 3986 大小寫不敏感，所以全大寫仍然是合法網址；
///   而小寫字母不在 QR 的 alphanumeric 字集裡，寫成小寫會把整包踢進 byte 模式。
///   之後要接 Universal Links 時，流通中的 QR 不必重發就直接生效。
/// - `TAT2` 是 magic 加版本。`TAT1` 是只有課號、沒有時間的舊格式，這裡一併解得開。
/// - 課號固定 9 碼；時間接在 `.` 後面，第一碼是星期（1-7），其餘是節次代號
///   （`1234N56789ABCD`）。同一門課上多天就有多段 `.`。
///
/// **為什麼帶時間**：只帶課號的話，收方一定要連上 querycourse 才畫得出任何東西，
/// 而加退選就是在人擠人的地方發生的。帶了時間，離線就能看到完整的時間格子——
/// 找共同空堂需要的就只是時間；課名與教室有網路時再補。
/// 節次代號全是數字或大寫字母，所以帶時間仍然待在 alphanumeric 模式。
class CourseTableShareCodec {
  CourseTableShareCodec._();

  static const String prefix = 'HTTPS://NTUST-TAT.WEB.APP/S/';
  static const String magic = 'TAT2';
  static const String legacyMagic = 'TAT1';

  static const int courseIdLength = 9;
  static const int studentIdLength = 9;
  static const int semesterCodeLength = 4;

  static const String _courseSeparator = '-';
  static const String _slotSeparator = '.';

  /// 節次代號。順序就是 [SectionNumber] 的順序，索引對得起來。
  static const String _sectionCodes = '1234N56789ABCD';

  static String encode(CourseTableJson table) => prefix + encodePayload(table);

  /// 不含網址前綴的裸碼。「貼上代碼」那條路徑用得到。
  static String encodePayload(CourseTableJson table) {
    final buffer = StringBuffer()
      ..write(magic)
      ..write(_semesterCodeOf(table))
      ..write(_padStudentId(table.studentId));
    final courses = _coursesOf(table);
    for (var i = 0; i < courses.length; i++) {
      if (i > 0) buffer.write(_courseSeparator);
      buffer.write(courses[i].id);
      // 同一天的節次併成一段（`.467` 而不是 `.46.47`）：解碼端本來就讀「星期
      // 一碼 + 一串節次」，併起來每多一節只多一個字元。
      Day? current;
      for (final slot in courses[i].slots) {
        if (slot.day != current) {
          current = slot.day;
          buffer
            ..write(_slotSeparator)
            ..write(slot.day.index + 1);
        }
        buffer.write(_sectionCodes[slot.section.index]);
      }
    }
    return buffer.toString();
  }

  /// 解不開就回 null——這裡收得到的字串包括別的 App 的 QR、被截斷的貼上內容、
  /// 以及使用者手打的東西，全部都只是「不是我們的碼」，不是例外。
  static SharedTablePayload? decode(String raw) {
    var body = raw.trim().toUpperCase();
    if (body.startsWith(prefix)) body = body.substring(prefix.length);
    final version =
        body.length >= magic.length ? body.substring(0, magic.length) : '';
    if (version != magic && version != legacyMagic) return null;
    body = body.substring(magic.length);

    if (body.length < semesterCodeLength + studentIdLength) return null;
    final semesterCode = body.substring(0, semesterCodeLength);
    if (!_isAlphanumeric(semesterCode)) return null;
    body = body.substring(semesterCodeLength);
    final studentId = body.substring(0, studentIdLength).trim();
    body = body.substring(studentIdLength);

    final courses = <SharedCourse>[];
    if (body.isNotEmpty) {
      for (final chunk in body.split(_courseSeparator)) {
        final course = _decodeCourse(chunk);
        if (course == null) return null;
        courses.add(course);
      }
    }
    return SharedTablePayload(
      studentId: studentId,
      year: semesterCode.substring(0, 3),
      semester: semesterCode.substring(3),
      courses: courses,
    );
  }

  static SharedCourse? _decodeCourse(String chunk) {
    final parts = chunk.split(_slotSeparator);
    final id = parts.first;
    if (id.length != courseIdLength || !_isAlphanumeric(id)) return null;
    final slots = <SharedSlot>[];
    for (final slot in parts.skip(1)) {
      // 一段 `.` 後面是「星期一碼 + 至少一個節次」。
      if (slot.length < 2) return null;
      final day = int.tryParse(slot[0]);
      if (day == null || day < 1 || day > 7) return null;
      for (final code in slot.substring(1).split('')) {
        final index = _sectionCodes.indexOf(code);
        if (index < 0) return null;
        slots.add(SharedSlot(Day.values[day - 1], SectionNumber.values[index]));
      }
    }
    return SharedCourse(id: id, slots: slots);
  }

  /// 課表裡每一門課，以及它佔到的格子。順序照課表的走訪順序，同一份課表編出來
  /// 的碼才是穩定的。
  static List<SharedCourse> _coursesOf(CourseTableJson table) {
    final slots = <String, List<SharedSlot>>{};
    final order = <String>[];
    for (final day in CourseTableConflict.days) {
      final row = table.courseInfoMap[day];
      if (row == null) continue;
      for (final section in CourseTableConflict.sections) {
        final id = row[section]?.main.course.id;
        if (id == null || id.length != courseIdLength) continue;
        if (!slots.containsKey(id)) {
          slots[id] = [];
          order.add(id);
        }
        slots[id]!.add(SharedSlot(day, section));
      }
    }
    // 沒有時間的課也要帶上，收方才知道有這門課。
    for (final id in table.getCourseIdList()) {
      if (id.length == courseIdLength && !slots.containsKey(id)) {
        slots[id] = [];
        order.add(id);
      }
    }
    return [for (final id in order) SharedCourse(id: id, slots: slots[id]!)];
  }

  static String _semesterCodeOf(CourseTableJson table) {
    final semester = table.courseSemester;
    final code = '${semester.year}${semester.semester}'.toUpperCase();
    return code.length == semesterCodeLength
        ? code
        : code
            .padRight(semesterCodeLength, '0')
            .substring(0, semesterCodeLength);
  }

  /// 學號固定 9 碼才不需要分隔符。短的補空白——空白在 alphanumeric 字集裡。
  static String _padStudentId(String studentId) {
    final id = studentId.trim().toUpperCase();
    return id.length >= studentIdLength
        ? id.substring(0, studentIdLength)
        : id.padRight(studentIdLength);
  }

  static bool _isAlphanumeric(String value) {
    for (final unit in value.codeUnits) {
      final isDigit = unit >= 0x30 && unit <= 0x39;
      final isUpper = unit >= 0x41 && unit <= 0x5A;
      if (!isDigit && !isUpper) return false;
    }
    return true;
  }
}
