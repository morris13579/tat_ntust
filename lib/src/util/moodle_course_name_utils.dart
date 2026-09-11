/// NTUST Moodle 課名的純函式。
class MoodleCourseNameUtils {
  MoodleCourseNameUtils._();

  /// NTUST 課名前綴 `115.1【AT1001301】`；容忍沒有「.」與前後空白。
  static final RegExp _coursePrefix =
      RegExp(r'^\s*\d{3}\.?[0-9A-Za-z]\s*【[^】]*】\s*');

  /// 去掉前綴；去完是空字串就退回原字串（trim 過），不比對到就原樣回傳。
  static String stripCoursePrefix(String name) {
    final trimmed = name.trim();
    final stripped = trimmed.replaceFirst(_coursePrefix, '').trim();
    return stripped.isEmpty ? trimmed : stripped;
  }

  /// `idnumber` 的前 4 碼是學年學期（`1151CS3039701`），其餘就是課號。
  static const int semesterPrefixLength = 4;

  static String? courseIdOfIdNumber(String idnumber) {
    final trimmed = idnumber.trim();
    if (trimmed.length <= semesterPrefixLength) return null;
    return trimmed.substring(semesterPrefixLength);
  }

  /// 課名裡的課號。只有 `idnumber` 是空的時候才走這條。
  ///
  /// 兩種格式都要吃：`115.1【資工系】CS3039701 網路生活與應用程式` 的【】裡是
  /// **系所**、課號在後面；也有課的【】裡直接就是課號。所以不認位置，只認長相
  /// ——課號是 2-3 個大寫字母接數字或大寫字母、合計 9 碼。
  /// 光看「2-3 個大寫字母接英數」會把 `NETWORKED` 這種九個字母的全大寫英文字
  /// 當成課號，而假課號會被 `matchCourseId` 的課名模糊比對拿去配到別門課。
  /// 真的課號數字佔多數（`CS3039701`、`CS490B001` 最少也有六個數字），所以
  /// 另外要求至少五個數字。
  static final RegExp _courseIdToken = RegExp(r'^[A-Z]{2,3}[0-9A-Z]+$');
  static const int _courseIdMinDigits = 5;

  static final RegExp _candidates = RegExp(
      r'【([^】]*)】|\(\s*\d{4}([0-9A-Z]+)\s*\)|\b([A-Z]{2,3}[0-9A-Z]{6,7})\b');

  static bool _looksLikeCourseId(String token) {
    if (token.length != courseIdLength) return false;
    if (!_courseIdToken.hasMatch(token)) return false;
    final digits = token.runes.where((r) => r >= 0x30 && r <= 0x39).length;
    return digits >= _courseIdMinDigits;
  }

  static String? courseCodeOf(String name) {
    for (final match in _candidates.allMatches(name.trim())) {
      for (var group = 1; group <= 3; group++) {
        final token = match.group(group)?.trim();
        if (token != null && _looksLikeCourseId(token)) return token;
      }
    }
    return null;
  }

  /// NTUST 課號固定 9 碼（`CS3039701`、`TCG159301`、`CS490B001`）。
  static const int courseIdLength = 9;
}
