import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/util/course_table_conflict.dart';
import 'package:flutter_app/src/util/course_table_control.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 課程佔用的一個格子。
typedef CourseSlot = (Day, SectionNumber);

/// 挑「哪幾節」。
///
/// querycourse 的節次篩選**不在伺服器端**：官方前端送出去的 body 裡根本沒有
/// 節次，是拿回結果之後用每門課的 `Node` 欄位在瀏覽器裡比對的（`OnlyNode` 只是
/// 一個布林旗標，單獨送 1 還會回非 JSON）。所以這一頁只管挑格子，篩選在
/// 搜尋頁本地做。
class CourseSlotPickerPage extends StatefulWidget {
  const CourseSlotPickerPage({super.key, required this.selected});

  final Set<CourseSlot> selected;

  @override
  State<CourseSlotPickerPage> createState() => _CourseSlotPickerPageState();
}

class _CourseSlotPickerPageState extends State<CourseSlotPickerPage> {
  final CourseTableControl _control = CourseTableControl();
  late final Set<CourseSlot> _selected = {...widget.selected};

  List<Day> get _days => CourseTableConflict.days.toList();
  List<SectionNumber> get _sections =>
      CourseTableConflict.sections.toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: mainAppbar(
        title: R.current.courseSearchSlot,
        isShowBack: true,
        action: [
          TextButton(
            onPressed:
                _selected.isEmpty ? null : () => setState(_selected.clear),
            child: Text(R.current.courseSearchReset),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              R.current.courseSearchSlotHint,
              style: context.text.bodySmall
                  ?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: SingleChildScrollView(child: _grid())),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: TatTokens.heightButton,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  child: Text(R.current.courseSearchFilterApply),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Table(
        defaultColumnWidth: const FlexColumnWidth(),
        columnWidths: const {0: FixedColumnWidth(34)},
        children: [
          TableRow(children: [
            const SizedBox.shrink(),
            for (final day in _days) _dayHeader(day),
          ]),
          for (final section in _sections)
            TableRow(children: [
              _sectionHeader(section),
              for (final day in _days) _cell(day, section),
            ]),
        ],
      ),
    );
  }

  /// 整欄（一整天）一起切。全滿就清掉，否則補滿——跟官方前端的全選／清除同一個
  /// 意思，只是收在標頭上，不另外佔一列按鈕。
  Widget _dayHeader(Day day) {
    final all = _sections.map((s) => (day, s)).toList();
    final full = all.every(_selected.contains);
    return InkWell(
      onTap: () => setState(() =>
          full ? _selected.removeAll(all) : _selected.addAll(all)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            _control.getDayString(day.index),
            style: context.text.labelMedium?.copyWith(
                color: full ? context.scheme.primary : context.scheme.onSurface),
          ),
        ),
      ),
    );
  }

  /// 整列（同一節的每一天）一起切。
  Widget _sectionHeader(SectionNumber section) {
    final all = _days.map((d) => (d, section)).toList();
    final full = all.every(_selected.contains);
    return InkWell(
      onTap: () => setState(() =>
          full ? _selected.removeAll(all) : _selected.addAll(all)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Text(
            _control.getSectionString(section.index),
            style: context.text.labelMedium?.copyWith(
                color: full
                    ? context.scheme.primary
                    : context.scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }

  Widget _cell(Day day, SectionNumber section) {
    final slot = (day, section);
    final on = _selected.contains(slot);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: on ? context.scheme.primaryContainer : context.tokens.card,
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(
              () => on ? _selected.remove(slot) : _selected.add(slot)),
          child: SizedBox(
            height: 34,
            child: Center(
              child: on
                  ? Icon(Icons.check,
                      size: 16, color: context.scheme.primary)
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
