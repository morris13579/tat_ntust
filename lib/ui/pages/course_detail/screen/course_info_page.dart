import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/src/controller/course_detail/course_detail_controller.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/util/course_grading_utils.dart';
import 'package:flutter_app/ui/components/page/result_view.dart';
import 'package:flutter_app/ui/components/toast/tat_toast.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:sprintf/sprintf.dart';

/// 課程詳細資訊。
///
/// 原本是 18 張長得一樣的卡片，短欄位（課號、學年期）與長段落（課程大綱）
/// 視覺權重相同。現在拆成三段：標題、短欄位表格、長段落各自成段。
class CourseInfoPage extends StatelessWidget {
  const CourseInfoPage({
    required this.controller,
    required this.errorBuilder,
    this.onOpenMembers,
    this.onOpenUrl,
    super.key,
  });

  /// 課號與學年期都在 controller 上，這一頁只負責畫它抓回來的東西。
  final CourseDetailController controller;

  /// 失敗時要畫什麼。由呼叫端注入而不是直接用 `ErrorPage`，
  /// 見 docs/ARCHITECTURE.md「UI 慣例」。
  final Widget Function(String message) errorBuilder;

  /// 帶著已知人數進修課學生那一頁。名單那支 API 慢，所以只有真的想看的人才付。
  final void Function(int knownMemberCount)? onOpenMembers;

  /// 用瀏覽器開課程網址。
  final void Function(String url)? onOpenUrl;

  @override
  Widget build(BuildContext context) {
    return ResultView<CourseExtraInfoJson>(
      state: controller.info,
      onRetry: controller.loadInfo,
      errorBuilder: errorBuilder,
      builder: (info) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: _buildContent(context, info),
      ),
    );
  }

  List<Widget> _buildContent(BuildContext context, CourseExtraInfoJson info) {
    final rows = _buildFactRows(context, info);
    return [
      _Header(info: info),
      if (rows.isNotEmpty) ...[
        const SizedBox(height: 20),
        _FactTable(rows: rows),
      ],
      // 人數是主要 API 就給的，所以這一列立刻畫得出來、也不會失敗；名單本身
      // 那支慢的查詢搬到下一頁去。
      if (onOpenMembers != null && info.allStudent.trim().isNotEmpty) ...[
        const SizedBox(height: 20),
        _MemberCard(
          count: info.allStudent.trim(),
          onTap: () =>
              onOpenMembers!(int.tryParse(info.allStudent.trim()) ?? 0),
        ),
      ],
      ..._buildSections(context, info),
    ];
  }

  List<Widget> _buildFactRows(BuildContext context, CourseExtraInfoJson info) {
    final rows = <Widget>[];

    void add(String label, String value, {String? footnote}) {
      if (value.trim().isEmpty) return;
      rows.add(_FactRow(label: label, value: value, footnote: footnote));
    }

    add(R.current.instructor, info.courseTeacher);
    add(R.current.classRoomNo, info.classRoomNo);
    if (info.courseTimes.isNotEmpty || info.practicalTimes.isNotEmpty) {
      add(
        R.current.courseAndPracticalTimes,
        sprintf(R.current.hoursValue, [info.courseTimes, info.practicalTimes]),
      );
    }
    add(
      R.current.enrolledCount,
      info.allStudent.isEmpty
          ? ''
          : sprintf(R.current.enrolledCountValue,
              [info.allStudent, info.chooseStudent, info.threeStudent]),
      footnote: _limitSummary(info),
    );

    return rows;
  }

  /// 三個上限任何一個缺就整條不顯示——半條數字比沒有還難懂。
  String? _limitSummary(CourseExtraInfoJson info) {
    final ntu = int.tryParse(info.nTURestrict.trim());
    final ntnu = int.tryParse(info.nTNURestrict.trim());
    if (info.restrict1.isEmpty || info.restrict2.isEmpty) return null;
    if (ntu == null || ntnu == null) return null;
    return sprintf(R.current.enrollmentLimitSummary,
        [info.restrict1, info.restrict2, ntu + ntnu]);
  }

  List<Widget> _buildSections(BuildContext context, CourseExtraInfoJson info) {
    final sections = <Widget>[];

    void addProse(String title, String body) {
      if (body.trim().isEmpty) return;
      sections.add(_ProseSection(title: title, body: body.trim()));
    }

    // 課程宗旨是唯一攤開的長文：它是「這門課在幹嘛」，值得一進來就看到。
    addProse(R.current.courseObject, info.courseObject);

    if (info.courseGrading.trim().isNotEmpty) {
      final items = CourseGradingUtils.parse(info.courseGrading);
      sections.add(items == null
          ? _ProseSection(
              title: R.current.courseGrading,
              body: info.courseGrading.trim(),
            )
          : _GradingSection(items: items));
    }

    // 其餘長欄位收進折疊列。攤開來排是 18 張一樣大的卡片，正是這次要改掉的
    // 東西；真的要看的人點一下就好。
    final more = <_CollapsibleItem>[
      (title: R.current.courseContent, body: info.courseContent.trim()),
      (title: _booksTitle(info), body: _books(info)),
      (title: R.current.courseNote, body: info.courseNote.trim()),
      (title: R.current.coreAbility, body: info.coreAbility.trim()),
      (title: R.current.courseRemark, body: info.courseRemark.trim()),
    ].where((item) => item.body.isNotEmpty).toList();

    final url = info.courseURL.trim();
    final hasUrl = url.isNotEmpty && onOpenUrl != null;

    if (more.isNotEmpty || hasUrl) {
      sections.add(_MoreFieldsSection(
        items: more,
        url: hasUrl ? url : null,
        onOpenUrl: hasUrl ? () => onOpenUrl!(url) : null,
      ));
    }

    return sections;
  }

  String _booksTitle(CourseExtraInfoJson info) {
    if (info.courseTextbook.trim().isEmpty) return R.current.courseRefbook;
    if (info.courseRefbook.trim().isEmpty) return R.current.courseTextbook;
    return R.current.courseTextbookAndRefbook;
  }

  String _books(CourseExtraInfoJson info) {
    return [info.courseTextbook.trim(), info.courseRefbook.trim()]
        .where((text) => text.isNotEmpty)
        .join('\n');
  }
}

/// 課名、課號與學年期，以及必修／學分／全年這三個標籤。
class _Header extends StatelessWidget {
  const _Header({required this.info});

  final CourseExtraInfoJson info;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final subtitle = [info.courseNo, info.semester]
        .where((text) => text.trim().isNotEmpty)
        .join(' · ');
    final chips = [
      info.requireOption.trim(),
      if (info.creditPoint.trim().isNotEmpty)
        sprintf(R.current.creditCount, [info.creditPoint.trim()]),
      info.allYear.trim(),
    ].where((text) => text.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (info.courseName.trim().isNotEmpty)
          Text(info.courseName.trim(), style: context.text.titleLarge),
        if (subtitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              style: context.text.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        if (chips.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final chip in chips) _Chip(label: chip)],
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style:
            context.text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

/// 短欄位的 label / value 表格。列與列之間只有一條細線，沒有卡片。
class _FactTable extends StatelessWidget {
  const _FactTable({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 2),
          Material(
            color: context.tokens.card,
            borderRadius: UIUtils.getBorderRadius(i, rows.length),
            clipBehavior: Clip.antiAlias,
            child: rows[i],
          ),
        ],
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.label,
    required this.value,
    this.footnote,
  });

  final String label;
  final String value;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final text = context.text;
    // 高度由 padding 決定，不要再壓一個 minHeight：單行的列（授課老師）內容
    // 只有一行高，卻被撐到 52 再靠上對齊，字就浮在上緣。
    // 標籤與值的行高都設成 1.5，兩欄的第一條基線才會對齊。
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 標籤欄固定寬、值靠左接著排（設計稿是 80px + 1fr 的兩欄）。值靠右
          // 的話，短的值會被推到畫面另一端，眼睛要在兩欄之間來回跳。
          SizedBox(
            // 「上課時間教室」是最長的標籤，寬度就是照它抓的。
            width: 96,
            child: Text(
              label,
              style: text.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: text.bodyLarge
                        ?.copyWith(height: 1.5, fontWeight: FontWeight.w500)),
                if (footnote != null)
                  Text(
                    footnote!,
                    style: text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 長段落。標題、內文，以及一顆明確的複製鈕——原本是整張卡點一下就複製，
/// 沒有人看得出來那件事會發生。
class _ProseSection extends StatelessWidget {
  const _ProseSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return _Section(
      title: title,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body, style: context.text.bodyLarge),
            const SizedBox(height: 11),
            Divider(height: 1, color: scheme.outlineVariant),
            _CopyButton(text: body),
          ],
        ),
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    // 不要用 TextButton：主題給每顆按鈕 44 的最小高度與 16 的左右內距，
    // 塞在已經有 14 內距的卡片底部就變成一大塊空白。設計稿這裡只是一行
    // 圖示加文字。
    final scheme = context.scheme;
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: text));
        TatToast.show(R.current.copy);
      },
      borderRadius: BorderRadius.circular(TatTokens.radiusButton),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.copy, size: 16, color: scheme.primary),
            const SizedBox(width: 8),
            Text(
              R.current.copyAction,
              style: context.text.bodySmall?.copyWith(
                  color: scheme.primary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

/// 評量方式解析得出百分比時的樣子：名目一欄、百分比靠右一欄。
class _GradingSection extends StatelessWidget {
  const _GradingSection({required this.items});

  final List<GradingItem> items;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return _Section(
      title: R.current.courseGrading,
      boxed: false,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 2),
            Material(
              color: context.tokens.card,
              borderRadius: UIUtils.getBorderRadius(i, items.length),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(items[i].label, style: text.bodyLarge)),
                    const SizedBox(width: 12),
                    Text(
                      items[i].percentText,
                      style: AppTypography.tabular(text.bodyLarge!)
                          .copyWith(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 標題在卡片外、內容裝在一塊 surface 裡（設計稿 3e 的每一段都是這個形狀）。
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.boxed = true,
  });

  final String title;
  final Widget child;

  /// false 代表內容自己畫底板（清單型每一列各自是一塊）。
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 11),
            child: Text(
              title,
              style: context.text.titleSmall
                  ?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
          ),
          if (boxed)
            Material(
              color: context.tokens.card,
              borderRadius: BorderRadius.circular(TatTokens.radiusCard),
              clipBehavior: Clip.antiAlias,
              child: child,
            )
          else
            child,
        ],
      ),
    );
  }
}

/// 修課學生：人數已經在主要 API 裡，所以這一列自己一張卡、立刻畫得出來。
class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.count, required this.onTap});

  final String count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Material(
      color: context.tokens.card,
      borderRadius: BorderRadius.circular(TatTokens.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          child: Row(
            children: [
              Expanded(
                child: Text(R.current.enrolledStudents,
                    style: context.text.bodyLarge),
              ),
              const SizedBox(width: 12),
              Text(
                sprintf(R.current.peopleCount, [count]),
                style: AppTypography.tabular(context.text.bodyMedium!)
                    .copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 12),
              Icon(LucideIcons.chevronRight,
                  size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// 折疊列的一項：標題與內文。
typedef _CollapsibleItem = ({String title, String body});

/// 「其餘欄位」。每一列點開才顯示內文，收合時只有一行標題。
class _MoreFieldsSection extends StatefulWidget {
  const _MoreFieldsSection({
    required this.items,
    required this.url,
    required this.onOpenUrl,
  });

  final List<_CollapsibleItem> items;
  final String? url;
  final VoidCallback? onOpenUrl;

  @override
  State<_MoreFieldsSection> createState() => _MoreFieldsSectionState();
}

class _MoreFieldsSectionState extends State<_MoreFieldsSection> {
  final _expanded = <int>{};

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      for (var i = 0; i < widget.items.length; i++)
        _CollapsibleRow(
          item: widget.items[i],
          isExpanded: _expanded.contains(i),
          onTap: () => setState(() {
            _expanded.contains(i) ? _expanded.remove(i) : _expanded.add(i);
          }),
        ),
      if (widget.url != null)
        _UrlRow(url: widget.url!, onOpen: widget.onOpenUrl!),
    ];

    return _Section(
      title: R.current.otherFields,
      boxed: false,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 2),
            Material(
              color: context.tokens.card,
              borderRadius: UIUtils.getBorderRadius(i, rows.length),
              clipBehavior: Clip.antiAlias,
              child: rows[i],
            ),
          ],
        ],
      ),
    );
  }
}

class _CollapsibleRow extends StatelessWidget {
  const _CollapsibleRow({
    required this.item,
    required this.isExpanded,
    required this.onTap,
  });

  final _CollapsibleItem item;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Expanded(
                    child: Text(item.title, style: context.text.bodyLarge)),
                const SizedBox(width: 12),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: Icon(LucideIcons.chevronDown,
                      size: 18, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.body, style: context.text.bodyLarge),
                const SizedBox(height: 11),
                Divider(height: 1, color: scheme.outlineVariant),
                _CopyButton(text: item.body),
              ],
            ),
          ),
      ],
    );
  }
}

/// 課程相關網址：沒有內文可以展開，右邊直接是「用瀏覽器開啟」。
class _UrlRow extends StatelessWidget {
  const _UrlRow({required this.url, required this.onOpen});

  final String url;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(R.current.courseURL, style: context.text.bodyLarge),
            ),
            const SizedBox(width: 12),
            Text(
              R.current.openInBrowser,
              style: context.text.bodySmall?.copyWith(
                  color: context.scheme.primary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
