import Flutter

/// 課表頁的核心呼叫。
@MainActor
final class CourseTableClient {
  private let api: TatCourseTableApi

  init(messenger: FlutterBinaryMessenger) {
    api = TatCourseTableApi(binaryMessenger: messenger)
  }

  func current() async throws -> CourseGrid? {
    try await pigeonCall { api.current(completion: $0) }
  }

  func load(semester: String?, refresh: Bool) async throws -> CourseGrid? {
    try await pigeonCall { api.load(semester: semester, refresh: refresh, completion: $0) }
  }

  func semesters() async throws -> [String] {
    try await pigeonCall { api.semesters(completion: $0) }
  }

  func preloadSemesters() async throws {
    try await pigeonCall { api.preloadSemesters(completion: $0) }
  }

  func myTables() async throws -> [MyTable] {
    try await pigeonCall { api.myTables(completion: $0) }
  }

  func applyMyTable(_ table: MyTable) async throws -> CourseGrid? {
    try await pigeonCall {
      api.applyMyTable(studentId: table.studentId, semester: table.semester, completion: $0)
    }
  }

  func deleteMyTable(_ table: MyTable) async throws {
    try await pigeonCall {
      api.deleteMyTable(studentId: table.studentId, semester: table.semester, completion: $0)
    }
  }

  func share() async throws -> TableShare? {
    try await pigeonCall { api.share(completion: $0) }
  }

  func sharedTables() async throws -> [SharedTableInfo] {
    try await pigeonCall { api.sharedTables(completion: $0) }
  }

  func sharedTable(id: String) async throws -> CourseGrid? {
    try await pigeonCall { api.sharedTable(id: id, completion: $0) }
  }

  func deleteSharedTable(id: String) async throws {
    try await pigeonCall { api.deleteSharedTable(id: id, completion: $0) }
  }

  func previewShareCode(_ raw: String) async throws -> SharePreview? {
    try await pigeonCall { api.previewShareCode(raw: raw, completion: $0) }
  }

  func lookupPreview(raw: String) async throws -> [SharedCourseInfo] {
    try await pigeonCall { api.lookupPreview(raw: raw, completion: $0) }
  }

  func importShareCode(_ raw: String) async throws -> SharedTableInfo? {
    try await pigeonCall { api.importShareCode(raw: raw, completion: $0) }
  }

  func restoreSharedTable(id: String) async throws -> CourseGrid? {
    try await pigeonCall { api.restoreSharedTable(id: id, completion: $0) }
  }

  func removeCourse(_ cell: CourseGridCell) async throws -> CourseGrid? {
    try await pigeonCall { api.removeCourse(day: cell.day, section: cell.section, completion: $0) }
  }

  func emptySlot(day: Int64, section: Int64) async throws -> EmptySlot? {
    try await pigeonCall { api.emptySlot(day: day, section: section, completion: $0) }
  }

  func editCourseId(_ cell: CourseGridCell, to courseId: String) async throws -> CourseGrid? {
    try await pigeonCall {
      api.editCourseId(day: cell.day, section: cell.section, courseId: courseId, completion: $0)
    }
  }
}

extension CourseGridCell: Identifiable {
  var id: String { "\(day)-\(section)" }
}
