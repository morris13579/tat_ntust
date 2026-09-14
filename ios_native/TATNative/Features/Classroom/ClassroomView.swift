import SwiftUI

/// 空教室，照 `classroom_page.dart`：先回答「現在」，再讓你往後看。大樓、時段與檢視放在一起，
/// 切換檢視不重設任何選擇。
struct ClassroomView: View {
  @Environment(AppEnvironment.self) private var app
  @State private var model: ClassroomModel
  @State private var sheet: Sheet?
  @State private var detail: RoomDetail?

  private enum Sheet: String, Identifiable {
    case building, time
    var id: String { rawValue }
  }

  private struct RoomDetail: Identifiable {
    let room: ClassroomRoom
    var id: String { room.name }
  }

  init(model: ClassroomModel) {
    _model = State(initialValue: model)
  }

  var body: some View {
    page
      .background(Color(.systemGroupedBackground))
      .navigationTitle(L10n.classroomTitle)
      .analyticsScreen("/ClassroomPage")
      .navigationBarTitleDisplayMode(.inline)
      .sheet(item: $sheet) { sheetContent($0) }
      .sheet(item: $detail) { detail in
        ClassroomRoomSheet(room: detail.room, sections: model.sections, section: Int(model.section))
      }
      .task { await model.start() }
  }

  @ViewBuilder private var page: some View {
    if let setup = model.setup {
      if let error = setup.error, setup.campuses.isEmpty {
        InlineErrorView(message: error, signedIn: setup.signedIn, presenter: app.presenter) {
          await model.loadSetup()
        }
        .frame(maxHeight: .infinity)
      } else {
        VStack(spacing: 0) {
          header
          sectionBar
          filters
          content
        }
      }
    } else {
      ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private var header: some View {
    HStack(spacing: 12) {
      Button {
        sheet = .building
      } label: {
        HStack(spacing: 2) {
          Text(model.currentBuilding?.name ?? L10n.classroomPickBuilding)
            .font(.headline)
            .lineLimit(1)
          LucideImage(Lucide.chevronDown, size: 18)
            .foregroundStyle(.secondary)
        }
        .foregroundStyle(Color.primary)
      }
      .buttonStyle(.plain)
      Spacer(minLength: 0)
      // 切的是「怎麼看這一棟」，跟大樓、時段是同一組決定，所以不放導覽列。
      Picker(
        L10n.classroomTitle,
        selection: Binding(get: { model.layout }, set: { layout in Task { await model.setLayout(layout) } })
      ) {
        Text(L10n.classroomViewList).tag(ClassroomLayout.list)
        Text(L10n.classroomViewDay).tag(ClassroomLayout.day)
      }
      .pickerStyle(.segmented)
      .frame(width: 150)
    }
    .padding(EdgeInsets(top: 8, leading: 16, bottom: 10, trailing: 16))
  }

  /// 節次一定帶時間，沒人記得第七節是幾點；不是今天時前面補上日期。
  private var sectionBar: some View {
    HStack(spacing: 8) {
      LucideImage(Lucide.clock, size: 15)
      Text(timeLabel)
        .font(.subheadline.weight(.medium).monospacedDigit())
        .lineLimit(1)
      Spacer(minLength: 8)
      Button(L10n.classroomChangeTime) { sheet = .time }
        .font(.subheadline.weight(.semibold))
    }
    .foregroundStyle(Color.tatBrand)
    .padding(.horizontal, 16)
    .padding(.vertical, 9)
    .background(Color.tatBrand.opacity(0.12))
  }

  private var timeLabel: String {
    let index = Int(model.section)
    guard index >= 0, index < model.sections.count else { return "" }
    let section = model.sections[index]
    let label = L10n.classroomSectionAt(section.label, "\(section.start)–\(section.end)")
    guard let date = CalendarKey.components(model.date)?.date, !Calendar.current.isDateInToday(date)
    else { return label }
    let formatter = DateFormatter()
    formatter.locale = L10n.locale
    formatter.setLocalizedDateFormatFromTemplate("MdEEE")
    return "\(formatter.string(from: date)) · \(label)"
  }

  /// 清單是連續節數篩選，一整天是圖示說明，兩者不同時出現。
  @ViewBuilder private var filters: some View {
    if model.layout == .day {
      HStack(spacing: 14) {
        legend(Color(.systemGroupedBackground), L10n.classroomLegendFree)
        legend(Color.tatBrand.opacity(0.5), L10n.classroomLegendClass)
        legend(Color(.systemOrange).opacity(0.5), L10n.classroomLegendBooked)
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
    } else {
      ScrollView(.horizontal) {
        HStack(spacing: 8) {
          ForEach(ClassroomRun.allCases, id: \.self) { run in
            FilterChip(label: Self.runLabel(run), isOn: model.run == run) {
              Task { await model.setRun(run) }
            }
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
      }
      .scrollIndicators(.hidden)
    }
  }

  private func legend(_ color: Color, _ label: String) -> some View {
    HStack(spacing: 6) {
      RoundedRectangle(cornerRadius: 4, style: .continuous)
        .fill(color)
        .overlay {
          RoundedRectangle(cornerRadius: 4, style: .continuous)
            .strokeBorder(Color(.separator), lineWidth: 0.5)
        }
        .frame(width: 14, height: 14)
      Text(label).font(.footnote).foregroundStyle(.secondary)
    }
  }

  @ViewBuilder private var content: some View {
    if model.loading {
      ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if let day = model.day {
      if let error = day.error, day.roomCount == 0, !day.closed {
        InlineErrorView(
          message: failedMessage(error), signedIn: model.setup?.signedIn ?? true, presenter: app.presenter
        ) {
          await model.refresh()
        }
        .frame(maxHeight: .infinity)
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 0) {
            if day.closed {
              closedDay
            } else if model.layout == .day {
              ClassroomDayGrid(day: day, sections: model.sections, section: Int(model.section)) {
                detail = RoomDetail(room: $0)
              }
            } else {
              list(day)
            }
            otherBuildings
            footer(day)
          }
          .padding(EdgeInsets(top: 4, leading: 16, bottom: 24, trailing: 16))
        }
      }
    } else {
      Spacer()
    }
  }

  @ViewBuilder private func list(_ day: ClassroomDay) -> some View {
    Text(L10n.classroomFreeSummary(String(day.roomCount), String(day.freeCount)))
      .font(.footnote)
      .foregroundStyle(.secondary)
      .padding(.horizontal, 8)
      .padding(.bottom, 10)
    if day.floors.isEmpty {
      full(day)
    }
    ForEach(Array(day.floors.enumerated()), id: \.offset) { _, floor in
      Text(floor.floor.map { L10n.classroomFloor(String($0)) } ?? "")
        .font(.sectionHeader)
        .foregroundStyle(.secondary)
        .padding(EdgeInsets(top: 14, leading: 4, bottom: 8, trailing: 4))
      VStack(spacing: 2) {
        ForEach(Array(floor.rooms.enumerated()), id: \.element.name) { index, room in
          Button {
            detail = RoomDetail(room: room)
          } label: {
            roomRow(room, index: index, count: floor.rooms.count)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  /// 主要資訊是「空到幾點」，不是課名：課名沒有時態，會被讀成「這間正在上課」。
  private func roomRow(_ room: ClassroomRoom, index: Int, count: Int) -> some View {
    HStack(spacing: 10) {
      VStack(alignment: .leading, spacing: 3) {
        Text(room.name)
          .foregroundStyle(Color.primary)
        Text(Self.subtitle(room))
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      Spacer(minLength: 0)
      Text(Self.badge(room))
        .font(.footnote.weight(.semibold).monospacedDigit())
        .foregroundStyle(Color(.systemGreen))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(.systemGreen).opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 12))
    .background(
      Color(.secondarySystemGroupedBackground), in: GroupedRowShape(index: index, count: count))
    .contentShape(Rectangle())
  }

  /// 全滿是正常結果，不是錯誤：沒有插圖也沒有驚嘆號，只給下一步。
  private func full(_ day: ClassroomDay) -> some View {
    let next = Int(model.section) + 1
    return VStack(spacing: 4) {
      Text(L10n.classroomFullTitle(model.currentBuilding?.name ?? "").trimmingCharacters(in: .whitespaces))
        .font(.headline)
      Text(L10n.classroomFullBody(String(day.roomCount)))
        .font(.subheadline)
        .foregroundStyle(.secondary)
      HStack(spacing: 10) {
        if next < model.sections.count {
          Button(L10n.classroomSeeSection(model.sections[next].label)) {
            Task { await model.setTime(date: model.date, section: Int64(next)) }
          }
          .prominentButtonStyle()
        }
        Button(L10n.classroomChangeBuilding) { sheet = .building }
          .buttonStyle(.bordered)
      }
      .padding(.top, 10)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 18)
  }

  /// 這一天站台一列都沒回。借用系統只排上課日：這不是錯誤，也不是「全部空著」。
  private var closedDay: some View {
    SectionEmptyState(
      message:
        "\(L10n.classroomClosedTitle(model.currentBuilding?.name ?? "").trimmingCharacters(in: .whitespaces))\n\(L10n.classroomClosedBody)",
      icon: Lucide.calendarDays)
  }

  /// 其他大樓。一次只查得到一棟，每一棟各自寫出自己的抓取時間，不假裝是一份即時的全校資料。
  @ViewBuilder private var otherBuildings: some View {
    let others = model.buildings.filter { $0.code != model.buildingCode }
    if !others.isEmpty {
      SectionHeader(title: L10n.classroomOtherBuildings)
      Text(L10n.classroomOtherBuildingsHint)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
      VStack(spacing: 2) {
        ForEach(Array(others.enumerated()), id: \.element.code) { index, building in
          Button {
            Task { await model.select(building: building.code) }
          } label: {
            HStack(spacing: 4) {
              Text(building.name)
                .foregroundStyle(Color.primary)
              Spacer(minLength: 8)
              if let fetchedAt = model.fetched[building.code] {
                Text(L10n.classroomLastFetched(Self.clock(Date(milliseconds: fetchedAt))))
                  .font(.footnote.monospacedDigit())
                  .foregroundStyle(.secondary)
              }
              LucideImage(Lucide.chevronRight, size: 18)
                .foregroundStyle(.secondary)
            }
            .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 10))
            .frame(minHeight: 48)
            .background(
              Color(.secondarySystemGroupedBackground), in: GroupedRowShape(index: index, count: others.count))
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  /// 跟著內容捲到底，不釘在畫面底部：它講的是這份資料什麼時候抓的，屬於資料的結尾。
  @ViewBuilder private func footer(_ day: ClassroomDay) -> some View {
    if let fetchedAt = day.fetchedAt {
      let clock = Self.clock(Date(milliseconds: fetchedAt))
      HStack {
        Text(
          model.layout == .day
            ? L10n.classroomDayFetchedAt(clock)
            : L10n.classroomFetchedAt(model.currentBuilding?.name ?? "", clock)
              .trimmingCharacters(in: .whitespaces)
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
        Spacer(minLength: 8)
        Button(L10n.classroomRefresh) { Task { await model.refresh() } }
          .font(.subheadline)
      }
      .padding(.top, 16)
    }
  }

  @ViewBuilder private func sheetContent(_ sheet: Sheet) -> some View {
    switch sheet {
    case .building:
      SheetStack(title: L10n.classroomPickBuilding) {
        List {
          ForEach(model.buildings, id: \.code) { building in
            CheckRow(label: building.name, isSelected: building.code == model.buildingCode) {
              self.sheet = nil
              Task { await model.select(building: building.code) }
            }
          }
        }
      }
    case .time:
      ClassroomTimeSheet(date: model.date, section: model.section, sections: model.sections) {
        date, section in
        Task { await model.setTime(date: date, section: section) }
      } onBackToNow: {
        Task { await model.backToNow() }
      }
    }
  }

  /// 抓不到時說出是哪一棟、什麼時候試的，「載入失敗」四個字幫不上忙。
  private func failedMessage(_ fallback: String) -> String {
    guard let building = model.currentBuilding else { return fallback }
    return L10n.classroomFetchFailed(building.name, Self.clock(Date()))
  }

  /// 第二行：下一堂是什麼、或者今天就這樣了。
  static func subtitle(_ room: ClassroomRoom) -> String {
    if room.freeAllDay { return L10n.classroomNoClassToday }
    guard let at = room.nextBusyAt else { return L10n.classroomNoMoreClass }
    if room.nextIsBooking { return L10n.classroomBookedFrom(at) }
    return L10n.classroomNextClass(at, room.nextCourse ?? "").trimmingCharacters(in: .whitespaces)
  }

  /// 右邊那一格：整天空著，或空到幾點。
  static func badge(_ room: ClassroomRoom) -> String {
    if room.freeAllDay { return L10n.classroomFreeAllDay }
    return room.freeUntil.map(L10n.classroomFreeUntil) ?? ""
  }

  static func runLabel(_ run: ClassroomRun) -> String {
    switch run {
    case .any: L10n.classroomRunAny
    case .twoSections: L10n.classroomRunTwo
    case .threeSections: L10n.classroomRunThree
    case .allDay: L10n.classroomRunAllDay
    }
  }

  static func clock(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
  }
}
