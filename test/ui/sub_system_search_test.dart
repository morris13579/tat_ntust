import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/ntust/ap_tree_json.dart';
import 'package:flutter_app/src/repository/ntust_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/ui/pages/subsystem/sub_system_category.dart';
import 'package:flutter_app/ui/pages/subsystem/sub_system_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 資訊系統的搜尋是本地過濾：整棵樹本來就在記憶體裡，打字不該再打一次 API。
class _FakeNtustRepository extends NtustRepository {
  _FakeNtustRepository(this.result);

  Result<List<APTreeJson>> result;
  int calls = 0;

  @override
  Future<Result<List<APTreeJson>>> getSubSystemTree() async {
    calls++;
    return result;
  }
}

APListJson _ap(String name) => APListJson(name: name, url: 'https://x/$name');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadTestL10n();
  });

  late _FakeNtustRepository repo;

  setUp(() {
    resetAppStatics();
  });

  tearDown(() {
    NtustRepository.instance = NtustRepository();
  });

  /// 預設的 800x600 放不下整份清單，最下面的分類會沒有被 layout 出來，
  /// `find.text` 因此找不到——把畫面拉高才測得到「有沒有畫」而不是「有沒有捲到」。
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// service-1 有五項（超過 collapsedCount），service-2 有兩項。
  Result<List<APTreeJson>> tree() => Ok([
        APTreeJson('service-1', [
          _ap('課程查詢'),
          _ap('教學意見調查'),
          _ap('畢業預審'),
          _ap('選課系統'),
          _ap('停修申請'),
        ]),
        APTreeJson('service-2', [_ap('學籍資料'), _ap('歷年成績')]),
      ]);

  Future<void> pump(WidgetTester tester, Result<List<APTreeJson>> result,
      {String? serviceId}) async {
    useTallSurface(tester);
    repo = _FakeNtustRepository(result);
    NtustRepository.instance = repo;
    await tester.pumpWidget(MaterialApp(
      home: SubSystemPage(
        serviceId: serviceId,
        errorBuilder: (message) => Text('error:$message'),
        openWebView: (title, url) async {},
        openClassroom: () {},
      ),
    ));
    await tester.pumpAndSettle();
  }

  test('空教室釘在「校園資訊」底下，不是別的分類', () {
    // 代號是 NTUST 那一側的不透明字串，靠 subSystemCategoryName 對照。
    // 釘錯分類的話那一列會整個消失而且不會有任何錯誤。
    expect(subSystemCategoryName(classroomPinnedCategory),
        R.current.resources);
  });

  testWidgets('搜尋只做本地過濾，不會再打一次 API', (tester) async {
    await pump(tester, tree());
    expect(repo.calls, 1);
    expect(find.text('學籍資料'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '課程');
    await tester.pumpAndSettle();

    expect(find.text('課程查詢'), findsOneWidget);
    expect(find.text('學籍資料'), findsNothing);
    expect(repo.calls, 1, reason: '搜尋不該打 API，整棵樹已經在記憶體裡了');
  });

  testWidgets('一個分類底下的服務一次列完，沒有「其餘 N 項」', (tester) async {
    await pump(tester, tree());

    expect(find.text('選課系統'), findsOneWidget);
    expect(find.text('停修申請'), findsOneWidget);
    expect(find.textContaining('其餘'), findsNothing);
  });

  testWidgets('搜尋只留下命中的服務', (tester) async {
    await pump(tester, tree());

    await tester.enterText(find.byType(TextField), '停修');
    await tester.pumpAndSettle();

    expect(find.text('停修申請'), findsOneWidget);
    expect(find.text('選課系統'), findsNothing);
  });

  testWidgets('搜不到東西時給空狀態，而不是一片空白', (tester) async {
    await pump(tester, tree());

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();

    expect(find.text(R.current.subSystemSearchEmpty), findsOneWidget);
  });

  testWidgets('功能樹抓失敗時交給呼叫端注入的錯誤畫面', (tester) async {
    await pump(tester, const Failed(Offline()));

    expect(find.textContaining('error:'), findsOneWidget);
  });

  testWidgets('帶 serviceId 進來只看那一個分類，其他分類都不畫', (tester) async {
    // 這一支盯的是 Obx：篩掉其他分類之後，如果 builder 裡一個 observable
    // 都沒讀到，GetX 會整頁丟「improper use of a GetX」而不是少畫幾列。
    await pump(tester, tree(), serviceId: 'service-1');

    expect(tester.takeException(), isNull);
    expect(find.text('選課系統'), findsOneWidget);
    expect(find.text('學籍資料'), findsNothing);
  });
}
