import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/ui/components/sheet/tat_bottom_sheet.dart';
import 'package:flutter_app/ui/other/tat_dialog.dart';
import 'package:flutter_app/ui/pages/course_table/component/semester_item.dart';

/// 選學期。「挑一個」用底部選單，回傳 null 代表沒選。
///
/// [dismissible] 為 false 時改開對話框：有些呼叫端收到 null 會悄悄退回清單的
/// 第一個學期，使用者會拿到不是自己選的那一個，那條路徑上「關掉」不是合法的
/// 答案。選單一律可以下滑與點遮罩關閉，表達不了這件事。
Future<SemesterJson?> showSemesterSheet({
  required BuildContext context,
  required List<SemesterJson> semesterList,
  SemesterJson? selected,
  bool dismissible = true,
}) {
  final options = [
    for (final semester in semesterList)
      TatSheetOption(label: semesterLabel(semester), value: semester),
  ];

  if (!dismissible) {
    return showTatDialog<SemesterJson>(
      dialog: TatDialog(
        title: R.current.selectSemester,
        body: null,
        kind: TatDialogKind.info,
        content: Builder(
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final option in options)
                TatSheetOptionRow<SemesterJson>(
                  option: option,
                  isSelected: option.value == selected,
                  tabularFigures: true,
                  onTap: () => Navigator.pop(context, option.value),
                ),
            ],
          ),
        ),
      ),
    );
  }

  return showTatSingleSelectSheet<SemesterJson>(
    context: context,
    title: R.current.selectSemester,
    options: options,
    selected: selected,
    // 歷年清單會超過畫面高度，標題列放關閉鈕就不必再多一列「取消」。
    showClose: true,
    tabularFigures: true,
  );
}
