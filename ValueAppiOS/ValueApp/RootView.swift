import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthSession
    @EnvironmentObject private var store: DealStore
    @State private var showingAccountAccess = false

    var body: some View {
        Group {
            switch auth.user?.role {
            case .merchant: MerchantTabs(showingRolePicker: $showingAccountAccess)
            case .shopper: ShopperTabs(showingRolePicker: $showingAccountAccess)
            case nil: GuestTabs(showingAccountAccess: $showingAccountAccess)
            }
        }
        .sheet(isPresented: $showingAccountAccess) { AccountAccessView().presentationDetents([.large]) }
        .task { if auth.user == nil { store.resetForGuest() } }
        .onChange(of: auth.user?.id) { _, userID in
            if userID == nil { store.resetForGuest() }
            else { Task { await store.refresh() } }
        }
    }
}

struct AccountAccessView: View {
    @EnvironmentObject private var auth: AuthSession
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var role = AccountRole.shopper
    @State private var creatingAccount = false

    var body: some View {
        if let user = auth.user {
            NavigationStack {
                List {
                    Section("Signed in") { LabeledContent("Email", value: user.email); LabeledContent("Account", value: user.role.title) }
                    Section { Button("Sign out", role: .destructive) { auth.signOut(); dismiss() } }
                }
                .navigationTitle("Account")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            }
        } else {
        NavigationStack {
            Form {
                Section("Continue as") {
                    Picker("Account type", selection: $role) {
                        ForEach(AccountRole.allCases) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented)
                }
                Section("Account") {
                    TextField("Email address", text: $email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Password", text: $password).textContentType(creatingAccount ? .newPassword : .password)
                    if creatingAccount { Text("Use at least 8 characters.").font(.footnote).foregroundStyle(.secondary) }
                }
                if let error = auth.errorMessage { Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) } }
                Section {
                    Button {
                        Task {
                            let success = creatingAccount ? await auth.createAccount(email: email, password: password, role: role) : await auth.signIn(email: email, password: password)
                            if success { dismiss() }
                        }
                    } label: { HStack { Spacer(); if auth.isWorking { ProgressView() } else { Text(creatingAccount ? "Create account" : "Sign in").bold() }; Spacer() } }
                    .disabled(!isValid || auth.isWorking)
                    Button(creatingAccount ? "Already have an account? Sign in" : "New to ValueApp? Create an account") { creatingAccount.toggle(); auth.errorMessage = nil }.frame(maxWidth: .infinity, alignment: .center)
                }
                Section {
                    Button("Continue browsing as guest") { dismiss() }.frame(maxWidth: .infinity, alignment: .center)
                } footer: { Text("Guests can browse offers. Shoppers can save vouchers, while shop owners can manage only their own deals.") }
            }
            .navigationTitle(creatingAccount ? "Create account" : "Welcome back")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        }
    }

    private var isValid: Bool { email.contains("@") && email.contains(".") && password.count >= 8 }
}

private struct GuestTabs: View {
    @Binding var showingAccountAccess: Bool
    var body: some View {
        TabView {
            NavigationStack { DiscoverView(showingRolePicker: $showingAccountAccess) }.tabItem { Label("Discover", systemImage: "sparkles") }
            NavigationStack { GuestProfile(showingAccountAccess: $showingAccountAccess) }.tabItem { Label("Guest", systemImage: "person.crop.circle.dashed") }
        }
    }
}

private struct GuestProfile: View {
    @Binding var showingAccountAccess: Bool
    var body: some View {
        List {
            Section { Label("Browsing as guest", systemImage: "eye.fill"); Text("Explore nearby offers without saving vouchers or creating redemption activity.").font(.footnote).foregroundStyle(.secondary) }
            Section { Button("Sign in or create an account") { showingAccountAccess = true } }
        }.navigationTitle("Guest mode")
    }
}

private struct ShopperTabs: View {
    @Binding var showingRolePicker: Bool
    var body: some View {
        TabView {
            NavigationStack { DiscoverView(showingRolePicker: $showingRolePicker) }.tabItem { Label("Discover", systemImage: "sparkles") }
            NavigationStack { VouchersView() }.tabItem { Label("My Vouchers", systemImage: "ticket.fill") }
            NavigationStack { ShopperProfile() }.tabItem { Label("Profile", systemImage: "person.fill") }
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
    @EnvironmentObject private var auth: AuthSession
    @EnvironmentObject private var proximity: ProximityService
    var body: some View {
        List {
            Section { Label(auth.user?.email ?? "ValueApp Shopper", systemImage: "person.crop.circle.fill") }
            Section("Location & nearby deals") {
                Button { proximity.enableLocation() } label: { Label(locationLabel, systemImage: "location.fill") }
                Toggle("Notify me about nearby deals", isOn: Binding(get: { proximity.alertsEnabled }, set: { enabled in Task { await proximity.setNearbyAlerts(enabled) } }))
                if proximity.alertsEnabled { VStack(alignment: .leading) { Text("Alert distance: \(Int(proximity.radiusKilometres)) km"); Slider(value: $proximity.radiusKilometres, in: 1...20, step: 1) } }
                Text("Location and notifications are optional and can be changed in iPhone Settings.").font(.footnote).foregroundStyle(.secondary)
            }
            Section { Label("Help & Support", systemImage: "questionmark.circle.fill") }
            Section { Button("Sign out", role: .destructive) { auth.signOut() } }
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
