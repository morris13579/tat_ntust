import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/src/config/course_config.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/store/extra_table_store.dart';
import 'package:flutter_app/src/util/course_table_control.dart';
import 'package:flutter_app/src/util/shared_table_builder.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:sprintf/sprintf.dart';

/// 掃進來的他人課表。唯讀。
///
/// 標題掛一個「他人」的記號：這張表跟自己的課表長得一樣，沒有記號會看錯成
/// 自己的。它也是掃描當下的快照，對方之後加退選不會同步。
class SharedTablePage extends StatefulWidget {
  const SharedTablePage({super.key, required this.shared, this.onRestore});

  final ExtraTable shared;

  /// 補課名。QR 只帶課號與時間，格子先畫出來，名字有網路再補——所以這是進頁
  /// 之後才跑的，不是進頁之前。回傳補完的課程清單。
  final Future<List<CourseMainInfoJson>> Function(
      void Function(int done, int total) onProgress)? onRestore;

  @override
  State<SharedTablePage> createState() => _SharedTablePageState();
}

class _SharedTablePageState extends State<SharedTablePage> {
  ExtraTable get shared => widget.shared;

  CourseTableJson get _table => shared.table;

  /// 還原進度。null 代表沒在跑。
  (int, int)? _progress;

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    final restore = widget.onRestore;
    if (restore == null) return;
    setState(() => _progress = (0, _table.getCourseIdList().length));
    final courses = await restore((done, total) {
      if (mounted) setState(() => _progress = (done, total));
    });
    if (!mounted) return;
    SharedTableBuilder.enrich(_table, courses);
    setState(() => _progress = null);
    unawaited(ExtraTableStore.instance.upsertShared(shared));
  }

  @override
  Widget build(BuildContext context) {
    final control = CourseTableControl()..set(_table);
    return Scaffold(
      appBar: mainAppbar(
        title: shared.label,
        subtitle: _summary(),
        isShowBack: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
        child: Column(
          children: [
            _badge(context),
            if (_progress != null) _restoring(context),
            const SizedBox(height: 8),
            _grid(context, control),
          ],
        ),
      ),
    );
  }

  String _summary() =>
      '${_table.courseSemester.year}-${_table.courseSemester.semester}'
      ' · ${sprintf(R.current.courseCount, [_table.getCourseIdList().length])}';

  Widget _badge(BuildContext context) {
    final scheme = context.scheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(TatTokens.radiusButton),
          ),
          child: Text(
            R.current.sharedTableBadge,
            style: context.text.labelMedium
                ?.copyWith(color: scheme.onSecondaryContainer),
          ),
        ),
      ),
    );
  }

  /// 補課名的進度。格子已經在了，所以這只是一行字，不是擋住畫面的轉圈。
  Widget _restoring(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            sprintf(R.current.importRestoring, [_progress!.$1, _progress!.$2]),
            style: AppTypography.tabular(context.text.bodySmall!)
                .copyWith(color: context.scheme.onSurfaceVariant),
          ),
        ),
      );

  Widget _grid(BuildContext context, CourseTableControl control) {
    final sections = control.getSectionIntList;
    return Column(
      children: [
        _header(context, control),
        for (var i = 0; i < sections.length; i++)
          _row(context, control, sections[i], i),
      ],
    );
  }

  Widget _header(BuildContext context, CourseTableControl control) => SizedBox(
        height: CourseConfig.dayHeight,
        child: Row(
          children: [
            const SizedBox(width: CourseConfig.sectionWidth),
            for (final day in control.getDayIntList)
              Expanded(
                child: Text(
                  control.getDayString(day),
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall
                      ?.copyWith(color: context.scheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      );

  Widget _row(BuildContext context, CourseTableControl control, int section,
          int index) =>
      Container(
        color: UIUtils.getListColor(index),
        height: 56,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: CourseConfig.sectionWidth,
              child: Center(
                child: Text(
                  control.getSectionString(section),
                  style: AppTypography.tabular(context.text.bodySmall!)
                      .copyWith(color: context.scheme.onSurfaceVariant),
                ),
              ),
            ),
            for (final day in control.getDayIntList)
              Expanded(child: _cell(context, control, day, section)),
          ],
        ),
      );

  Widget _cell(
      BuildContext context, CourseTableControl control, int day, int section) {
    final course = control.getCourseInfo(day, section);
    if (course == null) return const SizedBox();
    final color = control.getCourseInfoColor(day, section);
    return Padding(
      padding: const EdgeInsets.all(1),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(TatTokens.radiusButton),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: AutoSizeText(
              course.main.course.name,
              style: TextStyle(
                  color: UIUtils.getOnColor(color), fontSize: 12, height: 1.2),
              minFontSize: 8,
              maxLines: 3,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
