import SwiftUI
import SwiftData
import Charts

/// History page: a month calendar with day circles whose fill ramps with the
/// session count, and a card below showing the selected day's count + avg gap
/// + stretches chart + sessions.
struct HistoryView: View {
    @Environment(HitStore.self) private var store

    @State private var displayedMonth: Date = Calendar(identifier: .gregorian).startOfMonth(Date())
    @State private var selectedDay: Date = Calendar(identifier: .gregorian).startOfDay(for: Date())
    @State private var hitToEdit: Hit?
    @State private var hitToDelete: Hit?

    var body: some View {
        ZStack {
            Color.driftSkyLowerMid.ignoresSafeArea()
            AmbientLayer()

            if store.hits.isEmpty {
                emptyState
                    .transition(.opacity.animation(.easeOut(duration: 0.4)))
            } else {
                content
                    .transition(.opacity.animation(.easeIn(duration: 0.6)))
            }
        }
        .sheet(item: $hitToEdit) { hit in
            EditHitSheet(hit: hit)
        }
        .alert("Delete this hit?", isPresented: .init(
            get: { hitToDelete != nil },
            set: { if !$0 { hitToDelete = nil } }
        ), presenting: hitToDelete) { hit in
            Button("Delete", role: .destructive) {
                try? store.remove(hit)
                hitToDelete = nil
            }
            Button("Cancel", role: .cancel) { hitToDelete = nil }
        } message: { hit in
            Text(timeOfDay(hit.t))
        }
    }

    /// Empty-state surface — no calendar to render and nothing to drill into.
    /// Keeps the page from showing a blank month grid with zero data.
    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Text.caveat("history")
                .font(.driftHeroLabel)
                .foregroundStyle(.driftInkSoft)
            Text("Your history will live here.\nLog your first hit on the home tab.")
                .font(.driftRowDescription)
                .foregroundStyle(.driftInkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Real history surface — calendar + selected-day section. Pulled into a
    /// computed view so the body can cleanly switch between this and the
    /// empty state via `if/else`.
    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text.caveat("history")
                    .font(.driftHeroLabel)
                    .foregroundStyle(.driftInkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 36)

                CalendarCard(
                    countsByDay: countsByDay,
                    displayedMonth: $displayedMonth,
                    selectedDay: $selectedDay
                )

                selectedDaySection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
        }
    }

    /// Computed once per body render and passed down so the calendar and the
    /// day card aren't both invoking `hits.sessions(threshold:)` independently.
    private var allSessions: [Session] {
        store.hits.sessions(threshold: store.effectiveSessionThreshold)
    }

    /// Per-device-local-day session counts. Built once for the calendar to read
    /// — calendar cells just do an O(1) dictionary lookup per day instead of
    /// re-grouping all sessions on every render.
    private var countsByDay: [String: Int] {
        Dictionary(grouping: allSessions, by: \.logLocalDateKey).mapValues(\.count)
    }

    @ViewBuilder
    private var selectedDaySection: some View {
        let key = wakingDayKey(for: selectedDay)
        let sessions = allSessions
            .filter { $0.wakingDayKey == key }
            .sorted { $0.start > $1.start }
        let totalHits = sessions.reduce(0) { $0 + $1.count }
        let avgGap = avgGapBetweenSessions(sessions: sessions)
        let stretches = store.hits.stretches(
            forWakingDayKey: key,
            threshold: store.effectiveSessionThreshold
        )

        VStack(spacing: 16) {
            // Day label outside the cards, mirroring how "history" labels the page.
            Text.caveat(dayTitle(for: selectedDay))
                .font(.driftHeroLabel)
                .foregroundStyle(.driftInkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

            // Two stat cards side-by-side, matching home's hero stat row.
            HStack(spacing: 16) {
                StatCard(
                    title: store.useSessions ? "sessions" : "hits",
                    bigNumber: "\(store.useSessions ? sessions.count : totalHits)",
                    bigNumberColor: .driftCoral,
                    label: store.useSessions ? "\(totalHits) hit\(totalHits == 1 ? "" : "s")" : "this day"
                )
                StatCard(
                    title: "avg gap",
                    bigNumberParts: avgGap.map { formatGapParts($0) } ?? [.number("—")],
                    bigNumberColor: .driftSageDeep,
                    label: store.useSessions ? "between sessions" : "between hits"
                )
            }

            // Stretches chart, full-width like home's chart cards.
            if !stretches.isEmpty {
                ChartCard(
                    title: "stretches",
                    subtitle: "minutes between sessions",
                    chartHeight: 140
                ) {
                    DayStretchesChart(stretches: stretches)
                }
            }

            // Flat hits list — each row is a tap-to-open Menu with Edit/Delete.
            // Replaces the prior session-with-chips layout that ran a custom
            // FlowLayout per multi-hit session and chugged with many hits.
            if !sessions.isEmpty {
                hitsListCard(hits: dayHits(in: sessions))
            }
        }
    }

    private func dayHits(in sessions: [Session]) -> [Hit] {
        sessions.flatMap { $0.hits }.sorted { $0.t > $1.t }
    }

    private func hitsListCard(hits: [Hit]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text.caveat("hits")
                .font(.driftCardTitle)
                .foregroundStyle(.driftInk)

            VStack(spacing: 0) {
                ForEach(hits, id: \.persistentModelID) { hit in
                    hitRow(hit)
                    if hit.persistentModelID != hits.last?.persistentModelID {
                        Divider().opacity(0.25)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .driftCard()
    }

    private func hitRow(_ hit: Hit) -> some View {
        Menu {
            Button {
                hitToEdit = hit
            } label: {
                Label("Edit time", systemImage: "pencil")
            }
            Button(role: .destructive) {
                hitToDelete = hit
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.driftCoral.opacity(0.7))
                    .frame(width: 8, height: 8)
                Text(timeOfDay(hit.t))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.driftInk)
                Spacer()
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.driftInkFade)
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func avgGapBetweenSessions(sessions: [Session]) -> TimeInterval? {
        guard sessions.count >= 2 else { return nil }
        let sorted = sessions.sorted { $0.start < $1.start }
        var totalGap: TimeInterval = 0
        for i in 1..<sorted.count {
            totalGap += sorted[i].start.timeIntervalSince(sorted[i-1].end)
        }
        return totalGap / Double(sorted.count - 1)
    }

    private func dayTitle(for date: Date) -> String {
        let cal = Calendar(identifier: .gregorian)
        if cal.isDateInToday(date) { return "today" }
        if cal.isDateInYesterday(date) { return "yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEEE · MMM d"
        return f.string(from: date).lowercased()
    }

    private func wakingDayKey(for date: Date) -> String {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year!, comps.month!, comps.day!)
    }
}

// MARK: - Calendar card

private struct CalendarCard: View {
    /// Pre-grouped session counts by device-local "yyyy-MM-dd" key. Built once
    /// at HistoryView level so a tab swap or store change doesn't redo the
    /// grouping work for every day cell.
    let countsByDay: [String: Int]
    @Binding var displayedMonth: Date
    @Binding var selectedDay: Date

    private let cal = Calendar(identifier: .gregorian)

    var body: some View {
        VStack(spacing: 14) {
            header

            HStack(spacing: 0) {
                // Indices as IDs since "s" and "t" each appear twice — duplicate
                // \.self IDs cause SwiftUI to thrash diffing and burn CPU.
                let labels = ["s", "m", "t", "w", "t", "f", "s"]
                ForEach(labels.indices, id: \.self) { i in
                    Text(labels[i])
                        .font(.driftSub)
                        .foregroundStyle(.driftInkFade)
                        .frame(maxWidth: .infinity)
                }
            }

            grid
        }
        .frame(maxWidth: .infinity)
        .driftCard()
    }

    private var header: some View {
        let canPrev = canGoPrev
        let canNext = canGoNext
        return HStack {
            chevron(.left, enabled: canPrev) {
                displayedMonth = cal.date(byAdding: .month, value: -1, to: displayedMonth)!
            }

            Spacer()

            Text.caveat(monthYearLabel(displayedMonth))
                .font(.driftCardTitle)
                .foregroundStyle(.driftInk)

            Spacer()

            chevron(.right, enabled: canNext) {
                displayedMonth = cal.date(byAdding: .month, value: 1, to: displayedMonth)!
            }
        }
    }

    private enum ChevronDirection { case left, right }

    private func chevron(_ dir: ChevronDirection, enabled: Bool, action: @escaping () -> Void) -> some View {
        let symbol = dir == .left ? "chevron.left" : "chevron.right"
        return Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(enabled ? .driftInk : .driftInkFade.opacity(0.4))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    /// Allow going back as long as the previous month contains the user's first
    /// session, or any session — no point browsing pre-history months.
    private var canGoPrev: Bool {
        guard let oldestKey = countsByDay.keys.min() else { return false }
        let prevMonthStart = cal.date(byAdding: .month, value: -1, to: cal.startOfMonth(displayedMonth))!
        let prevMonthEndKey = String(
            format: "%04d-%02d-31",
            cal.component(.year, from: prevMonthStart),
            cal.component(.month, from: prevMonthStart)
        )
        return oldestKey <= prevMonthEndKey
    }

    /// Don't browse forward past the current month — no data there yet.
    private var canGoNext: Bool {
        let nowMonthStart = cal.startOfMonth(Date())
        return cal.startOfMonth(displayedMonth) < nowMonthStart
    }

    private func monthYearLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date).lowercased()
    }

    /// Manual VStack of HStacks instead of LazyVGrid — for a fixed 7-column
    /// month grid this is simpler and lays out faster. `.drawingGroup()`
    /// rasterizes the whole grid into a single Metal layer so 35-42 day cells
    /// don't compose as separate sublayers.
    private var grid: some View {
        let rows = monthRows
        return VStack(spacing: 8) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { c in
                        let cell = rows[r][c]
                        if let date = cell.date {
                            dayCircle(date: date, count: cell.count, inMonth: cell.inMonth)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
        }
        .drawingGroup()
    }

    @ViewBuilder
    private func dayCircle(date: Date, count: Int, inMonth: Bool) -> some View {
        let isSelected = cal.isDate(date, inSameDayAs: selectedDay)
        let isToday = cal.isDateInToday(date)
        let dayNumber = cal.component(.day, from: date)

        ZStack {
            if count > 0 {
                Circle().fill(Color.driftSageDeep.opacity(bucketedOpacity(count: count)))
            } else {
                Circle().strokeBorder(Color.driftSageDeep.opacity(0.25), lineWidth: 1)
            }
            if isToday {
                Circle().strokeBorder(Color.driftCoral, lineWidth: 1.5)
            }
            if isSelected {
                // No negative padding — drawingGroup clips outside the cell's
                // bounds, which would chop the selection ring on the bottom row.
                Circle().strokeBorder(Color.driftInk, lineWidth: 2)
            }
            Text("\(dayNumber)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(textColor(filled: count > 0, inMonth: inMonth))
        }
        .aspectRatio(1, contentMode: .fit)
        .opacity(inMonth ? 1 : 0.35)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDay = cal.startOfDay(for: date)
        }
    }

    private func textColor(filled: Bool, inMonth: Bool) -> Color {
        if !inMonth { return .driftInkFade }
        if filled { return .driftCream }
        return .driftInkSoft
    }

    private func bucketedOpacity(count: Int) -> Double {
        switch count {
        case 0:        return 0
        case 1...2:    return 0.35
        case 3...5:    return 0.55
        case 6...10:   return 0.72
        case 11...18:  return 0.85
        default:       return 1.0
        }
    }

    private struct Cell {
        let date: Date?
        let count: Int
        let inMonth: Bool
    }

    /// Row-major 7-cell rows; only as many rows as the month actually needs
    /// (5 or 6 typically). Trailing padding kept so the last row is always 7.
    private var monthRows: [[Cell]] {
        let monthStart = cal.startOfMonth(displayedMonth)
        let range = cal.range(of: .day, in: .month, for: monthStart) ?? 1..<31
        let daysInMonth = range.count
        let firstWeekday = cal.component(.weekday, from: monthStart) - 1

        var cells: [Cell] = []
        cells.reserveCapacity(42)
        for _ in 0..<firstWeekday {
            cells.append(Cell(date: nil, count: 0, inMonth: false))
        }
        for d in 1...daysInMonth {
            var comps = cal.dateComponents([.year, .month], from: monthStart)
            comps.day = d
            let date = cal.date(from: comps)!
            let key = String(format: "%04d-%02d-%02d", comps.year!, comps.month!, d)
            cells.append(Cell(date: date, count: countsByDay[key, default: 0], inMonth: true))
        }
        let trailing = (7 - cells.count % 7) % 7
        for _ in 0..<trailing {
            cells.append(Cell(date: nil, count: 0, inMonth: false))
        }

        return stride(from: 0, to: cells.count, by: 7).map {
            Array(cells[$0..<min($0 + 7, cells.count)])
        }
    }
}

// MARK: - Day stretches mini chart

private struct DayStretchesChart: View {
    let stretches: [(Date, TimeInterval)]

    private struct Point: Identifiable {
        let id = UUID()
        let index: Int
        let minutes: Double
    }

    private var points: [Point] {
        stretches.enumerated().map { i, s in Point(index: i, minutes: s.1 / 60) }
    }

    var body: some View {
        Chart(points) { p in
            AreaMark(
                x: .value("step", p.index),
                y: .value("min", p.minutes)
            )
            .foregroundStyle(LinearGradient(
                colors: [Color.driftCoral.opacity(0.35), Color.driftCoral.opacity(0.04)],
                startPoint: .top, endPoint: .bottom
            ))
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("step", p.index),
                y: .value("min", p.minutes)
            )
            .foregroundStyle(Color.driftCoral)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("step", p.index),
                y: .value("min", p.minutes)
            )
            .foregroundStyle(Color.driftCoral)
            .symbolSize(40)
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 2)) { _ in
                AxisGridLine().foregroundStyle(Color.driftInkFade.opacity(0.15))
                AxisValueLabel()
                    .font(.driftSub)
                    .foregroundStyle(.driftInkSoft)
            }
        }
    }
}

// MARK: - Add / Edit sheets

/// Mirrors `NotificationsView`'s sheet vocabulary: sky background, Caveat
/// hero label, SettingsCards, solid-coral CTA. The previous Form-based version
/// had Form's grouped-list white background painting over the presentation
/// background on every appearance, which read as a white flash.
struct AddHitSheet: View {
    @Environment(HitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date = Date()
    @State private var futureWarning = false

    var body: some View {
        ZStack {
            Color.driftSkyLowerMid.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    Text.caveat("add hit")
                        .font(.driftHeroLabel)
                        .foregroundStyle(.driftInkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 28)

                    SettingsCard {
                        DatePicker(
                            "time",
                            selection: $date,
                            in: ...Date(),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.compact)
                        .tint(.driftCoral)
                        .font(.driftRowLabel)
                        .foregroundStyle(.driftInk)
                    }

                    SettingsCard {
                        VStack(spacing: 0) {
                            quickRow(label: "5 minutes ago") {
                                date = Date().addingTimeInterval(-300)
                            }
                            SettingsDivider()
                            quickRow(label: "15 minutes ago") {
                                date = Date().addingTimeInterval(-900)
                            }
                            SettingsDivider()
                            quickRow(label: "1 hour ago") {
                                date = Date().addingTimeInterval(-3600)
                            }
                        }
                    }

                    Button {
                        if date > Date() {
                            futureWarning = true
                        } else {
                            try? store.addPast(at: date)
                            dismiss()
                        }
                    } label: {
                        Text("add hit")
                            .font(.driftRowLabel)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background {
                                Capsule().fill(Color.driftCoral)
                            }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }
        }
        .alert("Can't add hits in the future.", isPresented: $futureWarning) {
            Button("OK", role: .cancel) {}
        }
    }

    private func quickRow(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.driftRowLabel)
                    .foregroundStyle(.driftInk)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct EditHitSheet: View {
    let hit: Hit
    @Environment(HitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date

    init(hit: Hit) {
        self.hit = hit
        self._date = State(initialValue: hit.t)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("when") {
                    DatePicker("time", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("edit hit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        try? store.editHit(hit, to: date)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Helpers

private func timeOfDay(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "h:mm a"
    f.amSymbol = "a"
    f.pmSymbol = "p"
    return f.string(from: date).lowercased()
}

extension Session: Identifiable {
    var id: Date { start }
}

extension Calendar {
    func startOfMonth(_ date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}
