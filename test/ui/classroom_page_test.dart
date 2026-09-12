import 'package:flutter/material.dart';
import 'package:flutter_app/src/enum/classroom_view.dart';
import 'package:flutter_app/src/model/classroom/classroom_option.dart';
import 'package:flutter_app/src/model/classroom/classroom_usage_json.dart';
import 'package:flutter_app/src/repository/ntust_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/store/settings_store.dart';
import 'package:flutter_app/ui/pages/classroom/classroom_page.dart';
import 'package:flutter_app/ui/pages/classroom/widgets/classroom_other_buildings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 空教室頁。重點在三件事：
/// 1. 主要資訊是「空到幾點」而不是課名；
/// 2. 切換檢視不重設任何選擇；
/// 3. 「站台一列都沒回」不可以畫成「全部空著」。
class _FakeNtustRepository extends NtustRepository {
  _FakeNtustRepository({required this.campuses, required this.usage});

  Result<List<ClassroomCampusJson>> campuses;
  Result<ClassroomUsageJson> usage;
  int usageCalls = 0;
  final requested = <String>[];

  @override
  Future<Result<List<ClassroomCampusJson>>> getClassroomCampuses() async =>
      campuses;

  @override
  Future<Result<ClassroomUsageJson>> getClassroomUsage({
    required String campusCode,
    required DateTime date,
    String? buildingCode,
  }) async {
    usageCalls++;
    requested.add('$buildingCode');
    return usage;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadTestL10n();
  });

  setUp(() {
    resetAppStatics();
  });

  tearDown(() {
    NtustRepository.instance = NtustRepository();
  });

  ClassroomRowJson room(String name, {List<int> busy = const []}) =>
      ClassroomRowJson(
        name: name,
        slots: List.generate(
          ClassroomUsageJson.sectionCount,
          (i) => busy.contains(i)
              ? const ClassroomSlotJson(course: '微積分（上）', teacher: '呂老師')
              : const ClassroomSlotJson(),
        ),
      );

  ClassroomUsageJson usage(List<ClassroomRowJson> rooms) => ClassroomUsageJson(
        campusCode: 'HQ',
        buildingCode: 'IB',
        date: DateTime(2026, 9, 9),
        rooms: rooms,
        fetchedAt: DateTime(2026, 9, 9, 10, 36),
      );

  // 站台的下拉真的是華夏校區排在校本部前面，測試照原樣擺。
  const campuses = Ok([
    ClassroomCampusJson(code: 'HHC', name: '華夏校區', buildings: [
      ClassroomOptionJson(code: 'D', name: '華夏恆毅樓'),
    ]),
    ClassroomCampusJson(code: 'HQ', name: '校本部', buildings: [
      ClassroomOptionJson(code: 'IB', name: '國際大樓'),
      ClassroomOptionJson(code: 'TR', name: '研揚大樓'),
      ClassroomOptionJson(code: 'T4', name: '第四教學大樓'),
    ]),
  ]);

  Future<_FakeNtustRepository> pump(
    WidgetTester tester, {
    required Result<ClassroomUsageJson> usageResult,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo =
        _FakeNtustRepository(campuses: campuses, usage: usageResult);
    NtustRepository.instance = repo;
    await tester.pumpWidget(MaterialApp(
      home: ClassroomPage(
        initialDate: DateTime(2026, 9, 9),
        initialSection: 2,
        errorBuilder: (message, onRetry) => Text('error:$message'),
      ),
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('每一列先說空到幾點，課名退到第二行而且帶「下一堂」', (tester) async {
    // 「14:20 微積分（上）／還有 3 節」會被讀成「這間正在上微積分」——
    // 課名沒有時態。所以答案要自己站出來。
    await pump(tester,
        usageResult: Ok(usage([room('IB-501', busy: [6, 7])])));

    expect(find.text('IB-501'), findsOneWidget);
    expect(find.text('空到 14:10'), findsOneWidget);
    expect(find.text('下一堂 14:20 微積分（上）'), findsOneWidget);
    // 找位子的人不需要老師名字。
    expect(find.textContaining('呂老師'), findsNothing);
  });

  testWidgets('整天沒課的教室講「當日未排課 / 整天空著」', (tester) async {
    await pump(tester, usageResult: Ok(usage([room('IB-507')])));
    expect(find.text('整天空著'), findsOneWidget);
    expect(find.text('當日未排課'), findsOneWidget);
  });

  testWidgets('摘要講的是「有幾間空著」，不是「符合篩選的有幾間」', (tester) async {
    await pump(
        tester,
        usageResult: Ok(usage([
          room('IB-501'),
          room('IB-502', busy: [2]),
          room('IB-503'),
        ])));
    expect(find.text('3 間裡有 2 間現在空著'), findsOneWidget);
  });

  testWidgets('依樓層分組', (tester) async {
    await pump(
        tester,
        usageResult:
            Ok(usage([room('IB-501'), room('IB-601'), room('IB-502')])));
    expect(find.text('5 樓'), findsOneWidget);
    expect(find.text('6 樓'), findsOneWidget);
  });

  testWidgets('切換檢視不重設任何選擇，而且只換第三列', (tester) async {
    final repo = await pump(
        tester, usageResult: Ok(usage([room('IB-501', busy: [6])])));
    final callsBefore = repo.usageCalls;

    // 清單：連續節數篩選；一整天：圖示說明。兩者不同時出現。
    expect(find.text('不限'), findsOneWidget);
    expect(find.text('已借出'), findsNothing);

    await tester.tap(find.text('一整天'));
    await tester.pumpAndSettle();

    expect(find.text('不限'), findsNothing);
    expect(find.text('已借出'), findsOneWidget);
    // 大樓與時段都還在，而且沒有再打一次網路。
    expect(find.text('國際大樓'), findsOneWidget);
    expect(find.textContaining('10:20–11:10'), findsOneWidget);
    expect(repo.usageCalls, callsBefore, reason: '換檢視不該重抓');
  });

  testWidgets('上次用的檢視會被記住', (tester) async {
    final stores = resetAppStatics();
    await SettingsStore.instance.setClassroomView(ClassroomView.day);
    expect(await SettingsStore.instance.classroomView, ClassroomView.day);
    expect(stores.plain, isNotNull);

    await pump(tester, usageResult: Ok(usage([room('IB-501')])));
    expect(find.text('已借出'), findsOneWidget, reason: '應該直接開在一整天');
  });

  testWidgets('站台一列都沒回時講「沒有資料」，不可以畫成全部空著', (tester) async {
    // 借用系統只排上課日，週末一律回空表。那一天有沒有人借用它根本沒講，
    // 畫成全空會是憑空捏造。
    await pump(tester, usageResult: Ok(usage([])));
    expect(find.textContaining('無資料'), findsOneWidget);
    expect(find.textContaining('間裡有'), findsNothing);
    // 下一步多半是換一棟，空狀態也要接得上。
    expect(find.text('其他大樓'), findsOneWidget);
    expect(find.text('重新整理'), findsOneWidget);
  });

  testWidgets('全滿是正常結果，給的是下一步而不是錯誤', (tester) async {
    await pump(
        tester, usageResult: Ok(usage([room('IB-501', busy: [2])])));
    expect(find.textContaining('這一節全滿'), findsOneWidget);
    expect(find.text('看第 4 節'), findsOneWidget);
    expect(find.text('換大樓'), findsOneWidget);
    // 沒有插圖、沒有驚嘆號，也不是錯誤畫面。
    expect(find.textContaining('error:'), findsNothing);
  });

  testWidgets('抓不到時說出是哪一棟', (tester) async {
    await pump(tester,
        usageResult: const Failed<ClassroomUsageJson>(FetchFailed()));
    expect(find.textContaining('研揚大樓 查詢失敗'), findsOneWidget);
  });

  testWidgets('開場開在大樓最多的校區，不是站台排第一個的那個', (tester) async {
    // 站台把華夏校區排在校本部前面。照順序取第一個的話，絕大多數人一進來
    // 看到的會是華夏那一棟樓。
    final repo =
        await pump(tester, usageResult: Ok(usage([room('IB-501')])));
    expect(find.text('研揚大樓'), findsOneWidget);
    expect(repo.requested, ['TR']);
  });

  testWidgets('研揚大樓排在大樓清單第一個，其餘維持站台順序', (tester) async {
    // 它是借用系統裡教室最多的一棟，最有機會一進來就看到空教室。
    await pump(tester, usageResult: Ok(usage([room('IB-501')])));
    final others = tester.widget<ClassroomOtherBuildings>(
        find.byType(ClassroomOtherBuildings));
    expect(others.buildings.map((b) => b.code), ['IB', 'T4'],
        reason: '目前這一棟不列在「其他大樓」，其餘照站台順序');
  });

  testWidgets('其他大樓列在底下，一次只查一棟', (tester) async {
    final repo =
        await pump(tester, usageResult: Ok(usage([room('IB-501')])));
    expect(find.text('其他大樓'), findsOneWidget);
    expect(find.text('第四教學大樓'), findsOneWidget);
    expect(repo.requested, ['TR'], reason: '開場只抓預設的那一棟');

    await tester.tap(find.text('第四教學大樓'));
    await tester.pumpAndSettle();
    expect(repo.requested, ['TR', 'T4']);
  });
}
