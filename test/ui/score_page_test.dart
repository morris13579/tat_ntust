import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/src/model/score/score_json.dart';
import 'package:flutter_app/ui/pages/score/widget/score_row.dart';
import 'package:flutter_app/ui/pages/score/widget/score_summary_strip.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_l10n.dart';

/// 成績頁（screens 3d）的畫面規格：三格摘要、分數靠右、不及格不只靠顏色。
///
/// 測的是頁面組出來的兩個元件而不是 ScoreViewerPage 本身：那一頁是
/// `GetView<ScorePageController>`，要跑起來得先備妥登入狀態與整個 store，
/// 而這裡要守的規格全都在這兩個元件裡。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadTestL10n();
  });

  tearDown(() async {
    await loadTestL10n();
  });

  ScoreItemJson item({
    String name = '電子學',
    String courseId = 'EE2010301',
    String credit = '3',
    String score = 'A',
    String remark = '',
    String generalDimension = '',
  }) =>
      ScoreItemJson(
        courseId: courseId,
        name: name,
        credit: credit,
        score: score,
        generalDimension: generalDimension,
        remark: remark,
      );

  /// 不走 AppThemes：那一份會讓 google_fonts 在測試裡去抓字體檔。
  ThemeData theme() {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0));
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: AppTypography.textTheme(ThemeData.light().textTheme),
      extensions: [TatTokens.from(scheme)],
    );
  }

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(
      theme: theme(),
      home: Scaffold(body: Center(child: child)),
    ));
    await tester.pumpAndSettle();
  }

  group('ScoreSummaryStrip', () {
    testWidgets('三格摘要：GPA / 學分 / 不及格', (tester) async {
      await pump(
          tester, const ScoreSummaryStrip(gpa: '3.82', credit: 21, failed: 1));

      expect(find.text('GPA'), findsOneWidget);
      expect(find.text('3.82'), findsOneWidget);
      expect(find.text('學分'), findsOneWidget);
      expect(find.text('21'), findsOneWidget);
      expect(find.text('不及格'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('算不出 GPA 時放破折號，不是 0.00 也不是 NaN', (tester) async {
      await pump(
          tester, const ScoreSummaryStrip(gpa: null, credit: 0, failed: 0));

      expect(find.text('—'), findsOneWidget);
      expect(find.text('NaN'), findsNothing);
      expect(find.text('0.00'), findsNothing);
    });

    testWidgets('數字是等寬數字，切學期時位數不會左右跳', (tester) async {
      await pump(
          tester, const ScoreSummaryStrip(gpa: '3.82', credit: 21, failed: 0));

      final style = tester.widget<Text>(find.text('3.82')).style!;
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    });

    testWidgets('0 門不及格不標紅，有的話才換色', (tester) async {
      await pump(
          tester, const ScoreSummaryStrip(gpa: '3.82', credit: 21, failed: 0));
      final none = tester.widget<Text>(find.text('0')).style!.color;

      await pump(
          tester, const ScoreSummaryStrip(gpa: '3.82', credit: 21, failed: 2));
      final some = tester.widget<Text>(find.text('2')).style!.color;

      expect(none, isNot(some));
    });
  });

  group('ScoreRow', () {
    testWidgets('課名、課號與學分；括號學分照樣顯示數字', (tester) async {
      await pump(tester, ScoreRow(score: item(credit: '(3)')));

      expect(find.text('電子學'), findsOneWidget);
      expect(find.textContaining('EE2010301'), findsOneWidget);
      expect(find.textContaining('3 學分'), findsOneWidget);
    });

    testWidgets('通識向度接在課號後面', (tester) async {
      await pump(tester, ScoreRow(score: item(generalDimension: 'A')));

      expect(find.textContaining('向度 A'), findsOneWidget);
    });

    testWidgets('整列可點，點下去走注入進來的那一段', (tester) async {
      var taps = 0;
      await pump(tester, ScoreRow(score: item(), onTap: () => taps++));

      await tester.tap(find.text('電子學'));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('不及格：底色、chip 與紅字三種都在，不只靠顏色', (tester) async {
      await pump(tester, ScoreRow(score: item(score: 'E')));

      // chip 的字與 Semantics 各一份。
      expect(find.text('不及格'), findsOneWidget);

      final scoreStyle = tester.widget<Text>(find.text('E')).style!;
      final chipStyle = tester.widget<Text>(find.text('不及格')).style!;
      expect(scoreStyle.color, isNot(chipStyle.color));

      final box = tester.widget<Container>(find
          .descendant(
            of: find.byType(ScoreRow),
            matching: find.byType(Container),
          )
          .first);
      expect((box.decoration as BoxDecoration).color, isNotNull);
    });

    testWidgets('D 依現行規則算不及格，畫面不另立一套判斷', (tester) async {
      await pump(tester, ScoreRow(score: item(score: 'D')));

      expect(find.text('不及格'), findsOneWidget);
    });

    testWidgets('及格的列沒有不及格 chip', (tester) async {
      await pump(tester, ScoreRow(score: item(score: 'A+')));

      expect(find.text('不及格'), findsNothing);
      expect(find.text('A+'), findsOneWidget);
    });

    testWidgets('沒有成績也沒有備註時顯示「尚未評分」，不是裸的「-」', (tester) async {
      await pump(tester, ScoreRow(score: item(score: '-')));

      expect(find.text('尚未評分'), findsOneWidget);
      expect(find.text('-'), findsNothing);
    });

    testWidgets('沒有成績但有備註時顯示備註', (tester) async {
      await pump(tester, ScoreRow(score: item(score: '-', remark: '抵免')));

      expect(find.text('抵免'), findsOneWidget);
      expect(find.text('尚未評分'), findsNothing);
    });

    testWidgets('學校寫的「通過」換成跟著語系走的字', (tester) async {
      await loadTestL10n(const Locale('en'));
      await pump(tester, ScoreRow(score: item(score: '通過', credit: '0')));

      expect(find.text('Passed'), findsOneWidget);
      expect(find.text('通過'), findsNothing);
    });

    testWidgets('分數是等寬數字並靠右', (tester) async {
      await pump(tester, ScoreRow(score: item(score: 'A')));

      final text = tester.widget<Text>(find.text('A'));
      expect(text.textAlign, TextAlign.end);
      expect(text.style!.fontFeatures,
          contains(const FontFeature.tabularFigures()));
    });

    testWidgets('不及格的列有一句讀得出來的 Semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, ScoreRow(score: item(score: 'E')));

      expect(find.bySemanticsLabel(RegExp('不及格')), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('電子學')), findsWidgets);
      handle.dispose();
    });
  });
}
