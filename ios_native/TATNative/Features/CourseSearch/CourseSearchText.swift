/// 搜尋與篩選頁上幾組列舉的顯示字。
enum CourseSearchText {
  static func level(_ level: ProgramLevel) -> String {
    switch level {
    case .all: L10n.courseSearchLevelAny
    case .underGraduate: L10n.courseSearchLevelUnder
    case .master: L10n.courseSearchLevelMaster
    }
  }

  static func dimension(_ dimension: GeDimension) -> String {
    switch dimension {
    case .a: L10n.courseDimensionA
    case .b: L10n.courseDimensionB
    case .c: L10n.courseDimensionC
    case .d: L10n.courseDimensionD
    case .e: L10n.courseDimensionE
    case .f: L10n.courseDimensionF
    }
  }

  /// querycourse 的向度代碼，「A」。
  static func code(_ dimension: GeDimension) -> String {
    String(describing: dimension).uppercased()
  }

  static func requirement(_ requirement: CourseRequirement) -> String {
    switch requirement {
    case .compulsory: L10n.courseRequired
    case .elective: L10n.courseElective
    }
  }
}
