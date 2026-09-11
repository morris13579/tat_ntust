import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/ui/pages/course_table/modal/course_cell_sheet.dart';
import 'package:flutter_app/ui/pages/course_table/modal/favorite_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 對話框裡的 TextEditingController 必須由 StatefulWidget 的 State 持有並釋放。
/// 在方法裡 new 一個區域變數再塞進對話框的 widget 樹，沒有人 dispose，
/// 每開一次就漏一個。
///
/// 測試摸不到 private 欄位，所以從畫面上的 EditableText 拿到同一個物件，
/// 等對話框真的被移除之後再 dispose 一次：ChangeNotifier 在 debug mode 下
/// 重複 dispose 會丟 FlutterError，那就是「第一次已經被釋放」的證據。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadTestL10n();
    // FileItem 的副標題會走 FileUtils.formatTime -> DateFormat，
    // 沒有先初始化 locale 資料會直接丟 LocaleDataException。
    await initializeDateFormatting();
  });

  TextEditingController currentController(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText)).controller;

  void expectAlreadyDisposed(TextEditingController controller) {
    expect(
      () => controller.dispose(),
      throwsA(isA<FlutterError>()),
      reason: '對話框關掉之後 TextEditingController 必須已經被 dispose',
    );
  }

  /// 這些對話框都是從別的浮層關掉之後才開，測試裡用一顆按鈕代表那個觸發點。
  Future<void> pumpOpener(WidgetTester tester, VoidCallback onPressed) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: Center(
            child: TextButton(onPressed: onPressed, child: const Text('open')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('課程代碼的編輯框', () {
    setUp(resetAppStatics);

    testWidgets('關閉後 controller 已被 dispose', (tester) async {
      final courseInfo = CourseInfoJson(
        main: CourseMainInfoJson(
          course: CourseMainJson(name: '測試課程', id: 'AT1234', select: false),
        ),
      );

      await pumpOpener(tester, () => unawaited(editCourseCellId(courseInfo)));

      final controller = currentController(tester);
      expect(controller.text, 'AT1234');

      await tester.tap(find.text(R.current.cancel));
      await tester.pumpAndSettle();

      expectAlreadyDisposed(controller);
      // 取消不會動到課號。
      expect(courseInfo.main.course.id, 'AT1234');
    });
  });

  group('刪除收藏的確認框', () {
    setUp(resetAppStatics);

    /// 舊版的「確定」只呼叫 onDelete，從來沒有人 pop，對話框會留在畫面上。
    testWidgets('按下刪除會關掉對話框並回報 true', (tester) async {
      bool? result;
      await pumpOpener(tester, () async {
        result = await showFavoriteDeleteDialog('B11234567 114-1');
      });

      expect(find.text('B11234567 114-1'), findsOneWidget);

      await tester.tap(find.text(R.current.delete));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.text('B11234567 114-1'), findsNothing);
    });

    testWidgets('取消會關掉對話框並回報 false', (tester) async {
      bool? result;
      await pumpOpener(tester, () async {
        result = await showFavoriteDeleteDialog('B11234567 114-1');
      });

      await tester.tap(find.text(R.current.cancel));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.text('B11234567 114-1'), findsNothing);
    });
  });
}
