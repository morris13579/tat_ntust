import Foundation
import Observation

@MainActor
@Observable
final class CourseSearchModel {
  enum Phase {
    /// 還沒查過。
    case idle
    case loading
    case loaded(CourseSearchResults)
  }

  var keyword = ""
  private(set) var filter = CourseFilter.empty
  /// 預設打開：加退選時最常問的是「哪些我排得進去」。
  private(set) var hideConflict = true
  private(set) var slots: Set<TimeSlot> = []
  private(set) var phase: Phase = .idle
  private(set) var start: CourseSearchStart?
  /// 正在加入或移除的課號。
  private(set) var pending: Set<String> = []

  let client: CourseSearchClient
  /// 模擬排課時加進哪一份草稿；導入其他課程時是 nil。
  let draftId: String?
  private let onTableChange: @MainActor (CourseGrid) -> Void
  private var started = false
  private var generation = 0

  init(
    client: CourseSearchClient, draftId: String? = nil, onTableChange: @escaping @MainActor (CourseGrid) -> Void
  ) {
    self.client = client
    self.draftId = draftId
    self.onTableChange = onTableChange
  }

  /// 一進來先列課表上最多課的那個系，關鍵字欄一起填上，使用者才知道這批課從哪來。
  func begin() async {
    guard !started else { return }
    started = true
    start = try? await client.start(draftId: draftId)
    guard let keyword = start?.keyword else { return }
    self.keyword = keyword
    await submit()
  }

  func submit() async {
    filter.keyword = keyword
    await run()
  }

  /// 篩選是伺服器端的，改完就重查；條件全空才不查。
  func apply(_ next: CourseFilter) async {
    filter = next
    if !next.isEmpty { await run() }
  }

  func setHideConflict(_ on: Bool) async {
    hideConflict = on
    await refresh()
  }

  func setSlots(_ next: Set<TimeSlot>) async {
    slots = next
    await refresh()
  }

  /// 回傳 false 代表衝堂、沒有加進去。
  func toggle(_ course: SearchCourse) async -> Bool {
    guard !pending.contains(course.id) else { return true }
    pending.insert(course.id)
    defer { pending.remove(course.id) }
    let change: CourseSearchChange?
    if course.added {
      change = try? await client.remove(courseId: course.id)
    } else {
      change = try? await client.add(courseId: course.id)
    }
    guard let change else { return true }
    if change.applied, let grid = change.grid { onTableChange(grid) }
    await refresh()
    return change.applied
  }

  private func run() async {
    generation += 1
    let current = generation
    let (hide, picked) = (hideConflict, slots)
    phase = .loading
    let results = try? await client.search(filter, hideConflict: hide, slots: picked)
    guard current == generation else { return }
    phase = results.map(Phase.loaded) ?? .idle
    if hideConflict != hide || slots != picked { await refresh() }
  }

  private func refresh() async {
    guard case .loaded = phase,
      let results = try? await client.results(hideConflict: hideConflict, slots: slots)
    else { return }
    phase = .loaded(results)
  }
}

extension CourseFilter {
  static var empty: CourseFilter {
    CourseFilter(
      keyword: "", department: nil, dimension: nil, level: .all,
      foreignLanguageOnly: false, generalOnly: false, intensiveOnly: false, ntustOnly: false)
  }

  /// 關鍵字以外有沒有勾任何條件，「篩選」籤靠它顯示已套用。
  var hasRefinements: Bool {
    department != nil || dimension != nil || level != .all
      || foreignLanguageOnly || generalOnly || intensiveOnly || ntustOnly
  }

  var isEmpty: Bool {
    keyword.trimmingCharacters(in: .whitespaces).isEmpty && !hasRefinements
  }
}
