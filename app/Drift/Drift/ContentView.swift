import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("home", systemImage: "house.fill") {
                HomeView()
            }
            Tab("history", systemImage: "list.bullet") {
                HistoryView()
            }
        }
    }
}
