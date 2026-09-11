import 'dart:async';

import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/repository/run.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/error_dialog_parameter.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 記錄「畫面上還開著哪些進度框」的 delegate。
///
/// 進度框只能靠 [ProgressHandle.dismiss] 一個一個關。`run()` 只要關錯一個，
/// 下面第一個測試就會紅。
class OverlayUi implements TaskUiDelegate {
  /// 還開著的進度框，key 是開啟順序，value 是訊息。
  final Map<int, String> visible = {};

  /// 依序回傳給每一次 confirmRetry 的決定，用完之後一律 giveUp。
  final List<RetryDecision> decisions = [];

  /// 每次 confirmRetry 被呼叫的當下，畫面上還開著幾個進度框。
  final List<int> visibleAtConfirm = [];

  int _nextId = 0;

  @override
  ProgressHandle beginProgress(String message) {
    final id = _nextId++;
    visible[id] = message;
    return _OverlayHandle(this, id);
  }

  @override
  Future<RetryDecision> confirmRetry(ErrorDialogParameter parameter) async {
    visibleAtConfirm.add(visible.length);
    return decisions.isEmpty ? RetryDecision.giveUp : decisions.removeAt(0);
  }

  @override
  void toast(String message) {}

  @override
  Future<String?> chooseOne(String title, Map<String, String> options) async =>
      chooseOneResult;

  /// [chooseOne] 要回什麼。null 代表使用者取消。
  String? chooseOneResult;

  @override
  Future<void> openLoginScreen() async => openLoginCalls++;

  /// 「帶我去登入設定」被叫了幾次。
  int openLoginCalls = 0;

  @override
  Future<SemesterJson?> chooseSemester({bool allowNull = false}) async => null;
}

class _OverlayHandle implements ProgressHandle {
  _OverlayHandle(this._ui, this._id);

  final OverlayUi _ui;
  final int _id;

  @override
  void dismiss() => _ui.visible.remove(_id);
}

void main() {
  late OverlayUi ui;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestL10n();
  });

  setUp(() {
    resetAppStatics();
    AuthSession.instance = FakeAuthSession();
    ui = OverlayUi();
    TaskUiDelegate.instance = ui;
    ConnectivityProbe.instance = FakeConnectivityProbe();
  });

  tearDown(() {
    AuthSession.instance = const UninstalledAuthSession();
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
  });

  group('進度框以 handle 收尾', () {
    test('並行的兩個 run，先結束的那一個只關掉自己的進度框', () async {
      final a = Completer<String>();
      final b = Completer<String>();

      final ra = run<String>(
        requires: const {},
        progressMessage: 'A',
        fetch: () => a.future,
      );
      final rb = run<String>(
        requires: const {},
        progressMessage: 'B',
        fetch: () => b.future,
      );
      await pumpEventQueue();

      expect(ui.visible.values, ['A', 'B']);

      a.complete('a');
      await ra;

      // 關錯一個的話，A 一結束就會把 B 的遮罩一起關掉，使用者以為 B 也載完
      // 了。課程頁三個分頁並行載入，每次都會踩到。
      expect(ui.visible.values, ['B'], reason: 'A 結束不能動到 B 的遮罩');

      b.complete('b');
      await rb;

      expect(ui.visible, isEmpty, reason: '兩個都結束後不能殘留遮罩');
    });

    test('按重試重跑一輪時，每一輪各開各關一個進度框', () async {
      ui.decisions.add(RetryDecision.retry);
      var attempts = 0;

      final result = await run<String>(
        requires: const {},
        progressMessage: '載入中',
        fetch: () async {
          attempts++;
          // 每一輪都要有自己的遮罩，而且只能有一個——handle 開在 while 迴圈
          // 裡面就是為了這件事。
          expect(ui.visible.values, ['載入中']);
          return attempts < 2 ? null : 'ok';
        },
      );

      expect(attempts, 2);
      expect(result, isA<Ok<String>>());
      expect(ui.visible, isEmpty, reason: '重試成功後不能殘留遮罩');
    });

    test('錯誤對話框跳出來的時候進度框已經關掉', () async {
      await run<String>(
        requires: const {},
        progressMessage: '載入中',
        fetch: () async => throw Exception('boom'),
      );

      // finally 在 _confirmRetry 之前跑，所以問使用者要不要重試的時候，
      // 吃掉觸控的遮罩不會蓋在對話框上面。
      expect(ui.visibleAtConfirm, [0]);
      expect(ui.visible, isEmpty);
    });
  });
}
