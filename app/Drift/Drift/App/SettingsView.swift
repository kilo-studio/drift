import SwiftUI
import UniformTypeIdentifiers

/// Settings tab. Detail surfaces (currently just notifications) come up as
/// sheets from the bottom — push navigation felt heavy for what's essentially
/// "drill into one group of toggles." Sheets keep the page in context, the
/// drag-down dismiss is intuitive, and the swipe-to-dismiss matches the rest
/// of the app's sheet vocabulary (AddHitSheet, EditHitSheet).
struct SettingsView: View {
    @Environment(HitStore.self) private var store
    @State private var showResetConfirm: Bool = false
    @State private var showNotifications: Bool = false

    @State private var showImporter: Bool = false
    /// Parsed file held between picking and confirming — the replace only runs
    /// once the user OKs the destructive warning.
    @State private var pendingImport: PrototypeImport.Parsed?
    @State private var importError: String?

    #if DEBUG
    /// The debug seed card is hidden until you tap the version row 7 times —
    /// keeps it out of the way during normal use (and it's already compiled out
    /// of release builds entirely).
    @State private var debugTapCount: Int = 0
    @State private var showDebugCard: Bool = false
    /// Held between tapping a scenario and confirming the destructive replace.
    @State private var pendingSeed: DebugScenario?
    #endif

    private static let thresholdOptions: [TimeInterval] = [60, 180, 300, 600, 900, 1800]
    private static let windowOptions: [Int] = [7, 14, 30, 60]
    private static let hourOptions: [Int] = Array(0...23)

    var body: some View {
        @Bindable var store = store

        ZStack {
            Color.driftSkyLowerMid.ignoresSafeArea()
            AmbientLayer()

            ScrollView {
                VStack(spacing: 16) {
                    Text.caveat("settings")
                        .font(.driftHeroLabel)
                        .foregroundStyle(.driftInkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 36)
                        #if DEBUG
                        // Secret: tap the title 7× to reveal the debug seed card.
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard !showDebugCard else { return }
                            debugTapCount += 1
                            if debugTapCount >= 7 {
                                withAnimation(.easeInOut(duration: 0.4)) { showDebugCard = true }
                            }
                        }
                        #endif

                    sessionsCard(store: $store)
                    rollingWindowCard(store: $store)
                    sleepWindowCard(store: $store)
                    notificationsCard
                    dataCard
                    onboardingCard
                    aboutCard
                    #if DEBUG
                    if showDebugCard {
                        debugCard
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    #endif
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
                // Drift the sheet's chrome to match the rest of the app — same
                // sky color the parent uses, so the sheet reads as a continuation
                // of the surface rather than a system-default white panel. The
                // sheet's grabber + rounded corners + shadow still signal "modal"
                // even with matching color.
                .presentationBackground(.driftSkyLowerMid)
        }
        .alert("Reset all data?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) {
                try? store.resetEverything()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every logged hit will be deleted and your records reset to zero. This can't be undone.")
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            handleImportPick(result)
        }
        .alert("Replace all data?", isPresented: Binding(
            get: { pendingImport != nil },
            set: { if !$0 { pendingImport = nil } }
        ), presenting: pendingImport) { parsed in
            Button("Replace", role: .destructive) {
                try? store.replaceWithImport(parsed)
                pendingImport = nil
            }
            Button("Cancel", role: .cancel) { pendingImport = nil }
        } message: { parsed in
            Text("This will delete your current hits and replace them with the \(parsed.hits.count) in this file. This can't be undone.")
        }
        .alert("Import failed", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "")
        }
        #if DEBUG
        .alert("Replace all data?", isPresented: Binding(
            get: { pendingSeed != nil },
            set: { if !$0 { pendingSeed = nil } }
        ), presenting: pendingSeed) { scenario in
            Button("Seed", role: .destructive) {
                store.seedScenario(scenario)
                pendingSeed = nil
            }
            Button("Cancel", role: .cancel) { pendingSeed = nil }
        } message: { scenario in
            Text("This wipes every logged hit and replaces it with the “\(scenario.label)” scenario. Debug only — can't be undone.")
        }
        #endif
    }

    /// Read + parse the picked file. Validation happens before the replace
    /// warning so a bad file never wipes anything — on success we stash the
    /// parsed result and let the confirmation alert drive the destructive step.
    private func handleImportPick(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }  // .failure = user cancelled
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            pendingImport = try PrototypeImport.parse(data)
        } catch {
            importError = "That file couldn't be read as a Drift export."
        }
    }

    // MARK: - Cards

    private func sessionsCard(store: Bindable<HitStore>) -> some View {
        SettingsCard {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    label: "use sessions",
                    description: "Group rapid hits into one session. When off, every tap counts on its own.",
                    isOn: store.useSessions
                )
                if store.wrappedValue.useSessions {
                    SettingsDivider()
                    SettingsPickerRow(
                        label: "session threshold",
                        description: "Rapid hits within this gap collapse into a single session.",
                        selection: store.sessionThresholdSec,
                        options: Self.thresholdOptions,
                        formatted: { formatThreshold($0) }
                    )
                }
            }
        }
    }

    private func rollingWindowCard(store: Bindable<HitStore>) -> some View {
        SettingsCard {
            SettingsPickerRow(
                label: "rolling window",
                description: "How many days of history feed your average stats.",
                selection: store.rollingWindowDays,
                options: Self.windowOptions,
                formatted: { "\($0) days" }
            )
        }
    }

    private func sleepWindowCard(store: Bindable<HitStore>) -> some View {
        SettingsCard {
            VStack(spacing: 0) {
                SettingsPickerRow(
                    label: "bedtime",
                    description: "Notifications soften their tone after this hour.",
                    selection: store.sleepStartHour,
                    options: Self.hourOptions,
                    formatted: { formatHour($0) }
                )
                SettingsDivider()
                SettingsPickerRow(
                    label: "end of day",
                    description: "Hits before this hour count as the previous day's stats.",
                    selection: store.sleepEndHour,
                    options: Self.hourOptions,
                    formatted: { formatHour($0) }
                )
            }
        }
    }

    /// Whole-card button — tapping anywhere on the row brings up the
    /// notifications sheet from the bottom. `.buttonStyle(.plain)` strips the
    /// default tap highlight so the row reads as a normal settings row.
    private var notificationsCard: some View {
        Button {
            showNotifications = true
        } label: {
            SettingsCard {
                SettingsNavRow(
                    label: "notifications",
                    description: "Master switch, per-type toggles, timing offsets."
                )
            }
        }
        .buttonStyle(.plain)
    }

    private var dataCard: some View {
        SettingsCard {
            VStack(spacing: 0) {
                ShareLink(item: store.makeHitsExport(), preview: SharePreview("Drift history")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("export history")
                            .font(.driftRowLabel)
                            .foregroundStyle(.driftInk)
                        Text("Save every logged hit as a JSON file you can keep in Files or share elsewhere.")
                            .font(.driftRowDescription)
                            .foregroundStyle(.driftInkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                SettingsDivider()
                Button {
                    showImporter = true
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("import history")
                            .font(.driftRowLabel)
                            .foregroundStyle(.driftInk)
                        Text("Restore from a Drift export file. This replaces all hits currently logged.")
                            .font(.driftRowDescription)
                            .foregroundStyle(.driftInkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                SettingsDivider()
                Button {
                    showResetConfirm = true
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("reset all data")
                            .font(.driftRowLabel)
                            .foregroundStyle(.driftCoral)
                        Text("Delete every logged hit and clear records. Cannot be undone.")
                            .font(.driftRowDescription)
                            .foregroundStyle(.driftInkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Re-run onboarding lives on its own card, away from the destructive
    /// data actions — it's a harmless "walk through setup again," not a data
    /// operation, so grouping it with export/import/reset misrepresented it.
    private var onboardingCard: some View {
        SettingsCard {
            Button {
                UserDefaults.standard.removeObject(forKey: driftOnboardingCompleteKey)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("re-run onboarding")
                        .font(.driftRowLabel)
                        .foregroundStyle(.driftInk)
                    Text("Walk through the setup carousel again. Your hits stay where they are.")
                        .font(.driftRowDescription)
                        .foregroundStyle(.driftInkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    #if DEBUG
    /// Debug-only dataset switcher — seed any home-screen mode/state on tap so
    /// the long-stretch work is easy to jump between. Compiled out of release.
    private var debugCard: some View {
        SettingsCard {
            VStack(spacing: 0) {
                Text("debug · seed scenario")
                    .font(.driftRowDescription)
                    .foregroundStyle(.driftInkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(DebugScenario.allCases) { scenario in
                    SettingsDivider()
                    Button {
                        pendingSeed = scenario
                    } label: {
                        Text(scenario.label)
                            .font(.driftRowLabel)
                            .foregroundStyle(.driftInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    #endif

    private var aboutCard: some View {
        SettingsCard {
            VStack(spacing: 0) {
                SettingsLinkRow(label: "privacy policy", url: URL(string: "https://github.com/kilo-studio/drift/blob/main/Privacy.md")!)
                SettingsDivider()
                SettingsLinkRow(label: "github", url: URL(string: "https://github.com/kilo-studio/drift")!)
                SettingsDivider()
                SettingsLinkRow(label: "buy me a coffee", url: URL(string: "https://buymeacoffee.com/griffinmullins")!)
            }
        }
    }

    // MARK: - Format helpers

    private func formatThreshold(_ sec: TimeInterval) -> String {
        let m = Int(sec / 60)
        return m == 1 ? "1 min" : "\(m) min"
    }

    /// Hour 0–23 → friendly clock label. "midnight" / "noon" for 0/12, "Xam" /
    /// "Xpm" otherwise.
    private func formatHour(_ h: Int) -> String {
        if h == 0 { return "midnight" }
        if h == 12 { return "noon" }
        if h < 12 { return "\(h) am" }
        return "\(h - 12) pm"
    }
}
