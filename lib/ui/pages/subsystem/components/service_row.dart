import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 資訊系統的一列服務。
///
/// 原本是 120px 高的兩欄方塊，一個畫面只放得下六項，長一點的服務名稱還會被
/// 壓成兩行。清單列一個畫面放得下十幾項，名稱也只需要一行。
///
/// [description] 目前一律是 null：逐服務的用途說明還沒有翻譯鍵可用。**沒有
/// 說明時不能留空位**，否則整份清單會多出一段永遠空著的高度。
class ServiceRow extends StatelessWidget {
  const ServiceRow({
    super.key,
    required this.name,
    required this.onTap,
    this.description,
    this.badge,
  });

  final String name;
  final VoidCallback onTap;
  final String? description;

  /// 名稱右邊的小籤。目前只有空教室在用：它是 App 內的頁面，混在一串會開
  /// 瀏覽器的服務裡需要講清楚。
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: TatTokens.heightRow),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                          child: Text(name, style: context.text.bodyLarge)),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(
                                TatTokens.radiusButton),
                          ),
                          child: Text(badge!,
                              style: context.text.labelSmall?.copyWith(
                                  height: 1.3,
                                  color: scheme.onPrimaryContainer)),
                        ),
                      ],
                    ],
                  ),
                  if (description != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        description!,
                        style: context.text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
