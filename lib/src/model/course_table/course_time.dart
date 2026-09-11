// ignore_for_file: constant_identifier_names
// SectionNumber 的列舉名是持久化的 JSON map key，見下方說明。

/// 課表的星期與節次。獨立成一個檔案是為了切斷
/// course_class_json ↔ course_table_json 的 import 環。
///
/// 重要：**enum 的名稱就是持久化格式**。course_table_json.g.dart 以名稱
/// 當作 JSON 的 map key，同時存在 `course_table_list` 與
/// `setting.course.info` 兩個 SharedPreferences key 裡。改名會讓
/// $enumDecode 失敗，連帶清空課表與整個 setting blob
/// （見 docs/ARCHITECTURE.md 的〈不可以改的東西〉）。
/// t_N 夾在 t_4 與 t_5 之間也是刻意的，那是中午 12:20–13:10 那一格。
/// `N` 只是內部代號（string2Time 逐字比對，每格必須單一字元），學校
/// 自己叫它第五節；顯示名稱一律走 `CourseTableControl.sectionStringList`。
enum Day {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday,
  unKnown
}

/// 節次。
///
/// 名稱**不能**改成 lowerCamelCase：CourseTableJson 直接用列舉名當作
/// JSON 的 map key 存進 SharedPreferences，改名會讓所有已存檔的課表
/// 在升級後讀不回來。這是整個檔案套用 ignore 的唯一原因。
enum SectionNumber {
  t_1,
  t_2,
  t_3,
  t_4,
  t_N,
  t_5,
  t_6,
  t_7,
  t_8,
  t_9,
  t_A,
  t_B,
  t_C,
  t_D,
  t_UnKnown
}
