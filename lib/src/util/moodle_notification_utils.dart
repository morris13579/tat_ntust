import 'dart:convert';

import 'package:flutter_app/src/model/moodle_webapi/moodle_message_popup_notifications.dart';
import 'package:flutter_app/src/util/html_utils.dart';

/// 站內通知的純解析：內文挑欄位、customdata、可開啟的位址與排序。
///
/// component 對應的 icon 刻意不放這裡：util 層不 import material。
class MoodleNotificationUtils {
  MoodleNotificationUtils._();

  static final RegExp _tag = RegExp(r'<[^>]*>');
  static final RegExp _whitespace = RegExp(r'\s+');

  /// 詳情要算繪的 HTML。`@@PLUGINFILE@@` 沒被伺服器換掉時那段 HTML 的圖是壞的，
  /// 退回 `text`（smallmessage 的 HTML 版），再退回逸出後的 `fullmessage`。
  static String bodyHtmlOf(MoodleNotification n) {
    final html = n.fullmessagehtml.trim();
    if (html.isNotEmpty && !html.contains('@@PLUGINFILE@@')) return html;
    final text = n.text.trim();
    if (text.isNotEmpty) return text;
    final plain = n.fullmessage.trim();
    if (plain.isEmpty) return '';
    return '<p>${_escape(plain)}</p>';
  }

  /// 清單那一列的摘要，純文字。smallmessage 是各模組寫給推播用的短句，
  /// 缺席才退回 fullmessage / text。
  static String plainSummaryOf(MoodleNotification n) {
    for (final raw in [n.smallmessage, n.fullmessage, n.text]) {
      final value = _toPlainText(raw);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  /// `customdata` 可能是 null、字串 `"null"`、壞掉的 JSON 或不是物件的 JSON，
  /// 一律回空 map，永不拋。
  static Map<String, dynamic> customDataOf(MoodleNotification n) {
    final raw = n.customdata?.trim();
    if (raw == null || raw.isEmpty || raw == 'null') return const {};
    try {
      final decoded = json.decode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // 每個 provider 自己塞的 JSON，沒有 schema 保證。
    }
    return const {};
  }

  /// course module id。v1 不用來深連，但它是之後接回 App 內頁面的唯一線索。
  static int? cmidOf(MoodleNotification n) {
    final value = customDataOf(n)['cmid'];
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// 可以在 App 內開啟的位址。只認自家 https 站台：通知內容指到的外站不該
  /// 被當成自家頁面開，更不該套上免登入鑰匙。[siteHost] 由呼叫端給
  /// （util 不可以 import connector，那是上行邊）。
  static String? openUrlOf(MoodleNotification n, {required String siteHost}) {
    final raw = n.contexturl?.trim() ?? '';
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https' || uri.host != siteHost) {
      return null;
    }
    return uri.toString();
  }

  /// 伺服器已經照 newestfirst 排好，這裡只做防禦性的排序。時間相同時維持原順序
  /// （`List.sort` 不保證穩定，所以帶著原索引一起比）。
  static List<MoodleNotification> sortNewestFirst(
      List<MoodleNotification> list) {
    final indexed = [
      for (var i = 0; i < list.length; i++) (i, list[i]),
    ]..sort((a, b) {
        final byTime = b.$2.timecreated.compareTo(a.$2.timecreated);
        return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
      });
    return [for (final entry in indexed) entry.$2];
  }

  /// 本地時間 `MM/dd HH:mm`，跨年才補年份，同 `UpcomingEventUtils.formatDueTime`。
  /// **不用伺服器的 `timecreatedpretty`**：那串「N 分鐘前」是伺服器端依 Moodle
  /// 帳號語言算好的，跟 App 的語言切換打架，而且快取拿出來時早就過時。
  static String formatCreatedTime(DateTime created, DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    final day = '${two(created.month)}/${two(created.day)} '
        '${two(created.hour)}:${two(created.minute)}';
    return created.year == now.year ? day : '${created.year}/$day';
  }

  /// 清單空但未讀數不是 0 ＝ 使用者在 Moodle 關掉了站內通知：伺服器這時直接
  /// 回空清單，外層的 unreadcount 照算。跟「真的沒有通知」必須分得開。
  static bool looksDisabledByUser(MoodleNotificationList list) =>
      list.notifications.isEmpty && list.unreadcount > 0;

  /// 標籤剝掉、實體還原、空白收斂。輸出只進 Text。
  static String _toPlainText(String raw) {
    if (raw.trim().isEmpty) return '';
    final stripped = raw.replaceAll(_tag, ' ');
    return HtmlUtils.clean(stripped).replaceAll(_whitespace, ' ').trim();
  }

  static String _escape(String raw) => raw
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
