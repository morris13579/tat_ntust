import Foundation
import Observation

@MainActor
@Observable
final class ClassroomModel {
  private(set) var setup: ClassroomSetup?
  private(set) var day: ClassroomDay?
  private(set) var loading = false
  private(set) var layout: ClassroomLayout = .list
  private(set) var run: ClassroomRun = .any
  /// 「2026-09-13」。
  private(set) var date = ""
  private(set) var section: Int64 = 0
  private(set) var campusCode: String?
  private(set) var buildingCode: String?
  /// 各棟這一天抓到的時間。一次只查得到一棟，就把各棟的新舊講出來；換日期就清掉。
  private(set) var fetched: [String: Int64] = [:]

  let client: ClassroomClient
  /// 從課表的空堂格進來時開在那一天那一節，而不是現在。
  private let initialDate: String?
  private let initialSection: Int64?
  private var started = false
  private var generation = 0

  init(client: ClassroomClient, initialDate: String? = nil, initialSection: Int64? = nil) {
    self.client = client
    self.initialDate = initialDate
    self.initialSection = initialSection
  }

  var buildings: [ClassroomBuilding] {
    setup?.campuses.first { $0.code == campusCode }?.buildings ?? []
  }

  var currentBuilding: ClassroomBuilding? {
    buildings.first { $0.code == buildingCode }
  }

  var sections: [ClassSection] {
    setup?.sections ?? []
  }

  func start() async {
    guard !started else { return }
    started = true
    await loadSetup()
  }

  func loadSetup() async {
    setup = nil
    guard let setup = try? await client.start() else {
      self.setup = ClassroomSetup(
        campuses: [], layout: .list, now: ClassroomNow(date: "", section: 0), sections: [],
        error: L10n.somethingError, signedIn: true)
      return
    }
    self.setup = setup
    layout = setup.layout
    date = initialDate ?? setup.now.date
    section = initialSection ?? setup.now.section
    campusCode = setup.campusCode
    buildingCode = setup.buildingCode
    await reload(progress: true)
  }

  func select(building code: String) async {
    guard code != buildingCode else { return }
    buildingCode = code
    await client.rememberBuilding(code)
    await reload(progress: true)
  }

  /// 日期真的變了才清掉抓過的東西；只換節次的話同一天的資料照樣可以用，不必再打網路。
  func setTime(date: String, section: Int64) async {
    let dayChanged = date != self.date
    self.date = date
    self.section = section
    if dayChanged { fetched = [:] }
    await reload(progress: dayChanged)
  }

  func backToNow() async {
    guard let now = try? await client.now() else { return }
    await setTime(date: now.date, section: now.section)
  }

  func setLayout(_ layout: ClassroomLayout) async {
    self.layout = layout
    await client.rememberLayout(layout)
  }

  func setRun(_ run: ClassroomRun) async {
    self.run = run
    await reload(progress: false)
  }

  func refresh() async {
    await reload(progress: true, refresh: true)
  }

  private func reload(progress: Bool, refresh: Bool = false) async {
    guard let campusCode, let buildingCode else { return }
    generation += 1
    let current = generation
    if progress { loading = true }
    let result = try? await client.day(
      campus: campusCode, building: buildingCode, date: date, section: section, run: run,
      refresh: refresh)
    guard current == generation else { return }
    loading = false
    day =
      result
      ?? ClassroomDay(
        error: L10n.somethingError, closed: false, roomCount: 0, freeCount: 0, floors: [], free: [],
        busy: [])
    if let fetchedAt = result?.fetchedAt { fetched[buildingCode] = fetchedAt }
  }
}
