import SwiftUI

@main
struct ValueAppApp: App {
    @StateObject private var store = DealStore()
    @StateObject private var proximity = ProximityService()
    @StateObject private var auth = AuthSession()

    var body: some Scene {
        WindowGroup {
            LaunchFlowView()
                .environmentObject(store)
                .environmentObject(proximity)
                .environmentObject(auth)
                .tint(.valuePurple)
                .preferredColorScheme(.light)
                .task { proximity.connect(to: store) }
        }
    }
}

extension Color {
    static let valuePurple = Color(red: 0.33, green: 0.18, blue: 0.70)
    static let valueCoral = Color(red: 1.00, green: 0.39, blue: 0.34)
    static let valueCream = Color(red: 0.97, green: 0.96, blue: 0.99)
    static let valueLandingBackground = Color(red: 0.93, green: 0.92, blue: 0.96)
}
