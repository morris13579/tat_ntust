import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_gradereport_get_grade_items.dart';

/// Moodle 成績項目怎麼顯示。App 的課程成績分頁與原生版共用同一套規則。
class MoodleGradeUtils {
  MoodleGradeUtils._();

  /// 這一列要顯示的標題。
  ///
  /// 伺服器對課程總分與類別總分不送 itemname，那兩類要由 App 自己補字。判斷一律
  /// 用 itemType，不要比對中文字串——「課程總分」那幾個字是 Moodle 依**使用者的
  /// Moodle 介面語言**產生的，與 App 語系無關，比字串在英文介面下會靜靜失效。
  static String titleOf(MoodleGradeItemEntity item) {
    final name = item.itemName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (item.isCourseTotal) return R.current.courseTotal;
    if (item.isCategoryTotal) return R.current.categoryTotal;
    return "";
  }

  /// 標題底下那一行：百分比、權量、全距，最後在有回饋時補一個「回饋」，
  /// 那是這一列可以點開的唯一提示——沒有這一個字的話，十幾列長得一模一樣，
  /// 看不出哪一列按下去會有東西。
  static String metaOf(MoodleGradeItemEntity item,
      {required bool hasFeedback}) {
    final parts = [
      if (hasContent(item.percentageFormatted)) plain(item.percentageFormatted),
      if (hasContent(item.weightFormatted))
        "${R.current.weight} ${plain(item.weightFormatted)}",
      if (hasContent(item.rangeFormatted))
        "${R.current.fullRange} ${plain(item.rangeFormatted)}",
      if (hasFeedback) R.current.gradeFeedbackTag,
    ];
    return parts.join(" · ");
  }

  /// Moodle 對「沒有值」送的是空字串或整串 `&nbsp;`（解碼邊界還原之後是
  /// U+00A0），兩種都要當成空。
  ///
  /// 還有第三種：未評分的項目 `gradeformatted`／`percentageformatted` 送的是
  /// 一個破折號。照字串長度算的話分數欄會印一個裸的「-」、副標第一段也會是
  /// 「-」，都是看起來像壞掉的畫面。整串只有破折號才算空——全距的 `0–100`
  /// 也含破折號，但它有數字。
  static bool hasContent(String? content) {
    final text = plain(content);
    return text.isNotEmpty && !_onlyDashes.hasMatch(text);
  }

  static final RegExp _onlyDashes = RegExp(r"^[-‐-―\s]+$");

  /// 這一列有沒有老師回饋。
  ///
  /// 不能拿 [hasContent] 來問：`feedback` 是 HTML，Moodle 對「沒有回饋」
  /// 也可能送一個 `<div class="no-overflow"></div>` 這樣的空殼。照字串長度算
  /// 的話每一列都會掛上「回饋」，等於這個提示不存在，也等於每一列都點得開、
  /// 點開卻是空的。
  static bool hasFeedback(String? content) {
    final html = content ?? "";
    if (html.trim().isEmpty) return false;
    // 只有圖片或附件、一個字都沒有的回饋照樣算數。
    if (_mediaTag.hasMatch(html)) return true;
    return hasContent(html.replaceAll(_anyTag, " "));
  }

  static final RegExp _anyTag = RegExp(r"<[^>]*>");
  static final RegExp _mediaTag =
      RegExp(r"<\s*(img|a|video|audio|iframe)\b", caseSensitive: false);

  /// `*formatted` 是純文字（HTML 實體已在 `MoodleRepository.normalizeScore`
  /// 還原），只是伺服器會用不換行空格當單位的間隔（`85.00 %`），
  /// 排版上要當成普通空白。
  static String plain(String? content) =>
      (content ?? "").replaceAll(" ", " ").replaceAll("&nbsp;", " ").trim();
}
