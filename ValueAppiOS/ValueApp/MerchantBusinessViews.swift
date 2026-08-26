import SwiftUI

struct MerchantBusinessView: View {
    @EnvironmentObject private var store: DealStore
    @State private var draft = MerchantSubscription.basic
    @State private var showingPlans = false
    @State private var showingLocation = false

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(draft.tier.rawValue) plan").font(.title2.bold())
                        Text(planSummary).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(draft.status.capitalized).font(.caption.bold()).padding(.horizontal, 10).padding(.vertical, 6).background(.green.opacity(0.14), in: Capsule()).foregroundStyle(.green)
                }
                Button("Compare plans", systemImage: "rectangle.3.group.fill") { showingPlans = true }
            } header: { Text("Subscription") }

            analyticsSection

            Section("Grow your reach") {
                Toggle("Premium Placement", isOn: $draft.premiumPlacement)
                Text("Give eligible deals featured placement in shopper listings.").font(.caption).foregroundStyle(.secondary)
                Toggle("Advertising", isOn: $draft.advertising)
                Text("Request promoted campaigns across ValueApp placements.").font(.caption).foregroundStyle(.secondary)
            }

            Section("Merchant services") {
                Toggle("Done-for-you service", isOn: $draft.doneForYou)
                Text("Ask the ValueApp team to create and manage deal content and campaigns for you.").font(.caption).foregroundStyle(.secondary)
                if draft.tier == .enterprise { Label("Dedicated support included", systemImage: "person.crop.circle.badge.checkmark") }
            }

            if draft.tier == .enterprise {
                Section("Locations") {
                    ForEach(draft.locations) { location in
                        VStack(alignment: .leading) { Text(location.name).font(.headline); Text(location.address).font(.caption).foregroundStyle(.secondary) }
                    }.onDelete { draft.locations.remove(atOffsets: $0) }
                    Button("Add location", systemImage: "plus") { showingLocation = true }
                }
            }

            Section {
                Button("Save merchant options") { Task { _ = await store.updateSubscription(draft) } }
                    .frame(maxWidth: .infinity)
            } footer: {
                Text("Paid upgrades and add-ons are recorded as requests until billing is confirmed. A ValueApp representative will contact you before charges begin.")
            }
        }
        .navigationTitle("Business")
        .task { draft = store.merchantSubscription; await store.refreshMerchantBusiness(); draft = store.merchantSubscription }
        .onChange(of: store.merchantSubscription.tier) { _, _ in draft = store.merchantSubscription }
        .sheet(isPresented: $showingPlans) { MerchantPlansView(subscription: $draft) }
        .sheet(isPresented: $showingLocation) { AddMerchantLocationView { draft.locations.append($0) } }
        .alert("ValueApp", isPresented: Binding(get: { store.merchantMessage != nil }, set: { if !$0 { store.merchantMessage = nil } })) { Button("OK") { store.merchantMessage = nil } } message: { Text(store.merchantMessage ?? "") }
    }

    @ViewBuilder private var analyticsSection: some View {
        Section(draft.tier.analyticsTitle) {
            if let analytics = store.merchantAnalytics {
                LabeledContent("Active deals", value: "\(analytics.activeDeals)")
                LabeledContent("Total redemptions", value: "\(analytics.redemptions)")
                if entitledTier != .basic {
                    LabeledContent("Coupons saved", value: "\(analytics.couponsSaved)")
                    LabeledContent("Conversion", value: analytics.conversionRate.formatted(.percent.precision(.fractionLength(1))))
                }
                if entitledTier == .enterprise {
                    ForEach(analytics.topDeals.prefix(5)) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title).font(.headline)
                            Text("\(item.saved) saved • \(item.redeemed) redeemed").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } else { ProgressView("Loading analytics…") }
        }
    }

    private var planSummary: String {
        switch draft.tier {
        case .basic: "Up to 3 active deals"
        case .pro: "Unlimited deals and basic analytics"
        case .enterprise: "Advanced analytics, support and locations"
        }
    }

    private var entitledTier: MerchantTier { draft.status == "active" ? draft.tier : .basic }
}

private struct MerchantPlansView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var subscription: MerchantSubscription

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    plan(.basic, features: ["Up to 3 active deals", "Deal and redemption totals"])
                    plan(.pro, features: ["Unlimited active deals", "Basic analytics", "Coupons saved and conversion"])
                    plan(.enterprise, features: ["Everything in Pro", "Advanced deal analytics", "Dedicated support", "Multiple locations"])
                    Text("Premium Placement, Advertising and Done-for-you services are optional add-ons.").font(.footnote).foregroundStyle(.secondary).padding(.horizontal)
                }.padding()
            }.navigationTitle("Merchant plans").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func plan(_ tier: MerchantTier, features: [String]) -> some View {
        Button {
            subscription.tier = tier
            subscription.status = tier == .basic ? "active" : "pending"
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Text(tier.rawValue).font(.title2.bold()); Spacer(); Image(systemName: subscription.tier == tier ? "checkmark.circle.fill" : "circle") }
                ForEach(features, id: \.self) { Label($0, systemImage: "checkmark") }
            }.frame(maxWidth: .infinity, alignment: .leading).padding().background(Color.valueCream, in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain)
    }
}

private struct AddMerchantLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var address = ""
    let save: (MerchantLocation) -> Void
    var body: some View {
        NavigationStack { Form { TextField("Location name", text: $name); TextField("Street address", text: $address, axis: .vertical) }
            .navigationTitle("Add location")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Add") { save(MerchantLocation(name: name, address: address)); dismiss() }.disabled(name.isEmpty || address.isEmpty) } }
        }
    }
}
