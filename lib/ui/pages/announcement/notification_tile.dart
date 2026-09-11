import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_message_popup_notifications.dart';
import 'package:flutter_app/src/util/moodle_notification_utils.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/components/html/moodle_html_view.dart';
import 'package:flutter_app/ui/components/page/web_view_opener.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:flutter_app/ui/pages/announcement/components/notification_groups.dart';

/// 站內通知的一列：類型圖示、標題、「來源 · 時間」，右側一個 chevron。
///
/// 一組列不是一張帶分隔線的卡片，而是每一列自己一塊、彼此差 2px
/// （[UIUtils.getBorderRadius]），與 App 其他清單同一套。
///
/// 有 contexturl 的點了會開網頁（chevron_right），沒有的就地展開內文
/// （chevron_down / up）——兩種行為在點下去之前就分得出來。
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.now,
    required this.openable,
    required this.expanded,
    required this.onTap,
    required this.openWebView,
    required this.index,
    required this.length,
  });

  final MoodleNotification notification;

  /// 「現在」，由呼叫端一次算好，整份清單的時間欄才是同一個時間點。
  final DateTime now;

  /// 有可以開啟的自家網址（`MoodleNotificationUtils.openUrlOf`）。
  final bool openable;

  final bool expanded;
  final VoidCallback onTap;
  final WebViewOpener openWebView;

  /// 這一列在所屬分組裡的位置，決定四個角的圓角。
  final int index;
  final int length;

  /// 伺服器的 `iconurl` 刻意不用：那是站台主題圖，每一列要多一次網路請求，
  /// 深色模式也不會反相。
  static IconData iconFor(String? component, {String? eventtype}) {
    // 成績通知在 Moodle 是 core 的 `moodle` 元件加上 grade 開頭的 eventtype，
    // 光看 component 會落到大聲公。設計稿把成績另外畫成學士帽。
    if (_isGrade(component, eventtype)) return LucideIcons.graduationCap;
    final name = component ?? '';
    return switch (name) {
      'mod_assign' => LucideIcons.clipboardList,
      'mod_forum' => LucideIcons.messagesSquare,
      'mod_quiz' => LucideIcons.fileQuestion,
      'mod_feedback' || 'mod_choice' || 'mod_survey' => LucideIcons.vote,
      'mod_lesson' || 'mod_scorm' => LucideIcons.bookOpen,
      _ => name.startsWith('mod_') ? LucideIcons.puzzle : LucideIcons.bell,
    };
  }

  static bool _isGrade(String? component, String? eventtype) =>
      (eventtype ?? '').toLowerCase().contains('grade') ||
      (component ?? '').startsWith('gradereport_');

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final text = context.text;
    final unread = !notification.read;
    final body =
        expanded ? MoodleNotificationUtils.bodyHtmlOf(notification) : '';
    final borderRadius = UIUtils.getBorderRadius(index, length);

    return Material(
      color: context.tokens.card,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    iconFor(notification.component,
                        eventtype: notification.eventtype),
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.subject,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyLarge?.copyWith(
                            color: scheme.onSurface,
                            height: 1.5,
                            // 未讀只差一個字重，是設計稿自己的訊號；圓點是
                            // 第二個，因為單靠字重在小字上幾乎看不出來。
                            fontWeight:
                                unread ? FontWeight.w500 : FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _MetaLine(
                          source: _sourceLabel(),
                          time: NotificationGroups.formatCreatedTime(
                              notification.createdTime, now),
                        ),
                      ],
                    ),
                  ),
                  if (unread) ...[
                    const SizedBox(width: 10),
                    Semantics(
                      label: R.current.notificationUnread,
                      child: Container(
                        key: ValueKey('unread-${notification.id}'),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 10),
                  Icon(
                    openable
                        ? LucideIcons.chevronRight
                        : (expanded
                            ? LucideIcons.chevronUp
                            : LucideIcons.chevronDown),
                    size: 17,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 12),
                MoodleHtmlView(
                  html: body,
                  title: notification.subject,
                  dirName: 'notification',
                  openWebView: openWebView,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 來源，也就是 Moodle 的活動名稱。core 的系統通知沒有 contexturlname。
  String _sourceLabel() {
    final source = notification.contexturlname?.trim();
    return (source == null || source.isEmpty)
        ? R.current.notificationUnknownSource
        : source;
  }
}

/// 「來源 · 時間」。兩段分開排版而不是一個 `Text`：活動名稱是老師打的、
/// 長度沒有上限，包在同一串裡被 ellipsis 吃掉的一定是後面的時間——而時間是
/// 這一列唯一的新舊訊號。
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.source, required this.time});

  final String source;
  final String time;

  @override
  Widget build(BuildContext context) {
    final style = (context.text.bodySmall ?? const TextStyle())
        .copyWith(color: context.scheme.onSurfaceVariant, height: 1.45);
    return Semantics(
      label: '$source · $time',
      child: Row(
        children: [
          Flexible(
            child: Text(
              source,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          Text(' · $time', maxLines: 1, style: AppTypography.tabular(style)),
        ],
      ),
    );
  }
}
