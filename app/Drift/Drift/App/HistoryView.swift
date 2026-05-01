import SwiftUI
import SwiftData

/// Read/write/delete counterpart to "log a hit." Sessions grouped by waking day,
/// tap to expand into their individual hits, swipe a hit for edit / delete, +
/// button in the toolbar for "add a forgotten hit."
struct HistoryView: View {
    @Environment(HitStore.self) private var store

    @State private var expandedSessions: Set<Date> = []
    @State private var hitToEdit: Hit?
    @State private var hitToDelete: Hit?
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("history")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showAddSheet) {
                    AddHitSheet(store: store)
                }
                .sheet(item: $hitToEdit) { hit in
                    EditHitSheet(hit: hit, store: store)
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
    }

    @ViewBuilder
    private var content: some View {
        if daySections.isEmpty {
            ContentUnavailableView(
                "no hits yet",
                systemImage: "clock",
                description: Text("logged hits will appear here.")
            )
        } else {
            List {
                ForEach(daySections, id: \.key) { day in
                    Section(day.title) {
                        ForEach(day.sessions, id: \.id) { session in
                            sessionRow(session)
                            if expandedSessions.contains(session.start) {
                                ForEach(session.hits, id: \.persistentModelID) { hit in
                                    hitRow(hit)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    @ViewBuilder
    private func sessionRow(_ session: Session) -> some View {
        let isExpanded = expandedSessions.contains(session.start)
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isExpanded {
                    expandedSessions.remove(session.start)
                } else {
                    expandedSessions.insert(session.start)
                }
            }
        } label: {
            HStack {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)

                Text(timeOfDay(session.start))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)

                Spacer()

                Text(session.count == 1 ? "solo hit" : "session of \(session.count) hits")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func hitRow(_ hit: Hit) -> some View {
        HStack {
            Color.clear.frame(width: 22)
            Text(timeOfDay(hit.t))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                hitToDelete = hit
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                hitToEdit = hit
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
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
            return DaySection(
                key: key,
                title: dayTitle(for: key),
                sessions: sessions
            )
        }
    }

    private func dayTitle(for wakingDayKey: String) -> String {
        let cal = Calendar(identifier: .gregorian)
        let todayKey = currentWakingDayKey()
        if wakingDayKey == todayKey { return "today" }

        let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!
        let yKey = currentWakingDayKey(yesterday)
        if wakingDayKey == yKey { return "yesterday" }

        // Otherwise full date: "Mon · Apr 28"
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

private func timeOfDay(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "h:mm a"
    f.amSymbol = "a"
    f.pmSymbol = "p"
    return f.string(from: date).lowercased()
}

// Stable per-render id for SwiftUI's ForEach over derived sessions.
extension Session: Identifiable {
    var id: Date { start }
}

// MARK: - Sheets

private struct AddHitSheet: View {
    let store: HitStore
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

private struct EditHitSheet: View {
    let hit: Hit
    let store: HitStore
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date

    init(hit: Hit, store: HitStore) {
        self.hit = hit
        self.store = store
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

