import SwiftUI
import SwiftData

/// Read/write/delete counterpart to "log a hit." Vibe-matched: solid sky bg
/// (no scroll-content offsets — same as HomeView), an activity grid of day
/// circles at the top, then session cards grouped by day. Each session row
/// expands to show individual hits with a context-menu for edit/delete.
struct HistoryView: View {
    @Environment(HitStore.self) private var store

    @State private var expandedSessions: Set<Date> = []
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

                    ActivityGridCard(store: store)

                    if daySections.isEmpty {
                        emptyState
                    } else {
                        ForEach(daySections, id: \.key) { day in
                            daySectionCard(day)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)  // breathing room for the bottom bar
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

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text.caveat("no hits yet")
                .font(.driftCardTitle)
                .foregroundStyle(.driftInk)
            Text("logged hits will appear here.")
                .font(.driftLabel)
                .foregroundStyle(.driftInkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .driftCard()
    }

    @ViewBuilder
    private func daySectionCard(_ day: DaySection) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text.caveat(day.title)
                .font(.driftCardTitle)
                .foregroundStyle(.driftInk)

            VStack(spacing: 10) {
                ForEach(day.sessions, id: \.id) { session in
                    sessionRow(session)
                    if expandedSessions.contains(session.start) {
                        VStack(spacing: 6) {
                            ForEach(session.hits, id: \.persistentModelID) { hit in
                                hitRow(hit)
                            }
                        }
                        .padding(.leading, 22)
                        .padding(.top, 2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .driftCard()
    }

    @ViewBuilder
    private func sessionRow(_ session: Session) -> some View {
        let isExpanded = expandedSessions.contains(session.start)
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isExpanded { expandedSessions.remove(session.start) }
                else { expandedSessions.insert(session.start) }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.driftInkFade)
                    .frame(width: 14)

                Text(timeOfDay(session.start))
                    .font(.driftLabel)
                    .foregroundStyle(.driftInk)

                Spacer()

                Text(session.count == 1 ? "solo hit" : "session of \(session.count) hits")
                    .font(.driftSub)
                    .foregroundStyle(.driftInkSoft)
            }
        }
        .buttonStyle(.plain)
    }

    private func hitRow(_ hit: Hit) -> some View {
        HStack {
            Circle()
                .fill(Color.driftCoral.opacity(0.6))
                .frame(width: 6, height: 6)
            Text(timeOfDay(hit.t))
                .font(.driftSub)
                .foregroundStyle(.driftInkSoft)
            Spacer()
        }
        .contentShape(Rectangle())
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

    // MARK: - Day grouping

    private struct DaySection {
        let key: String
        let title: String
        let sessions: [Session]
    }

    private var daySections: [DaySection] {
        let allSessions = store.hits.sessions(threshold: store.sessionThresholdSec)
        let grouped = Dictionary(grouping: allSessions, by: \.wakingDayKey)
        return grouped.keys.sorted(by: >).map { key in
            let sessions = (grouped[key] ?? []).sorted { $0.start > $1.start }
            return DaySection(key: key, title: dayTitle(for: key), sessions: sessions)
        }
    }

    private func dayTitle(for wakingDayKey: String) -> String {
        let cal = Calendar(identifier: .gregorian)
        if wakingDayKey == currentWakingDayKey() { return "today" }

        let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!
        if wakingDayKey == currentWakingDayKey(yesterday) { return "yesterday" }

        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        if let date = f.date(from: wakingDayKey) {
            let display = DateFormatter()
            display.dateFormat = "EEE · MMM d"
            return display.string(from: date).lowercased()
        }
        return wakingDayKey
    }
}

// MARK: - Activity grid

/// GitHub-style contribution grid using circles instead of squares. 7 columns
/// (Sun..Sat) × N rows (most recent week at the bottom). Each cell's opacity is
/// bucketed by session count for that day; today gets a coral ring.
private struct ActivityGridCard: View {
    let store: HitStore

    private let columns = 7        // days of week
    private let rows = 7           // ~7 weeks back

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text.caveat("the last 7 weeks")
                .font(.driftCardTitle)
                .foregroundStyle(.driftInk)

            grid
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .driftCard()
    }

    private var grid: some View {
        let cells = buildCells()
        // Layout: rows of 7 each, oldest week first / newest at bottom.
        return VStack(spacing: 8) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: 8) {
                    ForEach(0..<columns, id: \.self) { c in
                        let i = r * columns + c
                        cell(cells[i])
                    }
                }
            }
        }
    }

    private func cell(_ data: ActivityCell) -> some View {
        Circle()
            .fill(Color.driftSageDeep.opacity(data.opacity))
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if data.isToday {
                    Circle().strokeBorder(Color.driftCoral, lineWidth: 1.5)
                }
            }
    }

    private struct ActivityCell {
        let date: Date
        let opacity: Double
        let isToday: Bool
    }

    /// Build cells oldest-first so the bottom-right is "today" — mirrors GitHub.
    private func buildCells() -> [ActivityCell] {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())

        // Today's column index (0=Sun .. 6=Sat in default Gregorian) — but
        // .weekday is 1-indexed so subtract 1.
        let todayCol = (cal.component(.weekday, from: today) - 1).clamped(to: 0...6)

        // Total cells; last cell is today. Compute the date for cell 0:
        let totalCells = rows * columns
        let daysBack = totalCells - 1 - (columns - 1 - todayCol)
        let firstDate = cal.date(byAdding: .day, value: -(totalCells - 1), to: today)!

        // Map device-local date keys to session counts for the rolling window.
        let allSessions = store.hits.sessions(threshold: store.sessionThresholdSec)
        let countsByDay = Dictionary(grouping: allSessions, by: \.logLocalDateKey).mapValues(\.count)
        let maxCount = countsByDay.values.max() ?? 0

        var result: [ActivityCell] = []
        result.reserveCapacity(totalCells)
        for i in 0..<totalCells {
            let day = cal.date(byAdding: .day, value: i, to: firstDate)!
            let key = deviceLocalDateKey(day)
            let count = countsByDay[key] ?? 0
            result.append(ActivityCell(
                date: day,
                opacity: bucketedOpacity(count: count, max: maxCount),
                isToday: cal.isDate(day, inSameDayAs: today)
            ))
        }
        _ = daysBack
        return result
    }

    /// GitHub-style discrete buckets so a chart with one outlier doesn't
    /// completely flatten the rest. Empty days get a faint floor so the grid
    /// never reads as totally blank.
    private func bucketedOpacity(count: Int, max: Int) -> Double {
        if count == 0 { return 0.10 }
        guard max > 0 else { return 0.10 }
        let ratio = Double(count) / Double(max)
        switch ratio {
        case ..<0.25: return 0.30
        case ..<0.5:  return 0.50
        case ..<0.75: return 0.70
        default:       return 0.90
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Add / Edit sheets (used by ContentView's bottom-bar menu too)

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
