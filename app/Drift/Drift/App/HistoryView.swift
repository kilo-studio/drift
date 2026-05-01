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

            ScrollView {
                VStack(spacing: 16) {
                    Text.caveat("history")
                        .font(.driftHeroLabel)
                        .foregroundStyle(.driftInkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 36)

                    CalendarCard(
                        sessions: allSessions,
                        displayedMonth: $displayedMonth,
                        selectedDay: $selectedDay
                    )

                    selectedDayCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
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

    /// Computed once per body render and passed down so the calendar and the
    /// day card aren't both invoking `hits.sessions(threshold:)` independently.
    private var allSessions: [Session] {
        store.hits.sessions(threshold: store.sessionThresholdSec)
    }

    @ViewBuilder
    private var selectedDayCard: some View {
        let key = wakingDayKey(for: selectedDay)
        let sessions = allSessions
            .filter { $0.wakingDayKey == key }
            .sorted { $0.start > $1.start }
        let totalHits = sessions.reduce(0) { $0 + $1.count }
        let avgGap = avgGapBetweenSessions(sessions: sessions)
        let stretches = store.hits.stretches(
            forWakingDayKey: key,
            threshold: store.sessionThresholdSec
        )

        VStack(alignment: .leading, spacing: 14) {
            Text.caveat(dayTitle(for: selectedDay))
                .font(.driftCardTitle)
                .foregroundStyle(.driftInk)

            if sessions.isEmpty {
                Text("no hits this day.")
                    .font(.driftLabel)
                    .foregroundStyle(.driftInkSoft)
                    .padding(.vertical, 12)
            } else {
                statStrip(
                    sessionCount: sessions.count,
                    hitCount: totalHits,
                    avgGapSec: avgGap
                )

                if stretches.count >= 1 {
                    DayStretchesChart(stretches: stretches)
                        .frame(height: 90)
                        .padding(.top, 4)
                }

                Divider().opacity(0.3)

                VStack(spacing: 10) {
                    ForEach(sessions, id: \.id) { session in
                        sessionRow(session)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .driftCard()
    }

    private func statStrip(sessionCount: Int, hitCount: Int, avgGapSec: TimeInterval?) -> some View {
        HStack(spacing: 18) {
            stat(value: "\(sessionCount)", label: sessionCount == 1 ? "session" : "sessions", color: .driftCoral)
            divider
            stat(value: "\(hitCount)", label: hitCount == 1 ? "hit" : "hits", color: .driftInk)
            divider
            stat(
                value: avgGapSec.map { formatGap($0) } ?? "—",
                label: "avg gap",
                color: .driftSageDeep
            )
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.driftInkFade.opacity(0.25))
            .frame(width: 1, height: 26)
    }

    private func stat(value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.driftSub)
                .foregroundStyle(.driftInkSoft)
        }
    }

    @ViewBuilder
    private func sessionRow(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(timeOfDay(session.start))
                    .font(.driftLabel)
                    .foregroundStyle(.driftInk)
                Spacer()
                Text(session.count == 1 ? "solo hit" : "session of \(session.count) hits")
                    .font(.driftSub)
                    .foregroundStyle(.driftInkSoft)
            }
            if session.count > 1 {
                FlowLayout(spacing: 6, runSpacing: 6) {
                    ForEach(session.hits, id: \.persistentModelID) { hit in
                        hitChip(hit)
                    }
                }
            }
        }
    }

    private func hitChip(_ hit: Hit) -> some View {
        Text(timeOfDay(hit.t))
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.driftInkSoft)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.driftCoral.opacity(0.15), in: Capsule())
            .contextMenu {
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
            }
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
    let sessions: [Session]
    @Binding var displayedMonth: Date
    @Binding var selectedDay: Date

    private let cal = Calendar(identifier: .gregorian)

    var body: some View {
        VStack(spacing: 14) {
            header

            HStack(spacing: 0) {
                ForEach(["s", "m", "t", "w", "t", "f", "s"], id: \.self) { dow in
                    Text(dow)
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
        HStack {
            Button {
                displayedMonth = cal.date(byAdding: .month, value: -1, to: displayedMonth)!
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.driftInk)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Menu {
                ForEach(monthYearOptions, id: \.self) { date in
                    Button(monthYearLabel(date)) {
                        displayedMonth = date
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text.caveat(monthYearLabel(displayedMonth))
                        .font(.driftCardTitle)
                        .foregroundStyle(.driftInk)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.driftInkSoft)
                }
            }

            Spacer()

            Button {
                displayedMonth = cal.date(byAdding: .month, value: 1, to: displayedMonth)!
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.driftInk)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var monthYearOptions: [Date] {
        let now = Date()
        let start = cal.date(byAdding: .month, value: -12, to: now)!
        var options: [Date] = []
        for i in 0..<25 {
            if let d = cal.date(byAdding: .month, value: i, to: cal.startOfMonth(start)) {
                options.append(d)
            }
        }
        return options.reversed()
    }

    private func monthYearLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date).lowercased()
    }

    private var grid: some View {
        let cells = buildCells()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(cells.indices, id: \.self) { i in
                let cell = cells[i]
                if let date = cell.date {
                    dayCircle(date: date, count: cell.count, inMonth: cell.inMonth)
                } else {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    @ViewBuilder
    private func dayCircle(date: Date, count: Int, inMonth: Bool) -> some View {
        let isSelected = cal.isDate(date, inSameDayAs: selectedDay)
        let isToday = cal.isDateInToday(date)
        let opacity = bucketedOpacity(count: count)
        let dayNumber = cal.component(.day, from: date)

        Button {
            selectedDay = cal.startOfDay(for: date)
        } label: {
            ZStack {
                if count > 0 {
                    Circle().fill(Color.driftSageDeep.opacity(opacity))
                } else {
                    Circle().strokeBorder(Color.driftSageDeep.opacity(0.25), lineWidth: 1)
                }
                if isToday {
                    Circle().strokeBorder(Color.driftCoral, lineWidth: 1.5)
                }
                if isSelected {
                    Circle().strokeBorder(Color.driftInk, lineWidth: 2).padding(-2)
                }
                Text("\(dayNumber)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(textColor(filled: count > 0, inMonth: inMonth))
            }
            .aspectRatio(1, contentMode: .fit)
            .opacity(inMonth ? 1 : 0.35)
        }
        .buttonStyle(.plain)
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

    private func buildCells() -> [Cell] {
        let monthStart = cal.startOfMonth(displayedMonth)
        let range = cal.range(of: .day, in: .month, for: monthStart) ?? 1..<31
        let daysInMonth = range.count

        let firstWeekday = cal.component(.weekday, from: monthStart) - 1

        let countsByKey = Dictionary(grouping: sessions, by: \.logLocalDateKey).mapValues(\.count)

        var cells: [Cell] = []
        for _ in 0..<firstWeekday {
            cells.append(Cell(date: nil, count: 0, inMonth: false))
        }
        for d in 1...daysInMonth {
            var comps = cal.dateComponents([.year, .month], from: monthStart)
            comps.day = d
            let date = cal.date(from: comps)!
            let key = String(format: "%04d-%02d-%02d", comps.year!, comps.month!, d)
            cells.append(Cell(date: date, count: countsByKey[key, default: 0], inMonth: true))
        }
        let trailing = (7 - cells.count % 7) % 7
        for _ in 0..<trailing {
            cells.append(Cell(date: nil, count: 0, inMonth: false))
        }
        return cells
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

// MARK: - FlowLayout (wrap row of chips)

private struct FlowLayout: Layout {
    var spacing: CGFloat
    var runSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = layout(subviews: subviews, maxWidth: maxWidth)
        let height = rows.last?.maxY ?? 0
        let width = rows.flatMap { $0.frames }.map { $0.maxX }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = layout(subviews: subviews, maxWidth: bounds.width)
        for row in rows {
            for (idx, frame) in row.frames.enumerated() {
                let i = row.startIndex + idx
                subviews[i].place(
                    at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                    proposal: ProposedViewSize(width: frame.width, height: frame.height)
                )
            }
        }
    }

    private struct Row {
        let startIndex: Int
        let frames: [CGRect]
        var maxY: CGFloat { frames.map { $0.maxY }.max() ?? 0 }
    }

    private func layout(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current: [CGRect] = []
        var startIdx = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for (idx, sv) in subviews.enumerated() {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, !current.isEmpty {
                rows.append(Row(startIndex: startIdx, frames: current))
                startIdx = idx
                current = []
                x = 0
                y += rowHeight + runSpacing
                rowHeight = 0
            }
            current.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        if !current.isEmpty {
            rows.append(Row(startIndex: startIdx, frames: current))
        }
        return rows
    }
}

// MARK: - Add / Edit sheets

struct AddHitSheet: View {
    @Environment(HitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date = Date()
    @State private var futureWarning = false

    var body: some View {
        NavigationStack {
            Form {
                Section("when") {
                    DatePicker("time", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                }
                Section("quick") {
                    Button("5 minutes ago") { date = Date().addingTimeInterval(-300) }
                    Button("15 minutes ago") { date = Date().addingTimeInterval(-900) }
                    Button("1 hour ago") { date = Date().addingTimeInterval(-3600) }
                }
            }
            .navigationTitle("add hit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        if date > Date() {
                            futureWarning = true
                        } else {
                            try? store.addPast(at: date)
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Can't add hits in the future.", isPresented: $futureWarning) {
                Button("OK", role: .cancel) {}
            }
        }
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
