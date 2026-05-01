import SwiftUI

struct ContentView: View {
    @State private var currentTab: AppTab = .home
    @State private var showAddSheet: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            switch currentTab {
            case .home:    HomeView()
            case .history: HistoryView()
            }

            BottomBar(currentTab: $currentTab, showAddSheet: $showAddSheet)
        }
        .sheet(isPresented: $showAddSheet) {
            AddHitSheet()
        }
    }
}
