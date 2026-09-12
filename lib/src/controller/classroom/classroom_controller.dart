import 'package:flutter_app/src/enum/classroom_view.dart';
import 'package:flutter_app/src/model/classroom/classroom_option.dart';
import 'package:flutter_app/src/model/classroom/classroom_usage_json.dart';
import 'package:flutter_app/src/repository/ntust_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/store/settings_store.dart';
import 'package:flutter_app/src/util/classroom_availability.dart';
import 'package:get/get.dart';

/// 空教室頁的狀態。
///
/// 頁面層級的普通類別，不是 GetxController：生命週期就是那一頁。
///
/// **一次只查一棟**——借用系統的查詢頁本來就是這樣，沒辦法一次要整個校區
/// 的細節（校區層級的查詢會分頁，而且翻頁一樣是一次一趟）。所以這裡把每一棟
/// 各自的結果與抓取時間分開存，畫面才講得出「IB 棟資料為 10:36 抓取」。
class ClassroomController {
  ClassroomController({DateTime? now}) {
    final (date, section) =
        ClassroomAvailability.nowSection(now ?? DateTime.now());
    _date = date;
    _section = section;
  }

  /// 開場預設、而且在清單裡排第一個的大樓。
  ///
  /// `TR` 是研揚大樓，借用系統裡教室最多的一棟（38 間，第二多的國際大樓 33
  /// 間），最有機會一進來就看到空教室。站台沒有「哪一棟最常用」這種欄位，
  /// 所以寫在這裡；代號不存在時（學校把它移出借用系統）自動退回站台給的
  /// 第一棟，不會變成查不到東西的畫面。
  static const String preferredBuilding = 'TR';

  final campuses = Rxn<Result<List<ClassroomCampusJson>>>();

  /// `大樓代號` → 那一棟在 [date] 那一天的使用情形。切日期時整包清掉。
  final usage = <String, Result<ClassroomUsageJson>>{}.obs;

  /// 正在抓的大樓代號。
  final loading = <String>{}.obs;

  final view = ClassroomView.list.obs;
  final runFilter = ClassroomRunFilter.any.obs;

  /// 目前選的校區與大樓。大樓是 null 代表還沒選到任何一棟。
  final campusCode = RxnString();
  final buildingCode = RxnString();

  late DateTime _date;
  late int _section;

  /// 查的是哪一天。
  DateTime get date => _date;

  /// 查的是第幾節（索引，與 `sectionTimes` 對齊）。
  int get section => _section;

  final _revision = 0.obs;

  /// 日期或節次換了。畫面靠它重畫——[date] 與 [section] 是普通欄位，
  /// 不是 Rx，因為它們一定是成對變動的，兩顆 Rx 會讓畫面在中間狀態閃一次。
  int get revision => _revision.value;

  /// 目前這一棟的結果。
  Result<ClassroomUsageJson>? get current {
    final code = buildingCode.value;
    return code == null ? null : usage[code];
  }

  bool get isLoadingCurrent {
    final code = buildingCode.value;
    return code != null && loading.contains(code);
  }

  /// 目前校區底下的大樓清單，[preferredBuilding] 排第一個。
  List<ClassroomOptionJson> get buildings {
    final list = campuses.value?.dataOrNull ?? const <ClassroomCampusJson>[];
    final code = campusCode.value;
    for (final campus in list) {
      if (campus.code == code) return _ordered(campus.buildings);
    }
    return const [];
  }

  /// 只把偏好的那一棟提到最前面，其餘維持站台給的順序——站台的順序本身
  /// 是有意義的（大致照校區配置），整個重排只會讓熟悉的人找不到。
  static List<ClassroomOptionJson> _ordered(
      List<ClassroomOptionJson> buildings) {
    final index =
        buildings.indexWhere((b) => b.code == preferredBuilding);
    if (index <= 0) return buildings;
    return [
      buildings[index],
      ...buildings.where((b) => b.code != preferredBuilding),
    ];
  }

  ClassroomOptionJson? get currentBuilding {
    final code = buildingCode.value;
    for (final building in buildings) {
      if (building.code == code) return building;
    }
    return null;
  }

  /// 這一天站台一列教室都沒有回。
  ///
  /// 這**不是**錯誤：借用系統只排上課日，週末與假日一律回空表。畫成「全部
  /// 空著」會是憑空捏造——那一天有沒有人借用，站台根本沒講。
  bool get isClosedDay {
    final data = current?.dataOrNull;
    return data != null && data.rooms.isEmpty;
  }

  /// 目前這一棟、這一節的可用性。
  List<ClassroomVacancy> get vacancies {
    final data = current?.dataOrNull;
    if (data == null) return const [];
    return ClassroomAvailability.of(data, _section);
  }

  /// 通過連續節數篩選的空教室。
  List<ClassroomVacancy> get freeRooms =>
      vacancies.where(runFilter.value.accepts).toList();

  /// 這一節空著的教室，不套篩選——摘要那一行講的是「有幾間空著」，
  /// 套了篩選會變成「符合條件的有幾間」，兩者不是同一句話。
  int get freeCount => vacancies.where((v) => v.isFree).length;

  int get roomCount => current?.dataOrNull?.rooms.length ?? 0;

  Future<void> init() async {
    view.value = await SettingsStore.instance.classroomView;
    campuses.value = null;
    campuses.value = await NtustRepository.instance.getClassroomCampuses();

    final list = campuses.value?.dataOrNull ?? const <ClassroomCampusJson>[];
    if (list.isEmpty) return;

    final remembered = await SettingsStore.instance.classroomBuilding;
    // 記住的那一棟還在清單裡才用它。學校把一棟從借用系統拿掉時，開場不該是
    // 一個查不到東西的大樓代號。
    for (final campus in list) {
      for (final building in campus.buildings) {
        if (building.code == remembered) {
          campusCode.value = campus.code;
          buildingCode.value = building.code;
          await loadBuilding(building.code);
          return;
        }
      }
    }
    // 沒有記住的那一棟時開在**大樓最多的那個校區**。站台的下拉是華夏校區
    // 排在校本部前面，照順序取第一個會讓絕大多數人一進來看到的是華夏的
    // 那一棟樓。「哪個是主校區」站台沒有欄位講，大樓數量是手上唯一的訊號。
    final main = list.reduce(
        (a, b) => b.buildings.length > a.buildings.length ? b : a);
    campusCode.value = main.code;
    final ordered = _ordered(main.buildings);
    if (ordered.isEmpty) return;
    buildingCode.value = ordered.first.code;
    await loadBuilding(ordered.first.code);
  }

  /// 抓一棟。手上已經有這一棟這一天的結果就不重抓，除非 [force]。
  Future<void> loadBuilding(String code, {bool force = false}) async {
    final campus = campusCode.value;
    if (campus == null) return;
    if (!force && usage[code]?.hasData == true) return;
    if (loading.contains(code)) return;

    loading.add(code);
    try {
      usage[code] = await NtustRepository.instance.getClassroomUsage(
        campusCode: campus,
        date: _date,
        buildingCode: code,
      );
    } finally {
      loading.remove(code);
      // Map 的 `[]=` 對 RxMap 會通知，但 remove 之後還要再戳一次才畫得到
      // 「正在查…」消失。
      usage.refresh();
    }
  }

  /// 換一棟。
  Future<void> selectBuilding(String code) async {
    if (buildingCode.value == code) return;
    buildingCode.value = code;
    await SettingsStore.instance.setClassroomBuilding(code);
    await loadBuilding(code);
  }

  /// 換日期與節次。日期真的變了才清掉已經抓到的東西——只換節次的話同一天的
  /// 資料照樣可以用，不必再打一次網路。
  Future<void> setTime(DateTime date, int section) async {
    final day = DateTime(date.year, date.month, date.day);
    final dayChanged = day != _date;
    _date = day;
    _section = section;
    _revision.value++;
    if (dayChanged) {
      usage.clear();
      final code = buildingCode.value;
      if (code != null) await loadBuilding(code);
    }
  }

  /// 回到現在。
  Future<void> backToNow({DateTime? now}) async {
    final (date, section) =
        ClassroomAvailability.nowSection(now ?? DateTime.now());
    await setTime(date, section);
  }

  Future<void> setView(ClassroomView value) async {
    view.value = value;
    await SettingsStore.instance.setClassroomView(value);
  }

  /// 重抓目前這一棟。
  Future<void> refresh() async {
    final code = buildingCode.value;
    if (code == null) return;
    await loadBuilding(code, force: true);
  }

  void dispose() {
    campuses.close();
    usage.close();
    loading.close();
    view.close();
    runFilter.close();
    campusCode.close();
    buildingCode.close();
    _revision.close();
  }
}
