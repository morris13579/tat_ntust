import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/ui/components/sheet/tat_bottom_sheet.dart';
import 'package:flutter_app/ui/other/tat_dialog.dart';
import 'package:flutter_app/ui/pages/course_table/component/semester_item.dart';
import 'package:get/get.dart';

/// 可以手動挑的年度範圍，沿用原本 NumberPicker 的 minValue/maxValue。
const int _minYear = 100;
const int _maxYear = 120;

/// 手動挑年度與學期的對話框。
///
/// [allowSelectNull] 為 false 時，使用者沒有選就回「現在這個學期」而不是 null：
/// 呼叫端在那條路徑上沒有 null 的處理。
Future<SemesterJson?> manualSemesterDialog({allowSelectNull = false}) async {
  DateTime dateTime = DateTime.now();
  int year = dateTime.year - 1911;
  int semester = (dateTime.month <= 7 && dateTime.month >= 1) ? 2 : 1;
  if (dateTime.month <= 7) {
    year--;
  }
  SemesterJson before =
      SemesterJson(semester: semester.toString(), year: year.toString());
  SemesterJson? select = await showTatDialog<SemesterJson>(
    dialog: TatDialog(
      title: R.current.selectSemester,
      body: null,
      kind: TatDialogKind.info,
      content: Builder(
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final semester in manualSemesterOptions(before))
              TatSheetOptionRow<SemesterJson>(
                option: TatSheetOption(
                    label: semesterLabel(semester), value: semester),
                isSelected: semester == before,
                tabularFigures: true,
                onTap: () => Navigator.pop(context, semester),
              ),
          ],
        ),
      ),
      secondary: TatDialogAction(
        label: R.current.cancel,
        onPressed: () => Get.back<SemesterJson>(),
      ),
    ),
  );
  if (!allowSelectNull) {
    select ??= before;
  }
  return select;
}

/// 可挑的學期清單：年度 100–120 各三個學期，其中第三個是暑修（存成 "H"）。
///
/// 換掉 NumberPicker 之後仍要把整個範圍列完，否則暑修就沒有入口了。
///
/// [current] 之後的學期挪到清單最後：這裡有六十幾列，而使用者要的幾乎都是
/// 現在或過去，讓「現在」落在第一列比純粹照年度倒序好用。
List<SemesterJson> manualSemesterOptions(SemesterJson current) {
  final all = <SemesterJson>[
    for (int year = _maxYear; year >= _minYear; year--)
      for (final semester in const ['H', '2', '1'])
        SemesterJson(year: year.toString(), semester: semester),
  ];
  final index = all.indexOf(current);
  if (index < 0) return [current, ...all];
  return [...all.sublist(index), ...all.sublist(0, index)];
}
