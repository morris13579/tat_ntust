import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/ui/components/sheet/tat_bottom_sheet.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/tat_dialog.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:get/get.dart';
import 'package:sprintf/sprintf.dart';

/// 使用者在收藏清單上要做的事。
enum FavoriteIntent { apply, delete }

class FavoriteChoice {
  const FavoriteChoice(this.intent, this.index);

  final FavoriteIntent intent;
  final int index;
}

/// 收藏的課表清單。回傳 null 代表沒選。
///
/// [selected] 是目前畫面上那一份的標籤，用來標出「就是這一個」——一整排
/// 長得一樣的學期，沒有這個記號就看不出自己在哪。
///
/// 刪除只回報意圖、不在這裡確認：同一時間只允許一個浮層，選單開著時不能再
/// 疊一個對話框上去，所以由呼叫端關掉選單之後再問。
Future<FavoriteChoice?> showFavoriteSheet({
  required BuildContext context,
  required List<CourseTableJson> value,
  String? selected,
}) =>
    showTatContentSheet<FavoriteChoice>(
      context: context,
      title: R.current.loadFavorite,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int index = 0; index < value.length; index++)
            _FavoriteRow(
              label: favoriteLabel(value[index]),
              supporting: favoriteSummary(value[index]),
              isSelected: favoriteLabel(value[index]) == selected,
              index: index,
            ),
        ],
      ),
    );

/// 刪除收藏的確認。破壞性的是非題，所以是對話框而不是選單。
///
/// 標題就是要刪掉的那一份課表，主鈕用動作的名字——標題再寫一次「刪除」只是
/// 把同一個字說兩遍。
Future<bool> showFavoriteDeleteDialog(String label) async {
  final result = await showTatDialog<bool>(
    dialog: TatDialog(
      title: label,
      body: null,
      kind: TatDialogKind.warning,
      destructive: true,
      secondary: TatDialogAction(
        label: R.current.cancel,
        onPressed: () => Get.back<bool>(result: false),
      ),
      primary: TatDialogAction(
        label: R.current.delete,
        onPressed: () => Get.back<bool>(result: true),
      ),
    ),
  );
  return result ?? false;
}

/// 不放 studentName：現存的 querycourse 路徑一律寫死空字串，加上去會讓新存的
/// 課表多一個空格、舊的又有名字，同一份清單兩種樣子。
String favoriteLabel(CourseTableJson value) =>
    favoriteLabelOf(value.studentId, value.courseSemester);

/// 同一個格式，但給手上只有學號與學期、沒有整份課表的呼叫端用。
String favoriteLabelOf(String studentId, SemesterJson semester) =>
    sprintf("%s %s-%s", [studentId, semester.year, semester.semester]);

/// 「6 門課 · 14 學分」。同一個學號會有好幾個學期，光看標籤分不出哪一份
/// 才是要找的那一份。
String favoriteSummary(CourseTableJson value) =>
    '${sprintf(R.current.courseCount, [value.getCourseIdList().length])}'
    ' · ${sprintf(R.current.creditCount, [value.getTotalCredit()])}';

class _FavoriteRow extends StatelessWidget {
  const _FavoriteRow({
    required this.label,
    required this.supporting,
    required this.isSelected,
    required this.index,
  });

  final String label;
  final String supporting;
  final bool isSelected;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final foreground =
        isSelected ? scheme.onPrimaryContainer : scheme.onSurface;
    return Material(
      color: isSelected ? scheme.primaryContainer : Colors.transparent,
      child: InkWell(
        onTap: () =>
            Navigator.pop(context, FavoriteChoice(FavoriteIntent.apply, index)),
        child: Container(
          constraints: const BoxConstraints(minHeight: TatTokens.heightRow),
          padding: const EdgeInsets.only(left: 20, right: 8),
          child: Row(
            children: [
              SizedBox(
                width: TatTokens.iconColumn,
                child: Icon(LucideIcons.graduationCap,
                    size: 20,
                    color: isSelected ? foreground : scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.tabular(context.text.bodyLarge!)
                          .copyWith(height: 1.5, color: foreground),
                    ),
                    Text(
                      supporting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.tabular(context.text.bodySmall!)
                          .copyWith(
                              color: isSelected
                                  ? foreground
                                  : scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(LucideIcons.check, size: 20, color: foreground),
              IconButton(
                // 原本只有長按能刪，沒有任何提示；破壞性動作靠 error 色自己站出來。
                tooltip: R.current.delete,
                icon: const Icon(LucideIcons.trash2),
                color: scheme.error,
                onPressed: () => Navigator.pop(
                    context, FavoriteChoice(FavoriteIntent.delete, index)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
