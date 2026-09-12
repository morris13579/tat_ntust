import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/src/model/mail/mail_message_json.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:flutter_app/ui/pages/mail/components/mail_groups.dart';

/// 信件清單的一列：第一行「寄件者 · 時間」，第二行主旨。
///
/// 版面與「公告與通知」的 `NotificationTile` 同一套：每一列自己一塊卡片、彼此
/// 差 2px、四個角由 [UIUtils.getBorderRadius] 依位置決定。
///
/// **寄件者在上、主旨在下**，與通知頁相反。掃這一頁時真正在找的是「體育室」
/// 「就輔組」「Ellen Tsai」——校內公告的主旨前八個字幾乎都長一樣。
///
/// **未讀只畫一次**。先前同時畫了信封開／闔、一顆圓點與字重三個訊號，三者
/// 永遠一致，等於同一件事講三遍。現在收斂成一組：字重、色階、圓點——這三個
/// 是同一個強弱的三個面，不是三種標示。信封圖示整欄拿掉：每一封都是信，那
/// 個圖示不帶資訊卻吃掉一整欄。
class MailTile extends StatelessWidget {
  const MailTile({
    super.key,
    required this.message,
    required this.now,
    required this.onTap,
    this.onLongPress,
    required this.index,
    required this.length,
    this.highlight = '',
    this.borderRadius,
  });

  final MailMessageJson message;

  /// 「現在」，由呼叫端一次算好，整份清單的時間欄才是同一個時間點。
  final DateTime now;

  final VoidCallback onTap;

  /// 長按跳動作選單（標記未讀、移到資料夾、封存、刪除）。
  final VoidCallback? onLongPress;

  /// 這一列在所屬分組裡的位置，決定四個角的圓角。
  final int index;
  final int length;

  /// 蓋掉由 [index]/[length] 算出來的圓角。
  ///
  /// 滑動選單拉開時要用：那一排按鈕自己是 12 的圓角，這一列如果停在清單節奏
  /// 的 4，接縫看起來像兩個不同系統的東西拼在一起。
  final BorderRadius? borderRadius;

  /// 搜尋關鍵字。非空時主旨裡命中的那一段會標底色——主旨長的時候才看得出
  /// 為什麼這一封被列出來。
  final String highlight;

  /// 未讀圓點。7px：8px 在兩行主旨旁邊會顯得像個項目符號。
  static const double _dotSize = 7;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final unread = !message.seen;
    final subject = message.subject.trim();

    final subjectStyle = context.text.bodyLarge?.copyWith(
      height: 1.4,
      color: unread ? scheme.onSurface : scheme.onSurfaceVariant,
      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
    );

    return Material(
      color: context.tokens.card,
      borderRadius: borderRadius ?? UIUtils.getBorderRadius(index, length),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MetaLine(
                sender: message.displayFrom,
                time: MailGroups.formatDate(message.date, now),
              ),
              const SizedBox(height: 3),
              Semantics(
                label: unread ? '${R.current.mailUnread}：$subject' : null,
                child: Text.rich(
                  TextSpan(children: [
                    // 圓點用 WidgetSpan 而不是另外一欄：它要黏在主旨的第一行，
                    // 而主旨可能一行也可能兩行。交給文字排版對齊，行高與系統
                    // 字級縮放都不必自己算。
                    if (unread)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Container(
                            key: ValueKey('mail-unread-${message.uid}'),
                            width: _dotSize,
                            height: _dotSize,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ..._subjectSpans(
                      subject.isEmpty ? R.current.mailNoSubject : subject,
                      subjectStyle,
                      scheme.secondaryContainer,
                    ),
                  ]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: subjectStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 主旨切成「命中／沒命中」的片段。沒有關鍵字時就是一整段。
  List<InlineSpan> _subjectSpans(
      String subject, TextStyle? style, Color highlightColor) {
    final needle = highlight.trim().toLowerCase();
    if (needle.isEmpty) return [TextSpan(text: subject)];

    final spans = <InlineSpan>[];
    final haystack = subject.toLowerCase();
    var start = 0;
    while (true) {
      final hit = haystack.indexOf(needle, start);
      if (hit < 0) break;
      if (hit > start) spans.add(TextSpan(text: subject.substring(start, hit)));
      spans.add(TextSpan(
        text: subject.substring(hit, hit + needle.length),
        style: style?.copyWith(backgroundColor: highlightColor),
      ));
      start = hit + needle.length;
    }
    if (spans.isEmpty) return [TextSpan(text: subject)];
    if (start < subject.length) {
      spans.add(TextSpan(text: subject.substring(start)));
    }
    return spans;
  }
}

/// 「寄件者」靠左、「時間」靠右。
///
/// 兩段分開排版而不是一個 `Text`：寄件者是別人打的、長度沒有上限，包在同一串
/// 裡被 ellipsis 吃掉的一定是後面的時間——而時間是這一列唯一的新舊訊號。
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.sender, required this.time});

  final String sender;
  final String time;

  @override
  Widget build(BuildContext context) {
    final style = (context.text.bodySmall ?? const TextStyle())
        .copyWith(color: context.scheme.onSurfaceVariant, height: 1.45);
    return Semantics(
      label: '$sender · $time',
      child: Row(
        children: [
          Expanded(
            child: Text(
              sender,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          if (time.isNotEmpty) ...[
            const SizedBox(width: 10),
            // 等寬數字：時間欄靠右對齊，位數不一樣時右緣才不會抖。
            Text(time, maxLines: 1, style: AppTypography.tabular(style)),
          ],
        ],
      ),
    );
  }
}

/// 滑動選單拉開到 [ratio] 時，信件卡該有的圓角。
///
/// 清單靜止時每一列照 [UIUtils.getBorderRadius] 的節奏（頭尾 14、中間 4），
/// 那是「這幾列是同一群」的訊號。但拉開之後旁邊站的是自己有
/// [TatTokens.radiusCard] 圓角的按鈕，信件卡若還停在 4，接縫看起來像兩個不同
/// 系統的東西拼在一起。所以**朝著按鈕那一側**的兩個角跟著手指補到一樣圓。
///
/// [ratio] 帶正負號，就是 `SlidableController.ratio`：正的是右滑（露出左側的
/// 那一排），負的是左滑。另一側維持節奏值——兩側一起變圓會讓整群散掉。
///
/// **一定要除以 [extentRatio]。** `SlidableController.ratio` 是「拉開的距離佔
/// 整列寬度的比例」，被 `ActionPane.normalizeRatio` 夾在 `extentRatio` 以內，
/// 完全拉開時只有 0.3 或 0.56，不是 1。直接拿它當進度的話，整段拖曳圓角只從
/// 4 走到 6.4／8.5——兩三個像素，看起來就像「完全沒跟著手指動，放開才跳一下」。
BorderRadius mailSwipeCardRadius(
  BorderRadius resting,
  double ratio,
  double extentRatio,
) {
  if (ratio == 0 || extentRatio <= 0) return resting;
  final t = (ratio.abs() / extentRatio).clamp(0.0, 1.0);
  Radius grown(Radius from) => Radius.circular(
        from.x + (TatTokens.radiusCard - from.x) * t,
      );
  // **四個角要各自算。** `BorderRadius.horizontal(left:, right:)` 會把同一個
  // 值套到上下兩個角：清單第一列靜止時是「上 14、下 4」，用它就會在手指一碰
  // 的瞬間把下面那兩個角也跳成 14，連沒在動的那一側都跟著變。
  return ratio > 0
      ? BorderRadius.only(
          topLeft: grown(resting.topLeft),
          bottomLeft: grown(resting.bottomLeft),
          topRight: resting.topRight,
          bottomRight: resting.bottomRight,
        )
      : BorderRadius.only(
          topLeft: resting.topLeft,
          bottomLeft: resting.bottomLeft,
          topRight: grown(resting.topRight),
          bottomRight: grown(resting.bottomRight),
        );
}
