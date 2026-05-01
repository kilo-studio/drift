import SwiftUI
import SwiftData

/// History page: a month calendar with day circles whose fill ramps with the
/// session count, and a section below showing the selected day's sessions.
/// Tap a day in the calendar to drill in.
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
                        store: store,
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

    @ViewBuilder
    private var selectedDayCard: some View {
        let sessions = sessionsForSelectedDay
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

    private var sessionsForSelectedDay: [Session] {
        let key = wakingDayKey(for: selectedDay)
        return store.hits
            .sessions(threshold: store.sessionThresholdSec)
            .filter { $0.wakingDayKey == key }
            .sorted { $0.start > $1.start }
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
                HStack(spacing: 6) {
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

    private func dayTitle(for date: Date) -> String {
        let cal = Calendar(identifier: .gregorian)
        if cal.isDateInToday(date) { return "today" }
        if cal.isDateInYesterday(date) { return "yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEEE · MMM d"
        return f.string(from: date).lowercased()
    }

    private func wakingDayKey(for date: Date) -> String {
        // For the selected day in calendar, treat the day boundaries as device-local.
        // (The hits' own wakingDayKey already rolls 0–4am to the previous day.)
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year!, comps.month!, comps.day!)
    }
}

// MARK: - Calendar card

private struct CalendarCard: View {
    let store: HitStore
    @Binding var displayedMonth: Date
    @Binding var selectedDay: Date

    private let cal = Calendar(identifier: .gregorian)

    var body: some View {
        VStack(spacing: 14) {
            header

            // Day-of-week labels
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

            // Tap month/year label to open a year-month picker.
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

    /// 24 months of dropdown options (12 back, 12 forward) so the user can jump
    /// directly to a given month.
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

    // MARK: - Grid

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
                    Circle()
                        .fill(Color.driftSageDeep.opacity(opacity))
                } else {
                    Circle()
                        .strokeBorder(Color.driftSageDeep.opacity(0.25), lineWidth: 1)
                }
                if isToday {
                    Circle()
                        .strokeBorder(Color.driftCoral, lineWidth: 1.5)
                }
                if isSelected {
                    Circle()
                        .strokeBorder(Color.driftInk, lineWidth: 2)
                        .padding(-2)
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

    /// 6-step bucket so heavy days clearly differ from light days. Empty cells
    /// are handled separately as outline-only.
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

    // MARK: - Cells

    private struct Cell {
        let date: Date?    // nil = padding before first day / after last
        let count: Int
        let inMonth: Bool
    }

    private func buildCells() -> [Cell] {
        let monthStart = cal.startOfMonth(displayedMonth)
        let range = cal.range(of: .day, in: .month, for: monthStart) ?? 1..<31
        let daysInMonth = range.count

        // First weekday of month (1 = Sun)
        let firstWeekday = cal.component(.weekday, from: monthStart) - 1   // 0..6

        // Counts by device-local date key
        let allSessions = store.hits.sessions(threshold: store.sessionThresholdSec)
        let countsByKey = Dictionary(grouping: allSessions, by: \.logLocalDateKey).mapValues(\.count)

        var cells: [Cell] = []

        // Leading padding
        for _ in 0..<firstWeekday {
            cells.append(Cell(date: nil, count: 0, inMonth: false))
        }
        // Days of this month
        for d in 1...daysInMonth {
            var comps = cal.dateComponents([.year, .month], from: monthStart)
            comps.day = d
            let date = cal.date(from: comps)!
            let key = String(format: "%04d-%02d-%02d", comps.year!, comps.month!, d)
            cells.append(Cell(date: date, count: countsByKey[key, default: 0], inMonth: true))
        }
        // Trailing padding to round out the row
        let trailing = (7 - cells.count % 7) % 7
        for _ in 0..<trailing {
            cells.append(Cell(date: nil, count: 0, inMonth: false))
        }
        return cells
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
