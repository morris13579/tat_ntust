import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:sprintf/sprintf.dart';

/// 討論串清單的一列。公告分頁與一般討論區頁共用，兩邊長得一樣才對——
/// 它們是同一種東西（forum discussion），只是討論區的 type 不同。
///
/// 一組列不是一張帶分隔線的卡片，而是每一列自己一塊、彼此差 2px
/// （[UIUtils.getBorderRadius]），與 App 其他清單同一套。
///
/// **沒有已讀未讀**：App 讀公告不會回寫 Moodle 的閱讀狀態，硬做出來的紅點
/// 會跟網頁版不一致（設計稿 7e）。`numunread` 因此刻意不畫。
class ForumDiscussionCard extends StatelessWidget {
  const ForumDiscussionCard({
    super.key,
    required this.discussion,
    required this.onTap,
    this.showReplies = true,
    this.now,
    this.index = 0,
    this.length = 1,
  });

  final Discussions discussion;
  final VoidCallback onTap;

  /// 回覆數。公告單獨一頁時不畫——那一頁的每一列都是老師的單向公告，一整排
  /// 「0」只是雜訊（設計稿 7e：沒有討論區時就少了 filter chip 與回覆數）。
  final bool showReplies;

  /// 「今天」的判斷基準；測試以外都是 null ＝ [DateTime.now]。
  final DateTime? now;

  /// 這一列在所屬月份分組裡的位置，決定四個角的圓角。
  final int index;
  final int length;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final text = context.text;
    final meta = (text.bodySmall ?? const TextStyle())
        .copyWith(color: scheme.onSurfaceVariant, height: 1.45);
    return Material(
      color: context.tokens.card,
      borderRadius: UIUtils.getBorderRadius(index, length),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (discussion.pinned) ...[
                          Icon(LucideIcons.pin,
                              size: 14, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            discussion.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyLarge?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w500,
                                height: 1.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    _meta(meta),
                  ],
                ),
              ),
              // App 現在做得出附件，清單就該看得出誰有。伺服器那一欄是
              // PARAM_RAW（`"1"` 或空字串），模型已經轉成 bool。
              if (discussion.attachment) ...[
                const SizedBox(width: 10),
                Icon(LucideIcons.paperclip,
                    size: 16, color: scheme.onSurfaceVariant),
              ],
              if (showReplies && discussion.numreplies > 0) ...[
                const SizedBox(width: 10),
                Semantics(
                  label: sprintf(R.current.forumReplies,
                      [discussion.numreplies.toString()]),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.messageCircle,
                          size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        '${discussion.numreplies}',
                        style: AppTypography.tabular(
                            meta.copyWith(fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 「姓名 · 學號 · 12日」。
  ///
  /// 學號是分開的一段而不是一整串照印：Moodle 回的 `userfullname` 在臺科是
  /// 「學號 @ 姓名」，名字要讀、學號要查，兩件事各有各的位置。認不出學號時
  /// 那一段就不畫——**不補「老師」也不猜**：伺服器沒說那個人是誰。
  Widget _meta(TextStyle style) {
    final author = _AuthorName.of(discussion.userfullname);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: author.name),
        if (author.studentId != null) ...[
          const TextSpan(text: ' · '),
          TextSpan(
            text: author.studentId,
            style: AppTypography.tabular(style),
          ),
        ],
        const TextSpan(text: ' · '),
        TextSpan(
          text: _dayLabel(),
          style: AppTypography.tabular(style),
        ),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }

  /// 年月由分組標題說了，列上只留「N 日」。
  ///
  /// 同一天的改印時間：那是唯一一個「幾號」分不出先後的情況。其餘一律不印
  /// 時間——公告不是聊天訊息，「上午 10:52」沒有影響任何決定（設計稿 7e）。
  String _dayLabel() {
    // 用建立時間：modified 是第一篇貼文被編輯過的時間，詳情頁那邊印的是建立時間。
    final created =
        DateTime.fromMillisecondsSinceEpoch(discussion.created * 1000);
    final today = now ?? DateTime.now();
    final sameDay = created.year == today.year &&
        created.month == today.month &&
        created.day == today.day;
    return sameDay
        ? DateFormat.jm().format(created)
        : DateFormat.d().format(created);
  }
}

/// 拆開 Moodle 的 `userfullname`。
class _AuthorName {
  const _AuthorName(this.name, this.studentId);

  final String name;

  /// null ＝這一串裡沒有學號（老師、或站台的格式不一樣）。
  final String? studentId;

  /// 臺科 Moodle 的格式是「B11000004 @ 王小明」；老師只有名字。認不出來時
  /// 整串當名字，不從名字裡「湊」一個學號出來。
  static _AuthorName of(String fullname) {
    final raw = fullname.trim();
    final at = raw.indexOf('@');
    if (at <= 0 || at == raw.length - 1) return _AuthorName(raw, null);
    final id = raw.substring(0, at).trim();
    final name = raw.substring(at + 1).trim();
    if (id.isEmpty || name.isEmpty) return _AuthorName(raw, null);
    return _AuthorName(name, id);
  }
}
