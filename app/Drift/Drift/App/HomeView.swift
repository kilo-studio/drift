import SwiftUI

struct HomeView: View {
    @Environment(HitStore.self) private var store

    var body: some View {
        ZStack {
            LinearGradient.driftSky.ignoresSafeArea()
            LinearGradient.driftSunHaze.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    HeroView(
                        lastHitDate: store.lastSessionEnd(),
                        longestWakingGapSec: store.longestWakingGapSec,
                        longestGapSec: store.longestGapSec
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 36)
                }
                .padding(.bottom, 96)
            }

            #if DEBUG
            debugHitButton
            #endif
        }
    }

    #if DEBUG
    private var debugHitButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    try? store.append()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.driftCoral)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 32)
            }
        }
    }
    #endif
}
