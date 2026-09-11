import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/src/model/announcement/announcement_json.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:intl/intl.dart';

/// 通知頁最上面那張 TAT 公告卡。
///
/// 它是一整塊、不是清單的一列：底下 Moodle 通知是「別人送來的一長串」，
/// 這一則是「我們自己要說的一件事」，用 primaryContainer 的色塊分開兩者。
/// 只畫最新的一則，其餘留給 [onOpen] 開的公告頁翻頁。
class AnnouncementBanner extends StatelessWidget {
  const AnnouncementBanner({
    super.key,
    required this.info,
    required this.unread,
    required this.onOpen,
  });

  final AnnouncementInfoJson info;

  /// 進頁那一刻還沒讀過。設計稿沒有這個訊號，但少了它「有新公告」就只剩
  /// 「卡片還在」，讀過與沒讀過長得一模一樣。
  final bool unread;

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final text = context.text;
    // startTime 是 UTC 欄位裝著台北的牆上時間（見 RemoteConfigUtils），
    // toLocal() 會讓每一則公告的日期整整位移八小時。
    final date = DateFormat.MMMd().format(info.startTime);
    final excerpt = plainExcerpt(info.content);

    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(TatTokens.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.megaphone,
                      size: 18, color: scheme.onPrimaryContainer),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      R.current.appAnnouncement,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (unread) ...[
                    Semantics(
                      label: R.current.notificationUnread,
                      child: Container(
                        key: const ValueKey('notice-unread'),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Semantics(
                    label: '${R.current.announcementPublishedAt} $date',
                    child: Text(
                      date,
                      style: AppTypography.tabular(text.bodySmall!)
                          .copyWith(color: scheme.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                info.title,
                style: text.titleMedium?.copyWith(color: scheme.onSurface),
              ),
              if (excerpt.isNotEmpty) ...[
                const SizedBox(height: 9),
                Text(
                  excerpt,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium
                      ?.copyWith(color: scheme.onPrimaryContainer),
                ),
              ],
              const SizedBox(height: 9),
              // 不用 TextButton：主題給每顆按鈕 44 的最小高度與 16 的左右內距，
              // 塞在已經有 14 內距的卡片底部就變成一大塊空白。整張卡片都能點，
              // 這一行是看得出「還有下文」的那個記號。
              Text(
                R.current.announcementReadFull,
                style: text.labelLarge?.copyWith(
                  color: scheme.onPrimaryContainer,
                  decoration: TextDecoration.underline,
                  decorationColor: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 公告內文是 Markdown，摘要要的是純文字：卡片上只有三行，`**粗體**` 的
  /// 星號與整串網址佔掉的是那三行裡的字。
  static String plainExcerpt(String markdown) {
    var value = markdown
        .replaceAll(_codeFence, ' ')
        .replaceAll(_image, ' ')
        .replaceAllMapped(_link, (m) => m[1] ?? '')
        .replaceAll(_bullet, '')
        .replaceAll(_marks, '');
    value = value.replaceAll(_whitespace, ' ').trim();
    return value;
  }

  static final RegExp _codeFence = RegExp(r'```[\s\S]*?```');
  static final RegExp _image = RegExp(r'!\[[^\]]*\]\([^)]*\)');
  static final RegExp _link = RegExp(r'\[([^\]]*)\]\([^)]*\)');
  static final RegExp _bullet =
      RegExp(r'^[ \t]*(?:[-+*]|\d+\.)[ \t]+', multiLine: true);
  static final RegExp _marks = RegExp(r'[*_`>#~]');
  static final RegExp _whitespace = RegExp(r'\s+');
}
