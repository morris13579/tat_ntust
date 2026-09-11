import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_discussion_posts.dart';
import 'package:flutter_app/src/util/moodle_forum_utils.dart';
import 'package:flutter_app/ui/components/card/section_card.dart';
import 'package:flutter_app/ui/components/html/moodle_html_view.dart';
import 'package:flutter_app/ui/components/page/web_view_opener.dart';
import 'package:flutter_app/ui/components/tile/moodle_file_tile.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:intl/intl.dart';

/// 討論串裡的一則貼文。
///
/// 從討論串頁抽出來是為了 `ListView.builder`：底部那條回覆列每打一個字就
/// setState 一次，貼文如果還住在頁面的 method 裡就會整串跟著重建。
///
/// 主文（depth 0）用 primaryContainer 的底色，回覆用卡片底色：一眼看得出
/// 哪一則是被回覆的那一篇，而不必先找縮排。
class ForumPostBlock extends StatelessWidget {
  const ForumPostBlock({
    super.key,
    required this.item,
    required this.first,
    required this.aimed,
    required this.canReply,
    required this.hasOwnerActions,
    required this.onReply,
    required this.onActions,
    required this.onOpenFile,
    required this.openWebView,
    required this.dirName,
    required this.title,
  });

  final ThreadPost item;

  /// 整串的第一塊：上緣不留段距。
  final bool first;

  /// 使用者正在回覆這一篇：加一圈 1px 的 primary 外框當定位。
  final bool aimed;

  final bool canReply;

  /// 編輯或刪除至少有一個可用時才畫 `⋯`。
  final bool hasOwnerActions;

  final VoidCallback onReply;
  final VoidCallback onActions;
  final void Function(MoodleForumFile file) onOpenFile;

  final WebViewOpener openWebView;
  final String dirName;
  final String title;

  bool get _isRoot => item.depth == 0;

  @override
  Widget build(BuildContext context) {
    final p = item.post;
    final scheme = context.scheme;
    final author = p.author?.fullname ?? "";
    final name = author.isNotEmpty ? author : R.current.forumUnknownAuthor;
    final fill = _isRoot ? scheme.primaryContainer : context.tokens.card;
    return Padding(
      // 段距與縮排分成兩層：外層是與上一則的距離，內層才是這一則的深度。
      padding: EdgeInsets.only(top: first ? 0 : 10),
      child: Padding(
        padding: EdgeInsets.only(left: item.depth.clamp(0, 3) * 12.0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(TatTokens.radiusCard),
            border: aimed
                ? Border.all(color: scheme.primary, width: 1)
                : Border.all(color: Colors.transparent, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context, p, name),
                const SizedBox(height: 10),
                // 只有第一篇印標題：回覆的 subject 是伺服器語系的「回覆: …」，
                // 重複又難看。
                if (_isRoot && p.subject.isNotEmpty) SectionSubLabel(p.subject),
                _body(context, p),
                if (p.attachments.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SectionSubLabel(R.current.forumAttachments),
                  for (final f in p.attachments)
                    MoodleFileTile(
                      filename: f.filename,
                      onTap: () => onOpenFile(f),
                    ),
                ],
                if (canReply || hasOwnerActions) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (canReply) _ReplyLink(onTap: onReply),
                      const Spacer(),
                      if (hasOwnerActions)
                        IconButton(
                          tooltip: R.current.forumPostActions,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                              width: 32, height: 32),
                          icon: Icon(LucideIcons.ellipsisVertical,
                              size: 18, color: scheme.onSurfaceVariant),
                          onPressed: onActions,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 頭像（姓名首字）、作者、時間。首字圓片只是一個定位點，不打伺服器要
  /// 大頭貼：討論串一頁可能有三十則，那是三十個網路請求。
  Widget _header(BuildContext context, MoodleForumPost p, String name) {
    final scheme = context.scheme;
    final text = context.text;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _isRoot ? context.tokens.card : context.tokens.page,
            shape: BoxShape.circle,
          ),
          child: Text(
            _initialOf(name),
            style: text.labelMedium?.copyWith(
              color: _isRoot ? scheme.primary : scheme.onSurfaceVariant,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge?.copyWith(color: scheme.onSurface),
                ),
              ),
              if (_isRoot) ...[
                const SizedBox(width: 6),
                Text(
                  R.current.forumTopicStarter,
                  style: text.labelMedium?.copyWith(color: scheme.primary),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _timeLabel(p),
          style: AppTypography.tabular((text.bodySmall ?? const TextStyle())
              .copyWith(color: scheme.onSurfaceVariant)),
        ),
      ],
    );
  }

  /// 姓名首字。用 runes 取，不是 substring(0, 1)——後者會把一個代理對切成
  /// 半個字元，畫面上就是一個豆腐。
  static String _initialOf(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return "?";
    return String.fromCharCode(trimmed.runes.first);
  }

  Widget _body(BuildContext context, MoodleForumPost p) {
    final scheme = context.scheme;
    final text = context.text;
    if (p.isdeleted) {
      return Text(R.current.forumPostDeleted,
          style: text.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant));
    }
    if (p.message.trim().isEmpty) {
      return Text(R.current.nothingHere,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant));
    }
    return MoodleHtmlView(
      html: p.message,
      title: title,
      dirName: dirName,
      openWebView: openWebView,
    );
  }

  /// 建立時間，被改過就接一句「已編輯」——少了這個記號，討論串會默默改寫歷史。
  /// `isdeleted` 的貼文 timecreated 是 null（post_exporter 這時不載內容）。
  static String _timeLabel(MoodleForumPost p) {
    final unix = p.timecreated ?? p.timemodified ?? 0;
    if (unix <= 0) return "";
    final formatted = DateFormat.MMMd()
        .add_jm()
        .format(DateTime.fromMillisecondsSinceEpoch(unix * 1000));
    final created = p.timecreated;
    final modified = p.timemodified;
    final edited = created != null && modified != null && modified > created;
    return edited ? '$formatted · ${R.current.forumEdited}' : formatted;
  }
}

/// 卡片裡的「回覆」。不是 TextButton：主題給每一顆鈕 44 的最小高度與 16 的
/// 側邊留白，塞在卡片裡就是一塊很大的空白。
class _ReplyLink extends StatelessWidget {
  const _ReplyLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(TatTokens.radiusButton),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.reply, size: 16, color: scheme.primary),
            const SizedBox(width: 7),
            Text(R.current.forumReply,
                style: context.text.labelMedium
                    ?.copyWith(color: scheme.primary, height: 1.2)),
          ],
        ),
      ),
    );
  }
}
