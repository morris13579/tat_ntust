import 'package:flutter/material.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:flutter_app/src/R.dart';

/// 「這裡不能發文」的常駐底列：一句理由，加上還走得通的出口（如果真的有）。
///
/// 討論串頁的鎖定、清單頁的「不開放發文」與「無法確認能不能發文」共用這一個
/// 外殼。**只有網頁真的走得通時才給 [onOpenWeb]**：伺服器自己回「不行」時
/// 網頁版問的是同一個 capability，那顆鈕只會把人送去同樣被拒的一頁。
///
/// 放在 `bottomNavigationBar` 而不是清單的最後一項：五十則主題不必捲到底
/// 才知道自己不能發文。
///
/// **句子自己一行、動作在下面一行**：擠在同一條 Row 裡時兩顆按鈕在 360dp
/// 上就吃掉 270dp，`Expanded` 的句子被壓成一條窄柱，字級放大後整條列會長到
/// 佔掉三分之一個螢幕。
class ForumNoticeBar extends StatelessWidget {
  const ForumNoticeBar({
    super.key,
    required this.message,
    this.onOpenWeb,
    this.onRetry,
  });

  final String message;

  /// null ＝網頁也走不通，那就不要給一個假的出口。
  final VoidCallback? onOpenWeb;

  /// 只有「問不到」那一種狀態才給：問不到不等於不行。
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final hasActions = onOpenWeb != null || onRetry != null;
    return Material(
      // SafeArea 在 Material 裡面，底色才會一路鋪到螢幕最底（同
      // `ForumComposerBar`）：包在外面的話那段 inset 是透明的。
      color: context.tokens.card,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 1, color: scheme.outlineVariant),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, hasActions ? 4 : 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  // 放大字級時換行而不是互相擠壓。沒有 icon：句子已經把意思說
                  // 完了，兩顆帶圖的鈕只是把句子的位置搶走。
                  if (hasActions)
                    Wrap(
                      alignment: WrapAlignment.end,
                      children: [
                        if (onOpenWeb != null)
                          TextButton(
                            onPressed: onOpenWeb,
                            child: Text(R.current.forumOpenInWeb),
                          ),
                        if (onRetry != null)
                          TextButton(
                            onPressed: onRetry,
                            child: Text(R.current.refresh),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
