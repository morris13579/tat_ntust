import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 狀態籤的語意。呼叫端只說「這是什麼狀態」，配色由主題 token 決定。
enum StatusPillTone {
  /// 還沒開始動的中性狀態（未繳交、未作答、不需繳交）。
  pending,

  /// 已經送出去，等對方處理。
  submitted,

  /// 動了但還沒送出去（草稿、作答中、重新開放）。
  draft,

  /// 球還在使用者手上、而且時間在走（未繳交、已延長、還沒送出的草稿）。
  /// 跟 [pending] 分開是因為 pending 是「沒有事情要做」，這一組是「有」。
  attention,

  /// 有結果了。
  graded,

  /// 逾期或次數用完，需要注意。
  overdue,
}

/// 段標題右邊那顆狀態籤的外觀。作業與測驗共用同一份，兩邊才不會各自漂走。
/// 刻意不 import 任何頁面。
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.tone,
    required this.label,
    this.stale = false,
  });

  final StatusPillTone tone;
  final String label;

  /// 資料來自快取（`Stale`）。
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final tokens = context.tokens;
    // 快取的籤整顆換成 stale 配色，不只是多一個時鐘：底色照舊的話，
    // 「已評分」看起來仍像剛從伺服器拿到的那一份。
    final (:bg, :fg) = stale
        ? tokens.statusStale
        : switch (tone) {
            StatusPillTone.pending => tokens.statusPending,
            StatusPillTone.graded => tokens.statusGraded,
            StatusPillTone.overdue => tokens.statusLate,
            // 跟 statusStale 同一組顏色是刻意的：兩者都是「要留意」。
            // 分得開，因為快取的籤前面還多一個時鐘。
            StatusPillTone.attention => (
                bg: tokens.warningContainer,
                fg: tokens.warning
              ),
            // 這兩個沒有語意色可對：它們是流程位置，不是好壞，所以直接借
            // scheme 的容器色，token 裡刻意沒有它們。
            StatusPillTone.draft => (
                bg: scheme.tertiaryContainer,
                fg: scheme.onTertiaryContainer
              ),
            StatusPillTone.submitted => (
                bg: scheme.primaryContainer,
                fg: scheme.onPrimaryContainer
              ),
          };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        // 設計稿的籤是圓角方塊（8），不是藥丸：它和右邊那一欄的分數輪流
        // 出現，兩者的視覺重量要接近。
        borderRadius: BorderRadius.circular(TatTokens.radiusButton),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (stale) ...[
            Icon(LucideIcons.history, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label,
              style:
                  context.text.labelMedium?.copyWith(color: fg, height: 1.35)),
        ],
      ),
    );
  }
}
