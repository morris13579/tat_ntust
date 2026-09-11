import 'package:flutter/material.dart';
import 'package:flutter_app/ui/other/listview_animator.dart';
import 'package:flutter_test/flutter_test.dart';

/// WidgetAnimator 的進場延遲：同一個 frame 內依序錯開、有上限，
/// 而且每個 frame 重新從頭起算。歸零必須綁 frame 而不是牆上時鐘的計時器，
/// 否則建構跨 frame 時累加值會一路帶到下一批項目。
void main() {
  /// 取出目前畫面上每個 Animator 拿到的延遲，順序就是建構順序。
  List<Duration> delaysOf(WidgetTester tester) => tester
      .widgetList<Animator>(find.byType(Animator))
      .map((widget) => widget.time)
      .toList();

  /// 收掉整棵樹，讓 Animator 的計時器與 AnimationController 被 dispose，
  /// 否則 testWidgets 結束時會抱怨還有 pending timer。
  Future<void> disposeTree(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  Widget wrap(List<Widget> children) => MaterialApp(
        home: Column(children: children),
      );

  setUp(debugResetEntryDelay);

  testWidgets('同一個 frame 建構的項目，延遲依序相差 100ms', (tester) async {
    await tester.pumpWidget(wrap(const [
      WidgetAnimator(SizedBox()),
      WidgetAnimator(SizedBox()),
      WidgetAnimator(SizedBox()),
    ]));

    expect(delaysOf(tester), const [
      Duration(milliseconds: 100),
      Duration(milliseconds: 200),
      Duration(milliseconds: 300),
    ]);

    await disposeTree(tester);
  });

  testWidgets('延遲有上限，長清單不會愈後面等愈久', (tester) async {
    // 沒有上限的話第 8 項要等 800ms，第 20 項要等兩秒才淡入。
    await tester.pumpWidget(wrap(
      List<Widget>.generate(8, (_) => const WidgetAnimator(SizedBox())),
    ));

    expect(delaysOf(tester).last, const Duration(milliseconds: 500));
    expect(
      delaysOf(tester).every((d) => d <= const Duration(milliseconds: 500)),
      isTrue,
    );

    await disposeTree(tester);
  });

  testWidgets('下一個 frame 重新從 100ms 起算', (tester) async {
    // 歸零綁計時器的話，測試裡時間不推進就永遠不觸發，真機上也會因為建構
    // 跨 frame 而錯過時機，第二批項目就接著第一批繼續累加。
    await tester.pumpWidget(wrap(const [
      WidgetAnimator(SizedBox(), key: ValueKey('first')),
    ]));
    expect(delaysOf(tester), const [Duration(milliseconds: 100)]);

    // 換一個 key 逼出全新的 State，模擬「捲動時才延遲建構出來的下一項」。
    await tester.pumpWidget(wrap(const [
      WidgetAnimator(SizedBox(), key: ValueKey('second')),
    ]));
    expect(delaysOf(tester), const [Duration(milliseconds: 100)]);

    await disposeTree(tester);
  });

  testWidgets('rebuild 不會重新排隊，也不會佔掉別人的名額', (tester) async {
    // 延遲只能在 State 初始化時取一次：寫在 build 裡的話每次 rebuild 都再累加，
    // 而內層 Animator 的 State 早就建好、不會採用新值，等於白白把後面的往後推。
    final key = GlobalKey();
    await tester.pumpWidget(wrap([
      WidgetAnimator(const SizedBox(), key: key),
    ]));
    expect(delaysOf(tester), const [Duration(milliseconds: 100)]);

    // 同一個 GlobalKey ⇒ State 會被沿用，只是重新 build 一次。
    await tester.pumpWidget(wrap([
      WidgetAnimator(const SizedBox(width: 1), key: key),
    ]));
    expect(delaysOf(tester), const [Duration(milliseconds: 100)]);

    await disposeTree(tester);
  });
}
