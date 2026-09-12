import 'package:flutter_app/src/model/course_table/course_time.dart';
import 'package:json_annotation/json_annotation.dart';

part 'classroom_usage_json.g.dart';

/// 一間教室在某一天的一個節次上的使用情形。
@JsonSerializable()
class ClassroomSlotJson {
  /// 佔用這一格的課程名稱。空字串代表這一格沒有課。
  ///
  /// 站台把課名與老師寫成 `課名</br>老師`（是的，是個收尾標籤，HTML5 的
  /// 解析器會把它當成 `<br>`）。**兩段分開存**：黏成一個字串會變成
  /// 「文學作品導讀陳逸軒」，看不出哪裡是課名哪裡是人名。只有一段時全部
  /// 算課名，多於兩段時第二段之後併進 [teacher]。
  final String course;

  /// 授課老師。站台自己就會寫「多位教師」。
  final String teacher;

  /// 站台在這一格畫了記號。
  ///
  /// 查詢頁的圖示說明列了「已預約」與「確定借用」兩種顏色，會畫在每一格
  /// 內嵌的那張小表格上。**實測從來沒出現過**：未來八週與過去二十週、兩個
  /// 校區、全部大樓掃過一輪，382 種不同的格子文字全都是「課名+老師」的形狀。
  ///
  /// 所以這裡只記「站台標了記號」這件事，不去分辨是哪一種——沒有任何一筆
  /// 真實資料可以驗證顏色與語意的對應，硬猜只會寫出一個看起來很篤定、實際
  /// 沒被驗證過的分類。真的出現時 `ClassroomConnector` 會把原始記號記進
  /// log，那時候再依實際值細分。
  final bool marked;

  const ClassroomSlotJson({
    this.course = '',
    this.teacher = '',
    this.marked = false,
  });

  /// 沒有課、也沒有記號，才算空堂。
  bool get isFree => course.isEmpty && teacher.isEmpty && !marked;

  factory ClassroomSlotJson.fromJson(Map<String, dynamic> srcJson) =>
      _$ClassroomSlotJsonFromJson(srcJson);

  Map<String, dynamic> toJson() => _$ClassroomSlotJsonToJson(this);
}

/// 一間教室一整天的 14 個節次。
@JsonSerializable(explicitToJson: true)
class ClassroomRowJson {
  /// 站台給的教室編號，例如 `T4-301`。
  final String name;

  /// 逐格對位 [ClassroomUsageJson.sectionCount] 個節次。
  final List<ClassroomSlotJson> slots;

  const ClassroomRowJson({required this.name, required this.slots});

  /// 這間教室屬於哪一棟：教室編號的第一段。
  ///
  /// 站台的教室編號一律是「大樓代號-房號」（`T4-301`、`IB-304`）。取不到
  /// 分隔線時回整個名稱，不要回空字串——呼叫端會拿它當分組的鍵。
  String get buildingCode {
    final dash = name.indexOf('-');
    return dash <= 0 ? name : name.substring(0, dash);
  }

  /// 這一天完全沒有人用。
  bool get isFreeAllDay => slots.every((slot) => slot.isFree);

  factory ClassroomRowJson.fromJson(Map<String, dynamic> srcJson) =>
      _$ClassroomRowJsonFromJson(srcJson);

  Map<String, dynamic> toJson() => _$ClassroomRowJsonToJson(this);
}

/// 一次查詢的結果：某一天、某個校區（可再限定大樓）底下每一間教室的使用情形。
@JsonSerializable(explicitToJson: true)
class ClassroomUsageJson {
  /// 站台的節次欄位數，也是 [SectionNumber] 去掉 `t_UnKnown` 之後的長度。
  ///
  /// 兩邊**逐格對位**：站台的「第 N 節」就是 `SectionNumber.values[N - 1]`。
  /// 第五節是中午 12:20–13:10，內部代號 `t_N`；站台自己就叫它第五節，
  /// 與 `CourseTableControl.sectionStringList` 的註解是同一件事。
  ///
  /// 這個對位是驗過的：把 querycourse 的 `ClassRoomNo` × `Node` 攤平之後
  /// 與站台的表格對拚 3360 格，佔用與否完全一致（見 docs/EMPTY_CLASSROOM.md）。
  static const int sectionCount = 14;

  final String campusCode;

  /// 查詢時限定的大樓，沒限定就是 null（結果會涵蓋整個校區）。
  final String? buildingCode;

  /// 查的是哪一天。只有日期有意義，時間一律是午夜。
  final DateTime date;

  final List<ClassroomRowJson> rooms;

  /// 這份資料是什麼時候抓回來的。
  ///
  /// 畫面上要講出來（「IB 棟資料為 10:36 抓取」「EE 棟 上次 09:50」）：一次
  /// 只查得到一棟，各棟的新舊不一樣，不講的話看起來會像一份即時的全校資料。
  /// 它也會跟著快取一起存，離線讀回來時顯示的仍是當初抓的時間。
  final DateTime fetchedAt;

  const ClassroomUsageJson({
    required this.campusCode,
    required this.date,
    required this.rooms,
    required this.fetchedAt,
    this.buildingCode,
  });

  /// 站台第 [index] 格（0 起算）對應的節次。
  static SectionNumber sectionAt(int index) => SectionNumber.values[index];

  factory ClassroomUsageJson.fromJson(Map<String, dynamic> srcJson) =>
      _$ClassroomUsageJsonFromJson(srcJson);

  Map<String, dynamic> toJson() => _$ClassroomUsageJsonToJson(this);
}
