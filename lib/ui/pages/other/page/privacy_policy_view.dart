import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_link.dart';
import 'package:flutter_app/src/util/open_utils.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/components/card/section_card.dart';
import 'package:flutter_app/ui/components/page/note_icon.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:sprintf/sprintf.dart';

/// 條款本文切成一節一節。標題是 markdown 的 `### `，其餘都是內文。
///
/// 開頭沒有標題的那一段是引言，`title` 為 null。
class PolicySection {
  const PolicySection({required this.title, required this.body});

  final String? title;
  final String body;

  static List<PolicySection> parse(String markdown) {
    final sections = <PolicySection>[];
    final buffer = StringBuffer();
    String? title;
    void flush() {
      final body = buffer.toString().trim();
      if (title != null || body.isNotEmpty) {
        sections.add(PolicySection(title: title, body: body));
      }
      buffer.clear();
    }

    for (final line in markdown.split('\n')) {
      final trimmed = line.trimRight();
      // 只有 `### ` 是一節。`## ` 是整份文件的大標——舊版本文第一行的
      // 「## 隱私權條款」跟 AppBar 重複，收成一節只會多一列點不出東西的標題，
      // 所以把它丟掉、底下的引言接著往下寫。
      if (RegExp(r'^##\s+').hasMatch(trimmed) &&
          !RegExp(r'^###\s+').hasMatch(trimmed)) {
        flush();
        title = null;
        continue;
      }
      final heading = RegExp(r'^###\s+(.*)$').firstMatch(trimmed);
      if (heading != null) {
        flush();
        title = heading.group(1)!.trim();
        continue;
      }
      buffer.writeln(line);
    }
    flush();
    return sections;
  }
}

/// 隱私權條款的內容。閱讀入口與首次同意閘門共用這一份。
///
/// 最上面是「摘要」：學生真正在問的是「帳號密碼存哪、成績會不會被看到」，
/// 而條款本文一千多字沒有人會從頭讀。摘要寫在 App 裡而不是 markdown 裡——
/// 它描述的是這一版 App 的行為，跟著程式走才不會過期。
class PrivacyPolicyView extends StatefulWidget {
  const PrivacyPolicyView({super.key, required this.policy});

  final String policy;

  @override
  State<PrivacyPolicyView> createState() => _PrivacyPolicyViewState();
}

class _PrivacyPolicyViewState extends State<PrivacyPolicyView> {
  final _expanded = <int>{};

  @override
  Widget build(BuildContext context) {
    final sections = PolicySection.parse(widget.policy);
    final intro = sections.where((s) => s.title == null).toList();
    final body = sections.where((s) => s.title != null).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        const SizedBox(height: 12),
        _summary(context),
        SectionHeader(
          icon: LucideIcons.fileText,
          title: R.current.privacyBodyTitle,
          trailing: Text(
            sprintf(R.current.privacySectionCount, [body.length]),
            style: context.text.bodySmall
                ?.copyWith(color: context.scheme.onSurfaceVariant),
          ),
        ),
        for (final section in intro)
          if (section.body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: _markdown(context, section.body),
            ),
        // 預設全部收起：七節收起來一屏看得完，要找「會不會給別人」才點開。
        for (var i = 0; i < body.length; i++) ...[
          if (i > 0) const SizedBox(height: 2),
          _sectionTile(context, i, body[i], body.length),
        ],
        const SizedBox(height: 20),
        _historyLink(context),
      ],
    );
  }

  Widget _summary(BuildContext context) {
    final items = <(IconData, String, String)>[
      (
        LucideIcons.shieldCheck,
        R.current.privacySummaryLocalTitle,
        R.current.privacySummaryLocalBody
      ),
      (
        LucideIcons.graduationCap,
        R.current.privacySummaryDataTitle,
        R.current.privacySummaryDataBody
      ),
      (
        LucideIcons.chartColumn,
        R.current.privacySummaryAnalyticsTitle,
        R.current.privacySummaryAnalyticsBody
      ),
      (
        LucideIcons.circleAlert,
        R.current.privacySummaryCrashTitle,
        R.current.privacySummaryCrashBody
      ),
    ];
    final scheme = context.scheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, item) in items.indexed) ...[
          if (i > 0) const SizedBox(height: 2),
          Material(
            color: context.tokens.card,
            borderRadius: UIUtils.getBorderRadius(i, items.length),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NoteIcon(item.$1,
                      style: context.text.titleSmall,
                      size: 18,
                      color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.$2, style: context.text.titleSmall),
                        const SizedBox(height: 4),
                        Text(
                          item.$3,
                          style: context.text.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionTile(
      BuildContext context, int index, PolicySection section, int length) {
    final open = _expanded.contains(index);
    final scheme = context.scheme;
    return Material(
      color: context.tokens.card,
      borderRadius: UIUtils.getBorderRadius(index, length),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(
                () => open ? _expanded.remove(index) : _expanded.add(index)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
              child: Row(
                children: [
                  Expanded(
                    child: Text(section.title!, style: context.text.bodyLarge),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                      open ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                      size: 18,
                      color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              child: _markdown(context, section.body),
            ),
        ],
      ),
    );
  }

  Widget _markdown(BuildContext context, String data) => MarkdownBody(
        data: data,
        selectable: true,
        onTapLink: (text, href, title) =>
            href == null ? null : OpenUtils.launchURL(href),
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          p: context.text.bodyMedium
              ?.copyWith(color: context.scheme.onSurfaceVariant),
          listBullet: context.text.bodyMedium
              ?.copyWith(color: context.scheme.onSurfaceVariant),
        ),
      );

  Widget _historyLink(BuildContext context) => Material(
        color: context.tokens.card,
        borderRadius: UIUtils.getBorderRadius(0, 1),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => OpenUtils.launchURL(AppLink.privacyPolicyHistory),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: [
                Icon(LucideIcons.history,
                    size: 18, color: context.scheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(R.current.privacyHistoryLink,
                      style: context.text.bodyMedium),
                ),
                Icon(LucideIcons.externalLink,
                    size: 16, color: context.scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      );
}
