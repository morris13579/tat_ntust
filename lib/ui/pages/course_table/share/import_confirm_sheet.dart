import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_time.dart';
import 'package:flutter_app/src/repository/ntust_repository.dart';
import 'package:flutter_app/src/util/course_table_control.dart';
import 'package:flutter_app/src/util/course_table_share_codec.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/components/sheet/tat_bottom_sheet.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:sprintf/sprintf.dart';

/// 預覽最多列幾門課。學號、學年期與門數三個值就足以判斷是不是要的那一份，
/// 課號只是二次確認；列太多只會把按鈕推到看不見的地方。
const int _previewLimit = 3;

/// 查課的注入點。**刻意不讓呼叫端指定學期**：學期一律由這一頁自己從 payload
/// 算出來，呼叫端連傳錯的機會都沒有。
///
/// 這不是潔癖。實測過同一個課號在不同學期會回不同的老師、不同的上課時間與
/// 不同的教室，而課號右邊印的是 QR 自己帶的節次——查錯學期會排出一列「看起來
/// 完全自洽」的假資料，畫面上沒有任何破綻。
typedef LookupSharedCourses = Future<List<SharedCourseLookup>> Function(
  SemesterJson semester,
  List<String> courseIds, {
  void Function(SharedCourseLookup lookup)? onResolved,
  bool Function()? isCancelled,
});

/// 匯入前的確認。回傳 true 代表使用者按下匯入。
///
/// 標題與學號、摘要是同一塊置中的落款，所以不走選單自己的標題列。
///
/// 課名與教室是進來之後才補的：QR 只帶課號與節次，格子當下就畫得出來，查不到
/// 或沒網路也照樣匯得進去。學分 querycourse 有，但摘要那一行不寫——那是整份
/// 課表的合計，而這裡只查了前幾門。
Future<bool> showImportConfirmSheet({
  required BuildContext context,
  required SharedTablePayload payload,
  required LookupSharedCourses lookup,
}) async {
  final confirmed = await showTatContentSheet<bool>(
    context: context,
    builder: (context) =>
        _ImportConfirmContent(payload: payload, lookup: lookup),
  );
  // 下滑關掉或點遮罩都會回 null。沒有明白按下匯入就不算答應。
  return confirmed ?? false;
}

class _ImportConfirmContent extends StatefulWidget {
  const _ImportConfirmContent({required this.payload, required this.lookup});

  final SharedTablePayload payload;
  final LookupSharedCourses lookup;

  @override
  State<_ImportConfirmContent> createState() => _ImportConfirmContentState();
}

class _ImportConfirmContentState extends State<_ImportConfirmContent> {
  /// 查回來的課，以課號為鍵。沒有的鍵代表還在查或查不到。
  final _resolved = <String, CourseMainInfoJson>{};

  late final List<SharedCourse> _preview =
      widget.payload.courses.take(_previewLimit).toList();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  /// 只查畫得出來的那幾門。整份課表的課名由 SharedTablePage 進去之後再補。
  Future<void> _load() async {
    await widget.lookup(
      SemesterJson(
        year: widget.payload.year,
        semester: widget.payload.semester,
      ),
      [for (final course in _preview) course.id],
      isCancelled: () => !mounted,
      onResolved: (found) {
        if (!mounted || found.courses.isEmpty) return;
        setState(() => _resolved[found.id] = found.courses.first);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final text = context.text;
    final preview = _preview;
    final hidden = widget.payload.courses.length - preview.length;
    // 「還有 N 門」跟課號列是同一塊，圓角才收得起來。
    final rows = preview.length + (hidden > 0 ? 1 : 0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
          child: Column(
            children: [
              Text(R.current.importConfirmTitle, style: text.titleMedium),
              const SizedBox(height: 5),
              Text(
                widget.payload.studentId,
                style: AppTypography.tabular(text.titleLarge!),
              ),
              const SizedBox(height: 5),
              Text(
                '${widget.payload.year}-${widget.payload.semester}'
                ' · ${sprintf(R.current.courseCount, [
                      widget.payload.courses.length
                    ])}',
                style: AppTypography.tabular(text.bodySmall!)
                    .copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < preview.length; i++) ...[
                if (i > 0) const SizedBox(height: 2),
                _PreviewBlock(
                  borderRadius: UIUtils.getBorderRadius(i, rows),
                  child: _CoursePreviewRow(
                    course: preview[i],
                    found: _resolved[preview[i].id],
                  ),
                ),
              ],
              if (hidden > 0) ...[
                if (preview.isNotEmpty) const SizedBox(height: 2),
                _PreviewBlock(
                  borderRadius: UIUtils.getBorderRadius(rows - 1, rows),
                  child: Text(
                    sprintf(R.current.importMoreCourses, [hidden]),
                    style: text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(
            children: [
              // 寬度刻意不等分：主要動作要明顯大一顆。取消不是破壞性動作，
              // 所以是中性的灰底而不是 error 色。
              Expanded(
                flex: 5,
                child: _SheetButton(
                  label: R.current.cancel,
                  onPressed: () => Navigator.pop(context, false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 7,
                child: _SheetButton(
                  label: R.current.importConfirmOpen,
                  icon: LucideIcons.users,
                  isPrimary: true,
                  onPressed: () => Navigator.pop(context, true),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 預覽清單的一塊。選單本身就是 tokens.card，列要再深一階才看得出是一塊一塊的。
class _PreviewBlock extends StatelessWidget {
  const _PreviewBlock({required this.borderRadius, required this.child});

  final BorderRadius? borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.scheme.surfaceContainerHighest,
      borderRadius: borderRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: child,
      ),
    );
  }
}

/// 預覽的一列。純展示，不吃點擊。
///
/// 課名查回來之前（或查不到）就印課號：留白會讓人以為這門課壞了，而課號本來
/// 就是使用者對得起來的東西。右邊的節次一律來自 QR，不用查回來的那一份——
/// 對方存下來的就是這個時間。
class _CoursePreviewRow extends StatelessWidget {
  const _CoursePreviewRow({required this.course, this.found});

  final SharedCourse course;
  final CourseMainInfoJson? found;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final text = context.text;
    final time = _slotsLabel(course.slots);
    final name = found?.course.name.trim() ?? '';
    final classroom = found?.getClassroomName().trim() ?? '';
    final trailing = [time, classroom].where((e) => e.isNotEmpty).join(' · ');

    return Row(
      children: [
        Expanded(
          child: name.isEmpty
              ? Text(
                  course.id,
                  style: AppTypography.tabular(text.bodyMedium!)
                      .copyWith(color: scheme.onSurfaceVariant),
                )
              : Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(color: scheme.onSurface),
                ),
        ),
        if (trailing.isNotEmpty) ...[
          const SizedBox(width: 12),
          Text(
            trailing,
            style: AppTypography.tabular(text.bodySmall!)
                .copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// 選單底下的一顆按鈕。48 而不是主題預設的 44：這一排是整張選單的收尾。
class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isPrimary = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SizedBox(
      height: 48,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor:
              isPrimary ? scheme.primary : scheme.surfaceContainerHighest,
          foregroundColor: isPrimary ? scheme.onPrimary : scheme.onSurface,
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 19),
              const SizedBox(width: 9),
            ],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

/// 把格子組成「一 2·3　三 4」。同一天的節次併在一起，天與天之間用全形空白
/// 分開，中間點才不會被誤讀成跨天。
String _slotsLabel(List<SharedSlot> slots) {
  final names = courseDayNames();
  final control = CourseTableControl();
  final byDay = <Day, List<String>>{};
  for (final slot in slots) {
    // sectionStringList 只有 14 格，沒有 t_UnKnown；QR 解不出這一格，但這裡
    // 收的是外部資料，越界會直接炸掉整張選單。
    if (slot.section.index >= CourseTableControl.sectionLength) continue;
    byDay
        .putIfAbsent(slot.day, () => [])
        .add(control.getSectionString(slot.section.index));
  }
  return [
    for (final entry in byDay.entries)
      '${names[entry.key.index]} ${entry.value.join('·')}',
  ].join('　');
}
