import SwiftUI

extension LinearGradient {
    static let driftSky = LinearGradient(
        stops: [
            Gradient.Stop(color: .driftSkyTop,      location: 0.00),
            Gradient.Stop(color: .driftSkyUpperMid, location: 0.30),
            Gradient.Stop(color: .driftSkyLowerMid, location: 0.65),
            Gradient.Stop(color: .driftSkyHorizon,  location: 1.00),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let driftSunHaze = LinearGradient(
        stops: [
            Gradient.Stop(color: Color(red: 1.0, green: 220.0/255.0, blue: 150.0/255.0).opacity(0.45), location: 0.00),
            Gradient.Stop(color: .clear, location: 0.25),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}
