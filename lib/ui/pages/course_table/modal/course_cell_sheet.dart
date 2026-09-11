import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/ui/components/input/input_field.dart';
import 'package:flutter_app/ui/components/sheet/tat_bottom_sheet.dart';
import 'package:flutter_app/ui/components/toast/tat_toast.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/tat_dialog.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:get/get.dart';

/// 點課表格子之後使用者選了什麼。
enum CourseCellAction {
  moodle,
  remove,
  detail,
  editCourseId,
}

/// 課表格子的內容型選單：色帶標題、資料表、主次按鈕。
///
/// 動作只回報、不執行。導頁與移除都會再開一層畫面，而同一時間只允許一個
/// 浮層，所以要先讓這個選單關掉。
Future<CourseCellAction?> showCourseCellSheet({
  required BuildContext context,
  required CourseInfoJson courseInfo,
  required String time,
  required Color color,
}) =>
    showTatContentSheet<CourseCellAction>(
      context: context,
      builder: (context) => _CourseCellContent(
        courseInfo: courseInfo,
        time: time,
        color: color,
      ),
    );

/// 移除課程的確認。破壞性的是非題，所以是對話框而不是選單。
///
/// 標題就是要移除的那門課，主鈕用動作的名字。
Future<bool> showCourseRemoveDialog(String courseName) async {
  final result = await showTatDialog<bool>(
    dialog: TatDialog(
      title: courseName,
      body: null,
      kind: TatDialogKind.warning,
      destructive: true,
      secondary: TatDialogAction(
        label: R.current.cancel,
        onPressed: () => Get.back<bool>(result: false),
      ),
      primary: TatDialogAction(
        label: R.current.remove,
        onPressed: () => Get.back<bool>(result: true),
      ),
    ),
  );
  return result ?? false;
}

/// 改課號並寫回硬碟。自訂課程的課號可能是空的，改過才有詳情可以看。
Future<void> editCourseCellId(CourseInfoJson courseInfo) async {
  final course = courseInfo.main.course;
  final value = await showTatDialog<String>(
    dialog: _CourseIdEditDialog(value: course.id),
  );
  if (value == null) return;
  course.id = value;
  // 改過的課號要確定寫進硬碟才算完成。
  await Model.instance.saveOtherSetting();
}

class _CourseCellContent extends StatelessWidget {
  const _CourseCellContent({
    required this.courseInfo,
    required this.time,
    required this.color,
  });

  final CourseInfoJson courseInfo;
  final String time;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final course = courseInfo.main.course;
    final classroomName = courseInfo.main.getClassroomName();
    final teacherName = courseInfo.main.getTeacherName();
    // 色帶取格子的顏色，使用者才認得出點到的是哪一格。底色調淡、字調深，
    // 兩者都從同一個色相算出來，暗色模式下也不會變成一塊刺眼的粉彩。
    final band = _bandColors(context, color);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: band.background,
            borderRadius: BorderRadius.circular(TatTokens.radiusCard),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(course.name,
                  style: context.text.headlineSmall?.copyWith(
                      color: band.foreground, fontWeight: FontWeight.w600)),
              if (classroomName.isNotEmpty || time.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 12,
                    children: [
                      if (classroomName.isNotEmpty)
                        Text(classroomName,
                            style: context.text.titleMedium?.copyWith(
                                color: band.foreground,
                                fontWeight: FontWeight.w600)),
                      if (time.isNotEmpty)
                        Text(time,
                            style: context.text.bodyLarge
                                ?.copyWith(color: band.foreground)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(TatTokens.radiusCard),
            ),
            child: Column(
              children: [
                if (teacherName.isNotEmpty)
                  _DataRow(
                    icon: LucideIcons.user,
                    label: R.current.instructor,
                    value: teacherName,
                  ),
                if (teacherName.isNotEmpty && course.id.isNotEmpty)
                  Divider(height: 1, color: scheme.outlineVariant),
                if (course.id.isNotEmpty)
                  _DataRow(
                    icon: LucideIcons.hash,
                    label: R.current.courseId,
                    value: course.id,
                    monospace: true,
                    actions: [
                      _RowAction(
                        icon: LucideIcons.copy,
                        tooltip: R.current.copy,
                        onPressed: () => _copy(course.id),
                      ),
                      _RowAction(
                        icon: LucideIcons.squarePen,
                        tooltip: R.current.edit,
                        onPressed: () => Navigator.pop(
                            context, CourseCellAction.editCourseId),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            children: [
              if (course.select)
                _SheetButton(
                  icon: LucideIcons.graduationCap,
                  label: R.current.courseData,
                  isPrimary: true,
                  onPressed: () =>
                      Navigator.pop(context, CourseCellAction.moodle),
                )
              else
                _SheetButton(
                  icon: LucideIcons.trash2,
                  label: R.current.remove,
                  destructive: true,
                  onPressed: () =>
                      Navigator.pop(context, CourseCellAction.remove),
                ),
              const SizedBox(height: 10),
              _SheetButton(
                icon: LucideIcons.fileText,
                label: R.current.details,
                onPressed: () =>
                    Navigator.pop(context, CourseCellAction.detail),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    TatToast.show(R.current.copy);
  }

  /// 色帶的底色與前景。亮色時是淡底深字，暗色時把同一個色相壓暗當底、
  /// 提亮當字，不要直接把課表格子的粉彩色整塊搬過來。
  ({Color background, Color foreground}) _bandColors(
      BuildContext context, Color source) {
    final hsl = HSLColor.fromColor(source);
    final dark = context.scheme.brightness == Brightness.dark;
    return (
      background: hsl
          .withSaturation((hsl.saturation * (dark ? 0.55 : 0.85)).clamp(0, 1))
          .withLightness(dark ? 0.22 : 0.88)
          .toColor(),
      foreground: hsl
          .withSaturation((hsl.saturation * 0.9).clamp(0, 1))
          .withLightness(dark ? 0.82 : 0.28)
          .toColor(),
    );
  }
}

/// 資料表的一列：圖示欄、固定寬的標籤欄、值，右邊可以帶動作鈕。
class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.icon,
    required this.label,
    required this.value,
    this.actions = const [],
    this.monospace = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final List<Widget> actions;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final valueStyle = context.text.titleSmall?.copyWith(
      color: scheme.onSurface,
      fontFamily: monospace ? 'monospace' : null,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
          14, actions.isEmpty ? 13 : 11, 14, actions.isEmpty ? 13 : 11),
      child: Row(
        children: [
          Icon(icon, size: 19, color: scheme.onSurfaceVariant),
          const SizedBox(width: 11),
          SizedBox(
            width: 68,
            child: Text(
              label,
              style: context.text.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(child: Text(value, style: valueStyle)),
          for (final action in actions) ...[
            const SizedBox(width: 9),
            action,
          ],
        ],
      ),
    );
  }
}

/// 資料列右邊的小方鈕（複製、改課號）。
class _RowAction extends StatelessWidget {
  const _RowAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(TatTokens.radiusButton),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 17, color: scheme.primary),
          ),
        ),
      ),
    );
  }
}

/// 選單底部的按鈕，整排疊放。主鈕填色、次鈕外框，破壞性動作用 error 色。
class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final accent = destructive ? scheme.error : scheme.onSurface;
    final filled = isPrimary || destructive;
    final background = destructive
        ? scheme.errorContainer
        : (isPrimary ? scheme.primary : Colors.transparent);
    final foreground = destructive
        ? scheme.onErrorContainer
        : (isPrimary ? scheme.onPrimary : accent);

    // Material 不接受同時給 shape 與 borderRadius，次要按鈕要畫外框就只能走
    // shape，所以兩條路徑分開寫。
    return Material(
      color: background,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side:
            filled ? BorderSide.none : BorderSide(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(TatTokens.radiusButton),
      ),
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 9),
              Text(
                label,
                style: context.text.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: filled ? FontWeight.w600 : FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 改課號。自訂課程可能沒有課號，補上之後才查得到詳細內容。
class _CourseIdEditDialog extends StatefulWidget {
  const _CourseIdEditDialog({required this.value});

  final String value;

  @override
  State<_CourseIdEditDialog> createState() => _CourseIdEditDialogState();
}

class _CourseIdEditDialogState extends State<_CourseIdEditDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TatDialog(
      title: R.current.courseId,
      body: null,
      kind: TatDialogKind.info,
      content: InputField(
        hint: R.current.courseId,
        controller: _controller,
      ),
      secondary: TatDialogAction(
        label: R.current.cancel,
        onPressed: () => Get.back<String>(),
      ),
      primary: TatDialogAction(
        label: R.current.sure,
        onPressed: () => Get.back<String>(result: _controller.text.trim()),
      ),
    );
  }
}
