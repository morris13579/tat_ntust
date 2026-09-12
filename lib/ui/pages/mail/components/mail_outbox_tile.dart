import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/mail/mail_outbox_item.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/components/tat_progress.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:sprintf/sprintf.dart';

/// 寄件匣的一列。版面與 [MailTile] 同一套卡片，右邊多一顆動作鈕。
///
/// 三種狀態各自只給**一個**動作：
/// - 還在等 → 收回。那是唯一收得回來的時候，所以倒數秒數要看得到。
/// - 寄送中 → 沒有動作。信可能已經在對方伺服器上了，給一顆按不到效果的
///   「收回」比不給更糟。
/// - 失敗 → 重試，長按才給刪除。誤按刪除等於把使用者寫好的信弄不見。
class MailOutboxTile extends StatelessWidget {
  const MailOutboxTile({
    super.key,
    required this.item,
    required this.remainingSeconds,
    required this.index,
    required this.length,
    this.onRecall,
    this.onRetry,
    this.onDiscard,
  });

  final MailOutboxItem item;

  /// 還要等幾秒。0 代表已經到期，下一跳就送出去。
  final int remainingSeconds;

  final int index;
  final int length;

  final VoidCallback? onRecall;
  final VoidCallback? onRetry;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final failed = item.state == MailOutboxState.failed;
    final subject = item.draft.subject.trim();

    return Material(
      color: context.tokens.card,
      borderRadius: UIUtils.getBorderRadius(index, length),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // 點整列沒有事情可做——動作都在右邊那一顆。長按給失敗的那些一個出口。
        onLongPress: failed ? onDiscard : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _stateIcon(context),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _stateText(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall?.copyWith(
                              color: failed ? scheme.error : scheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subject.isEmpty ? R.current.mailNoSubject : subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    if (item.recipientSummary.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.recipientSummary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _action(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stateIcon(BuildContext context) => switch (item.state) {
        MailOutboxState.waiting =>
          Icon(LucideIcons.clock, size: 14, color: context.scheme.primary),
        MailOutboxState.sending => const TatProgress(size: 12),
        MailOutboxState.failed => Icon(LucideIcons.triangleAlert,
            size: 14, color: context.scheme.error),
      };

  String _stateText() => switch (item.state) {
        // 到期了但還沒輪到，講「寄送中」比留在「0 秒後寄出」誠實。
        MailOutboxState.waiting => remainingSeconds <= 0
            ? R.current.mailOutboxSending
            : sprintf(R.current.mailOutboxWaiting, [remainingSeconds]),
        MailOutboxState.sending => R.current.mailOutboxSending,
        MailOutboxState.failed => R.current.mailOutboxFailed,
      };

  Widget _action() => switch (item.state) {
        MailOutboxState.waiting =>
          TextButton(onPressed: onRecall, child: Text(R.current.mailRecall)),
        MailOutboxState.sending => const SizedBox(width: 8),
        MailOutboxState.failed =>
          TextButton(onPressed: onRetry, child: Text(R.current.mailRetry)),
      };
}
