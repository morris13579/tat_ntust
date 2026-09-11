import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/model/course/course_department.dart';
import 'package:flutter_app/src/model/course/course_query_filter.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 搜尋課程的篩選條件。
///
/// 是一頁而不是選單：條件有四組、其中系所還要往下鑽一層學院，塞進 72% 高的
/// bottom sheet 只會全部擠在一起。每一組各自一塊，滑起來找得到東西。
///
/// 每一個選項都對得上 `/api/courses` 真的吃的參數（見 [CourseQueryFilter]）。
class CourseFilterPage extends StatefulWidget {
  const CourseFilterPage({
    super.key,
    required this.filter,
    required this.loadColleges,
    required this.loadDepartments,
  });

  final CourseQueryFilter filter;

  final Future<List<CollegeJson>> Function() loadColleges;
  final Future<List<DepartmentJson>> Function(String collegeNo) loadDepartments;

  @override
  State<CourseFilterPage> createState() => _CourseFilterPageState();
}

class _CourseFilterPageState extends State<CourseFilterPage> {
  late CourseQueryFilter _filter = widget.filter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: mainAppbar(
        title: R.current.courseSearchFilterTitle,
        isShowBack: true,
        action: [
          if (_filter.hasRefinements)
            TextButton(
              onPressed: () => setState(() => _filter = CourseQueryFilter(
                    courseNo: _filter.courseNo,
                    courseName: _filter.courseName,
                    teacher: _filter.teacher,
                  )),
              child: Text(R.current.courseSearchReset),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: [
          _header(R.current.courseSearchDepartment),
          _row(
            index: 0,
            length: 1,
            label: _filter.department?.displayName ??
                R.current.courseSearchDepartmentAny,
            selected: _filter.department != null,
            trailing: LucideIcons.chevronRight,
            onTap: _pickDepartment,
          ),
          _header(R.current.courseSearchLevel),
          for (final (i, level) in CourseProgramLevel.values.indexed) ...[
            if (i > 0) const SizedBox(height: 2),
            _row(
              index: i,
              length: CourseProgramLevel.values.length,
              label: _levelLabel(level),
              selected: _filter.level == level,
              onTap: () =>
                  setState(() => _filter = _filter.copyWith(level: level)),
            ),
          ],
          _header(R.current.courseSearchOptions),
          ..._toggles(),
          _header(R.current.courseSearchDimension),
          ..._dimensions(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: TatTokens.heightButton,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _filter),
              child: Text(R.current.courseSearchFilterApply),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _toggles() {
    final items = <(String, bool, VoidCallback)>[
      (
        R.current.courseSearchForeignLanguage,
        _filter.foreignLanguageOnly,
        () => setState(() => _filter =
            _filter.copyWith(foreignLanguageOnly: !_filter.foreignLanguageOnly))
      ),
      (
        R.current.courseSearchGeneral,
        _filter.generalOnly,
        () => setState(
            () => _filter = _filter.copyWith(generalOnly: !_filter.generalOnly))
      ),
      (
        R.current.courseSearchIntensive,
        _filter.intensiveOnly,
        () => setState(() =>
            _filter = _filter.copyWith(intensiveOnly: !_filter.intensiveOnly))
      ),
      (
        R.current.courseSearchNtustOnly,
        _filter.ntustOnly,
        () => setState(
            () => _filter = _filter.copyWith(ntustOnly: !_filter.ntustOnly))
      ),
    ];
    return [
      for (final (i, item) in items.indexed) ...[
        if (i > 0) const SizedBox(height: 2),
        _row(
            index: i,
            length: items.length,
            label: item.$1,
            selected: item.$2,
            onTap: item.$3),
      ],
    ];
  }

  List<Widget> _dimensions() {
    final length = CourseDimension.values.length + 1;
    return [
      _row(
        index: 0,
        length: length,
        label: R.current.courseSearchDimensionAny,
        selected: _filter.dimension == null,
        onTap: () =>
            setState(() => _filter = _filter.copyWith(clearDimension: true)),
      ),
      for (final (i, dimension) in CourseDimension.values.indexed) ...[
        const SizedBox(height: 2),
        _row(
          index: i + 1,
          length: length,
          label: _dimensionLabel(dimension),
          supporting: dimension.code,
          selected: _filter.dimension == dimension,
          onTap: () =>
              setState(() => _filter = _filter.copyWith(dimension: dimension)),
        ),
      ],
    ];
  }

  /// 學院 → 系所兩層。系所是「這個系開的課」，送出去就是課號前兩碼。
  Future<void> _pickDepartment() async {
    final colleges = await widget.loadColleges();
    if (!mounted || colleges.isEmpty) return;
    final college = await _pickOne<CollegeJson>(
      title: R.current.courseSearchCollege,
      items: colleges,
      labelOf: (c) => c.displayName,
    );
    if (college == null || !mounted) return;
    final departments = await widget.loadDepartments(college.no);
    if (!mounted || departments.isEmpty) return;
    final department = await _pickOne<DepartmentJson>(
      title: college.displayName,
      items: departments,
      labelOf: (d) => d.displayName,
      allowAny: true,
    );
    if (!mounted) return;
    setState(() => _filter = department == null
        ? _filter.copyWith(clearDepartment: true)
        : _filter.copyWith(department: department));
  }

  Future<T?> _pickOne<T>({
    required String title,
    required List<T> items,
    required String Function(T item) labelOf,
    bool allowAny = false,
  }) =>
      Navigator.of(context).push<T>(MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: mainAppbar(title: title, isShowBack: true),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              if (allowAny) ...[
                _plainRow(
                  index: 0,
                  length: items.length + 1,
                  label: R.current.courseSearchDepartmentAny,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(height: 2),
              ],
              for (final (i, item) in items.indexed) ...[
                if (i > 0 || allowAny) const SizedBox(height: 2),
                _plainRow(
                  index: allowAny ? i + 1 : i,
                  length: allowAny ? items.length + 1 : items.length,
                  label: labelOf(item),
                  onTap: () => Navigator.pop(context, item),
                ),
              ],
            ],
          ),
        ),
      ));

  Widget _header(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(
          title,
          style: context.text.labelMedium
              ?.copyWith(color: context.scheme.onSurfaceVariant),
        ),
      );

  Widget _plainRow({
    required int index,
    required int length,
    required String label,
    required VoidCallback onTap,
  }) =>
      _row(index: index, length: length, label: label, onTap: onTap);

  /// 一列。選中是一塊 primaryContainer 加打勾，跟其他選單同一套；沒有描邊。
  Widget _row({
    required int index,
    required int length,
    required String label,
    required VoidCallback onTap,
    String? supporting,
    bool selected = false,
    IconData? trailing,
  }) {
    final scheme = context.scheme;
    final foreground = selected ? scheme.primary : scheme.onSurface;
    return Material(
      color: selected ? scheme.primaryContainer : context.tokens.card,
      borderRadius: UIUtils.getBorderRadius(index, length),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: TatTokens.heightRow),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        style: context.text.bodyLarge
                            ?.copyWith(height: 1.4, color: foreground)),
                    if (supporting != null)
                      Text(supporting,
                          style: context.text.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (selected && trailing == null)
                Icon(LucideIcons.check, size: 20, color: scheme.primary),
              if (trailing != null)
                Icon(trailing, size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  String _levelLabel(CourseProgramLevel level) => switch (level) {
        CourseProgramLevel.any => R.current.courseSearchLevelAny,
        CourseProgramLevel.underGraduate => R.current.courseSearchLevelUnder,
        CourseProgramLevel.master => R.current.courseSearchLevelMaster,
      };

  String _dimensionLabel(CourseDimension dimension) => switch (dimension) {
        CourseDimension.a => R.current.courseDimensionA,
        CourseDimension.b => R.current.courseDimensionB,
        CourseDimension.c => R.current.courseDimensionC,
        CourseDimension.d => R.current.courseDimensionD,
        CourseDimension.e => R.current.courseDimensionE,
        CourseDimension.f => R.current.courseDimensionF,
      };
}

/// 中英文名字由畫面挑：model 讀 `LanguageUtils` 會是 model -> util 的上行邊。
extension CollegeDisplayName on CollegeJson {
  String get displayName =>
      LanguageUtils.getLangIndex() == LangEnum.zh ? name : engName;
}

extension DepartmentDisplayName on DepartmentJson {
  String get displayName =>
      LanguageUtils.getLangIndex() == LangEnum.zh ? name : engName;
}
