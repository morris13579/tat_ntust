import 'package:flutter/material.dart';

/// 整頁的空狀態：一個大圖示加一行說明。嵌在頁面中段、周圍畫面還在的區塊
/// 有自己更小的一份（`SectionEmptyState`），不要共用這個。
///
/// [icon] 請傳 `LucideIconsThin` 的那一份：72 級的圖示用內文粗細畫出來會變成
/// 一團黑，比它底下那句真正在說明狀況的字還搶眼。
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});

  final IconData icon;

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 72,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 24),
          Text(message),
        ],
      ),
    );
  }
}
