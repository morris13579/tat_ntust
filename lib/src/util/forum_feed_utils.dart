import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_discussion_posts.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions.dart';
import 'package:intl/intl.dart';

/// 這一則是公告還是討論。公告分頁會把公告區與課程討論區併成同一條時間軸，
/// filter chip 要數得出兩邊各有幾則。
enum ForumFeedKind { announcement, discussion }

/// 清單上的一則討論串，外加「它是從哪個討論區來的」。
///
/// 兩者都是 `mod_forum` 的討論串，只差在誰能發文，所以列型完全一樣；帶著
/// [forumId] 是因為點進討論串頁之後附件政策要用它，而合併之後那個 id 不再
/// 只有一個。
class ForumFeedItem {
  const ForumFeedItem(
    this.discussion, {
    required this.kind,
    required this.forumId,
  });

  /// 公告區來的。
  const ForumFeedItem.announcement(this.discussion, {required this.forumId})
      : kind = ForumFeedKind.announcement;

  /// 一般討論區來的。
  const ForumFeedItem.discussion(this.discussion, {required this.forumId})
      : kind = ForumFeedKind.discussion;

  final Discussions discussion;
  final ForumFeedKind kind;

  /// forum instance id。舊快取解回來是 0，那時附件入口會收起來。
  final int forumId;
}

/// 清單上的一格：月份標題，或某一則討論串。
///
/// 攤平成一維是為了 `ListView.builder`：討論區可能有好幾百則主題，包成
/// 巢狀的 `Column` 會在進頁時全部建出來。
class ForumListEntry {
  const ForumListEntry.header(this.label)
      : item = null,
        indexInGroup = 0,
        groupLength = 0;

  const ForumListEntry.item(
    ForumFeedItem this.item, {
    required this.indexInGroup,
    required this.groupLength,
  }) : label = "";

  /// 月份標題，例如「6月」。只有 header 有值。
  final String label;

  final ForumFeedItem? item;

  /// 這一則在所屬月份裡的位置，決定四個角的圓角。
  final int indexInGroup;
  final int groupLength;

  bool get isHeader => item == null;

  /// 只有 item 格能問。
  Discussions get discussion => item!.discussion;
}

/// 把幾個來源併成一條時間軸：置頂的在前，其餘照建立時間由新到舊。
///
/// **排序只發生在合併的時候**：單一討論區照伺服器給的順序畫（見
/// [groupDiscussionsByMonth]），但兩個討論區各自排好的清單接起來並不會自己
/// 變成一條時間軸，所以這裡必須重排。置頂仍然在最前面——那是老師刻意釘上去
/// 的，把它丟回時間軸中間等於把那個動作抹掉。
List<ForumFeedItem> mergeForumFeed(Iterable<List<ForumFeedItem>> sources) {
  final merged = [for (final source in sources) ...source];
  merged.sort((a, b) {
    final pinned = _pinnedRank(a).compareTo(_pinnedRank(b));
    if (pinned != 0) return pinned;
    return b.discussion.created.compareTo(a.discussion.created);
  });
  return merged;
}

int _pinnedRank(ForumFeedItem item) => item.discussion.pinned ? 0 : 1;

/// 公告與討論區清單的月份分組。
///
/// **只切連續的同月份區段，不重排**：伺服器已經排好（置頂在前、其餘由新到
/// 舊），照月份重新集中會把置頂的那幾則丟回時間軸中間。置頂的舊主題會自己
/// 形成一段同名的分組，那正好說明了它為什麼排在最前面。
///
/// 標題只寫月份（設計稿 7e）：年份對一門課沒有分辨力，寫出來只是每一段都
/// 多四個字。真的撞名時（前後兩段都是「6月」，中間隔了整整一年）才補上年份，
/// 否則畫面上會出現兩個一模一樣的標題。
List<ForumListEntry> groupDiscussionsByMonth(List<ForumFeedItem> items) {
  final monthFormatter = DateFormat.MMM();
  final yearMonthFormatter = DateFormat.yMMM();
  final entries = <ForumListEntry>[];
  // 目前這一段的起點與長度，用來回填每一則在段裡的位置。
  var groupStart = 0;
  var groupLength = 0;
  // 分段的依據是年＋月，不是印出來的那行字：只看月份的話，隔了一年的同一個
  // 月份會被接成同一段。
  ({int year, int month})? key;
  String? label;

  void closeGroup() {
    for (var i = 0; i < groupLength; i++) {
      final entry = entries[groupStart + 1 + i];
      entries[groupStart + 1 + i] = ForumListEntry.item(
        entry.item!,
        indexInGroup: i,
        groupLength: groupLength,
      );
    }
  }

  for (final item in items) {
    final at =
        DateTime.fromMillisecondsSinceEpoch(item.discussion.created * 1000);
    final itemKey = (year: at.year, month: at.month);
    if (itemKey != key) {
      if (key != null) closeGroup();
      key = itemKey;
      var text = monthFormatter.format(at);
      if (text == label) text = yearMonthFormatter.format(at);
      label = text;
      groupStart = entries.length;
      groupLength = 0;
      entries.add(ForumListEntry.header(text));
    }
    entries.add(
        ForumListEntry.item(item, indexInGroup: groupLength, groupLength: 0));
    groupLength += 1;
  }
  if (key != null) closeGroup();
  return entries;
}

/// 課程目錄裡要併進公告頁的討論區（forum instance id），扣掉公告區本身。
///
/// 公告區的 id 在舊快取裡是 0，那時只剩名稱這條線索：[looksLikeAnnouncement]
/// 由呼叫端帶進來，connector 找公告區時用的是同一組線索。
List<int> forumModulesToMerge(
  List<MoodleCoreCourseGetContents> contents, {
  required int announcementForumId,
  required bool Function(String name) looksLikeAnnouncement,
}) {
  final found = <int>[];
  final seen = <int>{};
  for (final section in contents) {
    for (final m in section.modules) {
      if (m.modname != 'forum' || m.instance <= 0) continue;
      if (m.instance == announcementForumId) continue;
      if (announcementForumId == 0 && looksLikeAnnouncement(m.name)) continue;
      if (!seen.add(m.instance)) continue;
      found.add(m.instance);
    }
  }
  return found;
}

/// 拆開 Moodle 的 `userfullname`。
class ForumAuthorName {
  const ForumAuthorName(this.name, this.studentId);

  final String name;

  /// null ＝這一串裡沒有學號（老師、或站台的格式不一樣）。
  final String? studentId;

  /// 臺科 Moodle 的格式是「B11000004 @ 王小明」；老師只有名字。認不出來時
  /// 整串當名字，不從名字裡「湊」一個學號出來。
  static ForumAuthorName of(String fullname) {
    final raw = fullname.trim();
    final at = raw.indexOf('@');
    if (at <= 0 || at == raw.length - 1) return ForumAuthorName(raw, null);
    final id = raw.substring(0, at).trim();
    final name = raw.substring(at + 1).trim();
    if (id.isEmpty || name.isEmpty) return ForumAuthorName(raw, null);
    return ForumAuthorName(name, id);
  }
}

/// 清單列上的日期。年月由分組標題說了，列上只留「N 日」；同一天的改印時間，
/// 那是唯一一個「幾號」分不出先後的情況。
String forumDayLabel(int createdUnix, DateTime now) {
  final created = DateTime.fromMillisecondsSinceEpoch(createdUnix * 1000);
  final sameDay = created.year == now.year &&
      created.month == now.month &&
      created.day == now.day;
  return sameDay
      ? DateFormat.jm().format(created)
      : DateFormat.d().format(created);
}

/// 姓名首字。用 runes 取，不是 substring(0, 1)——後者會把一個代理對切成半個字元，
/// 畫面上就是一個豆腐。
String forumInitialOf(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return "?";
  return String.fromCharCode(trimmed.runes.first);
}

/// 貼文的建立時間，被改過就接一句「已編輯」——少了這個記號，討論串會默默改寫歷史。
/// `isdeleted` 的貼文 timecreated 是 null（post_exporter 這時不載內容）。
String forumPostTimeLabel(MoodleForumPost p) {
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
