import SwiftUI

struct RootView: View {
    @AppStorage("valueapp.role") private var role = "guest"
    @State private var showingRolePicker = false

    var body: some View {
        Group {
            if role == "merchant" { MerchantTabs(showingRolePicker: $showingRolePicker) }
            else if role == "guest" { GuestTabs(role: $role, showingRolePicker: $showingRolePicker) }
            else { ShopperTabs(showingRolePicker: $showingRolePicker) }
        }
        .sheet(isPresented: $showingRolePicker) {
            RolePicker(role: $role)
                .presentationDetents([.height(390)])
        }
    }
}

private struct RolePicker: View {
    @Binding var role: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(.secondary.opacity(0.3)).frame(width: 42, height: 5)
            Image(systemName: "person.2.badge.gearshape.fill").font(.system(size: 38)).foregroundStyle(Color.valuePurple)
            Text("How are you using ValueApp?").font(.title2.bold())
            Text("Switch any time. Your deals and vouchers stay right here.").multilineTextAlignment(.center).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                roleButton("Browse as guest", icon: "eye.fill", value: "guest")
                roleButton("Shop deals", icon: "bag.fill", value: "shopper")
                roleButton("Manage deals", icon: "storefront.fill", value: "merchant")
            }
        }.padding(24)
    }
    private func roleButton(_ title: String, icon: String, value: String) -> some View {
        Button { role = value; dismiss() } label: {
            VStack(spacing: 10) { Image(systemName: icon).font(.title2); Text(title).font(.subheadline.bold()) }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(role == value ? Color.valuePurple : Color.valueCream)
                .foregroundStyle(role == value ? .white : Color.valuePurple).clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
}

private struct GuestTabs: View {
    @Binding var role: String
    @Binding var showingRolePicker: Bool
    var body: some View {
        TabView {
            NavigationStack { DiscoverView(showingRolePicker: $showingRolePicker) }.tabItem { Label("Discover", systemImage: "sparkles") }
            NavigationStack { GuestProfile(role: $role, showingRolePicker: $showingRolePicker) }.tabItem { Label("Guest", systemImage: "person.crop.circle.dashed") }
        }
    }
}

private struct GuestProfile: View {
    @Binding var role: String
    @Binding var showingRolePicker: Bool
    var body: some View {
        List {
            Section { Label("Browsing as guest", systemImage: "eye.fill"); Text("Explore nearby offers without saving vouchers or creating redemption activity.").font(.footnote).foregroundStyle(.secondary) }
            Section { Button("Continue as a shopper") { role = "shopper" }; Button("Choose another mode") { showingRolePicker = true } }
        }.navigationTitle("Guest mode")
    }
}

private struct ShopperTabs: View {
    @Binding var showingRolePicker: Bool
    var body: some View {
        TabView {
            NavigationStack { DiscoverView(showingRolePicker: $showingRolePicker) }.tabItem { Label("Discover", systemImage: "sparkles") }
            NavigationStack { VouchersView() }.tabItem { Label("My Vouchers", systemImage: "ticket.fill") }
            NavigationStack { ShopperProfile(showingRolePicker: $showingRolePicker) }.tabItem { Label("Profile", systemImage: "person.fill") }
        }
    }
}

private struct MerchantTabs: View {
    @Binding var showingRolePicker: Bool
    var body: some View {
        TabView {
            NavigationStack { MerchantDashboard(showingRolePicker: $showingRolePicker) }.tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
            NavigationStack { CreateDealView() }.tabItem { Label("Create", systemImage: "plus.circle.fill") }
            NavigationStack { RedemptionHistory() }.tabItem { Label("Redemptions", systemImage: "checkmark.seal.fill") }
        }
    }
}

private struct ShopperProfile: View {
    @Binding var showingRolePicker: Bool
    @EnvironmentObject private var proximity: ProximityService
    var body: some View {
        List {
            Section { Label("ValueApp Shopper", systemImage: "person.crop.circle.fill") }
            Section("Location & nearby deals") {
                Button { proximity.enableLocation() } label: { Label(locationLabel, systemImage: "location.fill") }
                Toggle("Notify me about nearby deals", isOn: Binding(get: { proximity.alertsEnabled }, set: { enabled in Task { await proximity.setNearbyAlerts(enabled) } }))
                if proximity.alertsEnabled { VStack(alignment: .leading) { Text("Alert distance: \(Int(proximity.radiusKilometres)) km"); Slider(value: $proximity.radiusKilometres, in: 1...20, step: 1) } }
                Text("Location and notifications are optional and can be changed in iPhone Settings.").font(.footnote).foregroundStyle(.secondary)
            }
            Section { Label("Help & Support", systemImage: "questionmark.circle.fill") }
            Section { Button("Switch to shop owner") { showingRolePicker = true } }
        }.navigationTitle("Profile")
    }
    private var locationLabel: String {
        switch proximity.authorization {
        case .authorizedAlways, .authorizedWhenInUse: "Location enabled"
        case .denied, .restricted: "Location access unavailable"
        default: "Enable location"
        }
    }
}
