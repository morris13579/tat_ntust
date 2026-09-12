/// 一節課的起訖時刻。
///
/// 課表只需要「08:10 - 09:00」這種顯示字串，但空教室要算「空到幾點」與
/// 「下一堂幾點」，得拿得到分開的起訖。所以這裡存的是結構，顯示字串由
/// 兩邊各自組。
class SectionTime {
  const SectionTime(this.startHour, this.startMinute, this.endHour,
      this.endMinute);

  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  String get start => _hhmm(startHour, startMinute);
  String get end => _hhmm(endHour, endMinute);

  /// 這一節在 [day] 那一天的開始時刻。
  DateTime startOn(DateTime day) =>
      DateTime(day.year, day.month, day.day, startHour, startMinute);

  /// 這一節在 [day] 那一天的結束時刻。
  DateTime endOn(DateTime day) =>
      DateTime(day.year, day.month, day.day, endHour, endMinute);

  static String _hhmm(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// 十四節的時刻表，索引就是 `SectionNumber.values` 的索引。
///
/// **索引 4 是中午 12:20–13:10**（內部代號 `t_N`）。臺科自己叫它第五節，
/// 之後依序往下——教室借用系統的「第五節」指的也是這一格，兩邊逐格對位。
/// 顯示用的名稱是 `CourseTableControl.sectionStringList`（`1…10 A…D`），
/// 那一套與這裡的索引對齊，但與借用系統的「第 N 節」在第十一節之後不同名。
///
/// 這是全 App 唯一一份節次時刻，`CourseTableControl.timeList` 由它組出來。
const List<SectionTime> sectionTimes = [
  SectionTime(8, 10, 9, 0),
  SectionTime(9, 10, 10, 0),
  SectionTime(10, 20, 11, 10),
  SectionTime(11, 20, 12, 10),
  SectionTime(12, 20, 13, 10),
  SectionTime(13, 20, 14, 10),
  SectionTime(14, 20, 15, 10),
  SectionTime(15, 30, 16, 20),
  SectionTime(16, 30, 17, 20),
  SectionTime(17, 30, 18, 20),
  SectionTime(18, 25, 19, 15),
  SectionTime(19, 20, 20, 10),
  SectionTime(20, 15, 21, 5),
  SectionTime(21, 0, 22, 0),
];

/// 節次的顯示名稱，與 [sectionTimes] 逐格對位。
///
/// **這是顯示用的，不是內部代號。** 內部那一套（`SectionNumber` 的名稱、
/// `CourseConnector.timeEnum`、分享碼的 `1234N56789ABCD`）為了逐字比對，
/// 每一格必須是單一字元，所以中午那格在內部叫 `N`。臺科自己不是這樣叫的：
/// 中午 12:20–13:10 就是**第五節**，之後依序往下。
///
/// 與教室借用系統的「第 N 節」在**第十一節之後不同名**：站台一路數到第十四節，
/// 這裡是 A–D。索引是對齊的，名稱不是。
const List<String> sectionLabels = [
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
  "D",
];
