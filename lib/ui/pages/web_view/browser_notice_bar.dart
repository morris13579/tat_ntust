import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 內建瀏覽器的提示條。
///
/// 貼在進度線下方、不擋內容、也不會自己消失——這幾件事以前散在
/// `MyToast.show` 與 `Log.e`：toast 幾秒就沒了，而人還留在那一頁；寫進 log
/// 的那兩種使用者根本看不到。
enum BrowserNoticeKind { info, warning, success }

class BrowserNoticeBar extends StatelessWidget {
  const BrowserNoticeBar({
    super.key,
    required this.icon,
    required this.message,
    required this.kind,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final BrowserNoticeKind kind;

  /// 有動作時才給。「重新登入」「開啟」這種——只說發生了什麼、卻不給下一步，
  /// 使用者除了瞪著它沒有別的事可以做。
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    // 底色是 *Container、字就要用強色（跟 statusGraded / statusStale 同一套）。
    // `onWarning` 那一組是給實色底用的，配在淺底上會淺到看不見。
    final (background, foreground) = switch (kind) {
      BrowserNoticeKind.info => (tokens.infoContainer, tokens.info),
      BrowserNoticeKind.warning => (tokens.warningContainer, tokens.warning),
      BrowserNoticeKind.success => (tokens.successContainer, tokens.success),
    };
    return Material(
      color: background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 8, 11),
        child: Row(
          children: [
            Icon(icon, size: 17, color: foreground),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                message,
                style: context.text.bodySmall?.copyWith(color: foreground),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: foreground,
                  minimumSize: const Size(0, TatTokens.heightRow),
                ),
                child: Text(actionLabel!),
              ),
            ] else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// 網址列。主角是 host，呼叫端傳進來的標題降為第二行。
///
/// 只印主機名不印完整路徑：路徑幫不上「我在哪」的判斷，host 才是。前面那顆
/// 圖示是 https 與否——`WebViewUrlPolicy` 放行 http，所以那個狀態真的存在。
class BrowserAddressBar extends StatelessWidget {
  const BrowserAddressBar({super.key, required this.url, required this.title});

  final Uri url;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final tokens = context.tokens;
    final secure = url.scheme == 'https';
    final host = url.host.isEmpty ? url.toString() : url.host;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                secure ? LucideIcons.shieldCheck : LucideIcons.triangleAlert,
                size: 13,
                color: secure ? tokens.success : tokens.warning,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  host,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// 頂部列下緣那條 2px 進度線。載完就不畫，不是壓在整頁上的遮罩。
class BrowserProgressLine extends StatelessWidget
    implements PreferredSizeWidget {
  const BrowserProgressLine({super.key, required this.progress});

  final double progress;

  @override
  Size get preferredSize => const Size.fromHeight(2);

  @override
  Widget build(BuildContext context) {
    if (progress >= 1.0) return const SizedBox(height: 2);
    return LinearProgressIndicator(
      value: progress,
      minHeight: 2,
      backgroundColor: context.scheme.surfaceContainerHighest,
    );
  }
}
