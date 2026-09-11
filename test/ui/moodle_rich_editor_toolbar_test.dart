import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/util/rich_editor_bridge_utils.dart';
import 'package:flutter_app/ui/components/card/section_card.dart';
import 'package:flutter_app/ui/components/editor/moodle_rich_editor_toolbar.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_l10n.dart';

/// 工具列的畫面規格。這一塊完全沒有 WebView，所以是整個所見即所得功能裡
/// 唯一測得動的 UI。
///
/// **不要用 `find.byType(TextButton)`**：Flutter 3.38 的 `TextButton.icon`
/// 回的是私有的 `_TextButtonWithIcon`，byType 一個都比不到，測試會假綠。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadTestL10n();
  });

  Future<void> pump(
    WidgetTester tester, {
    Set<String> active = const {},
    bool sourceMode = false,
    bool enabled = true,
    void Function(EditorCommand)? onCommand,
    VoidCallback? onToggleSource,
    double width = 1600,
    double textScale = 1,
    List<Widget> trailing = const [],
    bool dense = false,
  }) async {
    // 工具列是橫向捲動的，視窗窄的話後面幾顆根本不會被建出來。預設寬到整排
    // 都塞得下；要驗證捲動與邊緣提示的那幾個才自己把它縮回手機寬度。
    tester.view.physicalSize = Size(width, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: MoodleRichEditorToolbar(
              active: active,
              sourceMode: sourceMode,
              enabled: enabled,
              onCommand: onCommand ?? (_) {},
              onToggleSource: onToggleSource ?? () {},
              trailing: trailing,
              dense: dense,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// `find.byTooltip` 比到的是 Tooltip，IconButton 是它的祖先。
  Finder buttonWithTooltip(String tooltip) => find.ancestor(
      of: find.byTooltip(tooltip), matching: find.byType(IconButton));

  /// 邊緣提示一直都在樹上，只是透明度為 0，所以要讀值不能只比有沒有畫。
  double opacityOf(WidgetTester tester, String key) =>
      tester.widget<AnimatedOpacity>(find.byKey(ValueKey(key))).opacity;

  testWidgets('每一個指令都有一顆鈕，另外還有一顆原始碼切換', (tester) async {
    await pump(tester);

    for (final command in EditorCommand.values) {
      expect(find.byTooltip(MoodleRichEditorToolbar.labelOf(command)),
          findsOneWidget,
          reason: '$command');
    }
    expect(find.byTooltip(R.current.forumEditorSource), findsOneWidget);
    // 就這些，一顆都不多。官方 App 也沒有插入圖片——這條路只能保留貼文
    // 原有的圖，多一顆按不出東西的鈕比沒有更糟。
    expect(find.byType(IconButton),
        findsNWidgets(EditorCommand.values.length + 1));
  });

  testWidgets('生效中的格式標成選取，其他不標', (tester) async {
    await pump(tester, active: const {'bold', 'h3'});

    IconButton buttonFor(String tooltip) =>
        tester.widget<IconButton>(buttonWithTooltip(tooltip));

    expect(
        buttonFor(MoodleRichEditorToolbar.labelOf(EditorCommand.bold))
            .isSelected,
        isTrue);
    expect(
        buttonFor(MoodleRichEditorToolbar.labelOf(EditorCommand.heading3))
            .isSelected,
        isTrue);
    expect(
        buttonFor(MoodleRichEditorToolbar.labelOf(EditorCommand.italic))
            .isSelected,
        isFalse);
    expect(
        buttonFor(MoodleRichEditorToolbar.labelOf(EditorCommand.heading4))
            .isSelected,
        isFalse);
  });

  testWidgets('按下去回報的是對應的那一個指令', (tester) async {
    final tapped = <EditorCommand>[];
    await pump(tester, onCommand: tapped.add);

    for (final command in EditorCommand.values) {
      await tester
          .tap(find.byTooltip(MoodleRichEditorToolbar.labelOf(command)));
      await tester.pump();
    }

    expect(tapped, EditorCommand.values);
  });

  testWidgets('原始碼模式：格式鈕全部停用，只剩切換鈕還能按', (tester) async {
    var toggles = 0;
    final tapped = <EditorCommand>[];
    await pump(tester,
        sourceMode: true,
        onCommand: tapped.add,
        onToggleSource: () => toggles++);

    for (final command in EditorCommand.values) {
      final button = tester.widget<IconButton>(
          buttonWithTooltip(MoodleRichEditorToolbar.labelOf(command)));
      expect(button.onPressed, isNull, reason: '$command');
    }
    expect(
        tester
            .widget<IconButton>(buttonWithTooltip(R.current.forumEditorSource))
            .isSelected,
        isTrue);

    await tester.tap(find.byTooltip(R.current.forumEditorSource));
    await tester.pump();
    expect(toggles, 1);
    expect(tapped, isEmpty);
  });

  testWidgets('編輯器還沒準備好時整排都按不動——包括原始碼切換', (tester) async {
    await pump(tester, enabled: false);

    for (final command in EditorCommand.values) {
      expect(
          tester
              .widget<IconButton>(
                  buttonWithTooltip(MoodleRichEditorToolbar.labelOf(command)))
              .onPressed,
          isNull);
    }
    expect(
        tester
            .widget<IconButton>(buttonWithTooltip(R.current.forumEditorSource))
            .onPressed,
        isNull);
  });

  testWidgets('402pt 寬的手機上，原始碼鈕還是在畫面裡', (tester) async {
    await pump(tester, width: 402);

    // 它不跟著格式鈕一起捲：捲出畫面的話，第一次用的人永遠找不到原始碼模式。
    final rect = tester.getRect(buttonWithTooltip(R.current.forumEditorSource));
    expect(rect.right, lessThanOrEqualTo(402));
    expect(
        tester
            .widget<IconButton>(buttonWithTooltip(R.current.forumEditorSource))
            .onPressed,
        isNotNull);
  });

  testWidgets('捲得動的時候右邊有箭頭，捲到底就換左邊', (tester) async {
    await pump(tester, width: 402);

    expect(opacityOf(tester, 'toolbar-scrim-start'), 0);
    expect(opacityOf(tester, 'toolbar-scrim-end'), 1);

    await tester.drag(find.byType(ListView), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(opacityOf(tester, 'toolbar-scrim-start'), 1);
    expect(opacityOf(tester, 'toolbar-scrim-end'), 0);
  });

  testWidgets('整排塞得下時兩邊都不畫箭頭', (tester) async {
    await pump(tester);

    expect(opacityOf(tester, 'toolbar-scrim-start'), 0);
    expect(opacityOf(tester, 'toolbar-scrim-end'), 0);
  });

  testWidgets('沒傳 trailing 就一顆都不多——原本的呼叫端一行都不用改', (tester) async {
    await pump(tester);

    expect(find.byIcon(LucideIcons.chevronDown), findsNothing);
    expect(find.byType(IconButton),
        findsNWidgets(EditorCommand.values.length + 1));
  });

  testWidgets('trailing 掛兩顆、寬 320、字級 3.0：這一列還是 64 高', (tester) async {
    // 鍵盤釘住的版面每一個數字都建立在這 64 上：這一列一變高，編輯面就變矮。
    for (final scale in [1.0, 2.0, 3.0]) {
      await pump(
        tester,
        width: 320,
        textScale: scale,
        trailing: [
          IconButton(
            tooltip: '附件',
            icon: Badge.count(
              count: 9,
              isLabelVisible: true,
              child: const Icon(LucideIcons.paperclip, size: 18),
            ),
            visualDensity: VisualDensity.compact,
            onPressed: () {},
          ),
          IconButton(
            tooltip: '收起鍵盤',
            icon: const Icon(LucideIcons.chevronDown, size: 18),
            visualDensity: VisualDensity.compact,
            onPressed: () {},
          ),
        ],
      );

      expect(tester.getSize(find.byType(SectionCard)).height, 64,
          reason: 'textScale=$scale');
      expect(tester.getSize(find.byType(SectionCard)).height,
          MoodleRichEditorToolbar.height,
          reason: 'textScale=$scale');
      expect(tester.takeException(), isNull, reason: 'textScale=$scale');
    }
  });

  testWidgets('dense：讓開的只有卡片的留白，48 高，按鈕一顆都沒縮', (tester) async {
    // 橫著拿的手機扣掉鍵盤只剩一百多點，這 16 點是編輯面看得到幾行的差別。
    for (final scale in [1.0, 2.0, 3.0]) {
      await pump(tester, width: 320, textScale: scale, dense: true);

      expect(tester.getSize(find.byType(SectionCard)).height,
          MoodleRichEditorToolbar.denseHeight,
          reason: 'textScale=$scale');
      expect(tester.getSize(find.byType(SectionCard)).height, 48,
          reason: 'textScale=$scale');
      // 觸控範圍是原本的 40，讓開的是卡片上下的留白。
      expect(
          tester.getSize(buttonWithTooltip(R.current.forumEditorSource)).height,
          40,
          reason: 'textScale=$scale');
      expect(tester.takeException(), isNull, reason: 'textScale=$scale');
    }
  });
}
