import SwiftUI

@main
struct ValueAppApp: App {
    @StateObject private var store = DealStore()

    var body: some Scene {
        WindowGroup {
            LaunchFlowView()
                .environmentObject(store)
                .tint(.valuePurple)
        }
    }
}

extension Color {
    static let valuePurple = Color(red: 0.33, green: 0.18, blue: 0.70)
    static let valueCoral = Color(red: 1.00, green: 0.39, blue: 0.34)
    static let valueCream = Color(red: 0.97, green: 0.96, blue: 0.99)
}
