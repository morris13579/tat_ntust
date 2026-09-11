import 'package:flutter/material.dart';
import 'package:flutter_app/ui/components/page/note_icon.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';

/// 卡片或某一列底下的一句說明。
///
/// [blocking] 的那一種**同時換 icon 與顏色**：只換色的話，色覺差異的人看到的
/// 是兩句一模一樣的灰字，而其中一句的意思是「這樣按不下去」。
class InlineNote extends StatelessWidget {
  const InlineNote(this.message, {super.key, this.blocking = false});

  final String message;

  /// true = 這句話說的是一個真的擋住動作的理由。
  final bool blocking;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = blocking ? scheme.error : scheme.onSurfaceVariant;
    final style = text.bodySmall?.copyWith(color: color);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NoteIcon(blocking ? LucideIcons.circleAlert : LucideIcons.info,
              style: style, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: style)),
        ],
      ),
    );
  }
}
