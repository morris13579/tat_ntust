/// 從課表點進一門課要帶的東西。
struct CourseRef: Hashable {
  let courseId: String
  let name: String
  /// 「115-1」。課程資訊要照課表的學期查，同一個課號在不同學期是不同的老師與教室。
  let semester: String
}
