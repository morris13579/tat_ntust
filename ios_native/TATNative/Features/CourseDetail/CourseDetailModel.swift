import Observation

@MainActor
@Observable
final class CourseDetailModel {
  private(set) var result: CourseDetailResult?
  let course: CourseRef
  let client: CourseDetailClient

  init(client: CourseDetailClient, course: CourseRef) {
    self.client = client
    self.course = course
  }

  func load() async {
    let fetched = try? await client.detail(courseId: course.courseId, semester: course.semester)
    result = fetched ?? CourseDetailResult(error: L10n.unknownError)
  }
}

@MainActor
@Observable
final class CourseMembersModel {
  private(set) var members: CourseMembers?
  private(set) var visible: [CourseMember] = []
  var query = ""
  let course: CourseRef
  /// 上一頁就知道的人數，骨架的列數跟著它。
  let knownCount: Int
  private let client: CourseDetailClient

  init(client: CourseDetailClient, course: CourseRef, knownCount: Int) {
    self.client = client
    self.course = course
    self.knownCount = knownCount
  }

  /// 名單那支 API 很慢：重新整理時先清掉，畫面才看得出正在重抓。
  func load(refresh: Bool) async {
    if refresh { members = nil }
    let fetched = try? await client.members(courseId: course.courseId, refresh: refresh)
    members = fetched ?? CourseMembers(members: [], error: L10n.unknownError, signedIn: true)
    await filter()
  }

  func filter() async {
    guard let all = members?.members else {
      visible = []
      return
    }
    if query.trimmingCharacters(in: .whitespaces).isEmpty {
      visible = all
      return
    }
    visible = (try? await client.filterMembers(courseId: course.courseId, query: query)) ?? all
  }
}
