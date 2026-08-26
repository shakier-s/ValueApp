import SwiftUI

struct MerchantDashboard: View {
    @EnvironmentObject private var store: DealStore
    @Binding var showingRolePicker: Bool
    @State private var editingDeal: Deal?
    @State private var deletingDeal: Deal?
    var totalRedemptions: Int { store.merchantDeals.reduce(0) { $0 + $1.redeemed } }
    var body: some View {
        ScrollView { LazyVStack(alignment: .leading, spacing: 18) {
            HStack { VStack(alignment: .leading) { Text("Shop dashboard").font(.largeTitle.bold()); Text("Manage offers and track results").foregroundStyle(.secondary) }; Spacer(); Button { showingRolePicker = true } label: { Image(systemName: "person.2.fill").padding(12).background(Color.valueCream).clipShape(Circle()) } }
            HStack(spacing: 12) { metric("Active deals", value: "\(store.merchantDeals.filter(\.isActive).count)", icon: "tag.fill"); metric("Redemptions", value: "\(totalRedemptions)", icon: "checkmark.seal.fill") }
            Text("Your deals").font(.title2.bold())
            if store.merchantDeals.isEmpty { ContentUnavailableView("No deals yet", systemImage: "tag", description: Text("Create your first offer from the Create tab.")) }
            ForEach(store.merchantDeals) { deal in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(deal.title).font(.headline)
                            Text(deal.offerText).font(.caption.bold()).foregroundStyle(Color.valuePurple)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary)
                        Toggle("", isOn: Binding(get: { deal.isActive }, set: { _ in store.toggleActive(deal) })).labelsHidden()
                    }
                    ProgressView(value: Double(deal.redeemed), total: Double(max(deal.quantity, 1)))
                    HStack { Text("\(deal.redeemed) redeemed"); Spacer(); Text("\(deal.quantity - deal.redeemed) remaining") }.font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Open & edit", systemImage: "pencil") { editingDeal = deal }
                        Spacer()
                        Button("Delete", systemImage: "trash", role: .destructive) { deletingDeal = deal }
                    }.buttonStyle(.bordered)
                }
                .padding(16)
                .background(Color.valueCream)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .contentShape(RoundedRectangle(cornerRadius: 18))
                .onTapGesture { editingDeal = deal }
                .accessibilityHint("Opens this deal for editing")
            }
        }.padding(20) }.toolbar(.hidden, for: .navigationBar)
        .sheet(item: $editingDeal) { EditDealView(deal: $0) }
        .alert("Delete this deal?", isPresented: Binding(get: { deletingDeal != nil }, set: { if !$0 { deletingDeal = nil } })) { Button("Cancel", role: .cancel) { deletingDeal = nil }; Button("Delete", role: .destructive) { if let deal = deletingDeal { store.delete(deal) }; deletingDeal = nil } } message: { Text("This removes the deal and prevents new coupon saves.") }
    }
    private func metric(_ title: String, value: String, icon: String) -> some View { VStack(alignment: .leading, spacing: 12) { Image(systemName: icon).foregroundStyle(Color.valueCoral); Text(value).font(.largeTitle.bold()); Text(title).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(Color.valueCream).clipShape(RoundedRectangle(cornerRadius: 18)) }
}

private struct EditDealView: View {
    @EnvironmentObject private var store: DealStore
    @EnvironmentObject private var proximity: ProximityService
    @Environment(\.dismiss) private var dismiss
    @State private var deal: Deal
    init(deal: Deal) { _deal = State(initialValue: deal) }
    var body: some View {
        NavigationStack { Form {
            Section("Offer") { TextField("Store name", text: $deal.merchant); TextField("Deal title", text: $deal.title); TextField("Describe the terms", text: $deal.detail, axis: .vertical).lineLimit(3...6); Picker("Deal type", selection: $deal.type) { ForEach(DealType.allCases) { Text($0.rawValue).tag($0) } }; if deal.type != .buyOneGetOne { TextField("Discount value", value: $deal.value, format: .number).keyboardType(.decimalPad) } }
            Section("Availability") { Picker("Category", selection: $deal.category) { ForEach(["Restaurants", "Groceries", "Cafés", "Health", "Retail"], id: \.self) { Text($0) } }; DatePicker("Expires", selection: $deal.expiry, in: Date.now..., displayedComponents: .date); Stepper("\(deal.quantity) coupons", value: $deal.quantity, in: max(1, deal.redeemed)...10_000); Button("Update shop to current location", systemImage: "mappin.and.ellipse") { proximity.enableLocation(); if let coordinate = proximity.location?.coordinate { deal.latitude = coordinate.latitude; deal.longitude = coordinate.longitude } } }
        }.navigationTitle("Edit deal").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { if deal.type == .buyOneGetOne { deal.value = 100 }; store.update(deal); dismiss() }.disabled(deal.title.trimmingCharacters(in: .whitespaces).isEmpty || deal.detail.trimmingCharacters(in: .whitespaces).isEmpty) } } }
    }
}

struct CreateDealView: View {
    @EnvironmentObject private var store: DealStore
    @EnvironmentObject private var proximity: ProximityService
    @State private var merchant = "My Store"
    @State private var title = ""
    @State private var detail = ""
    @State private var type = DealType.buyOneGetOne
    @State private var value = 20.0
    @State private var category = "Restaurants"
    @State private var expiry = Calendar.current.date(byAdding: .day, value: 14, to: .now)!
    @State private var quantity = 50
    @State private var created = false
    @State private var showingLimit = false
    let showMyDeals: () -> Void

    init(showMyDeals: @escaping () -> Void = {}) {
        self.showMyDeals = showMyDeals
    }

    var body: some View {
        Form {
            Section("Offer") { TextField("Store name", text: $merchant); TextField("Deal title", text: $title); TextField("Describe the terms", text: $detail, axis: .vertical).lineLimit(3...6); Picker("Deal type", selection: $type) { ForEach(DealType.allCases) { Text($0.rawValue).tag($0) } }; if type != .buyOneGetOne { HStack { Text(type == .percentage ? "Discount %" : "Amount (R)"); Spacer(); TextField("Value", value: $value, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) } } }
            Section("Availability") { Picker("Category", selection: $category) { ForEach(["Restaurants", "Groceries", "Cafés", "Health", "Retail"], id: \.self) { Text($0) } }; DatePicker("Expires", selection: $expiry, in: Date.now..., displayedComponents: .date); Stepper("\(quantity) coupons", value: $quantity, in: 1...10_000); Button(proximity.location == nil ? "Use current shop location" : "Current shop location added", systemImage: "mappin.and.ellipse") { proximity.enableLocation() } }
            if !store.canCreateDeal { Section { Label("Basic allows up to 3 active deals. Deactivate a deal or upgrade to Pro for unlimited deals.", systemImage: "info.circle.fill").foregroundStyle(Color.valuePurple) } }
            Section { Button("Publish deal") { guard store.canCreateDeal else { showingLimit = true; return }; store.create(Deal(merchant: merchant, title: title, detail: detail, type: type, value: type == .buyOneGetOne ? 100 : value, category: category, distance: 0, latitude: proximity.location?.coordinate.latitude, longitude: proximity.location?.coordinate.longitude, expiry: expiry, quantity: quantity)); title = ""; detail = ""; created = true }.disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || detail.trimmingCharacters(in: .whitespaces).isEmpty) }
        }
        .navigationTitle("Create a deal")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("My Deals", systemImage: "chevron.left") { showMyDeals() }
            }
        }
        .alert("Deal published", isPresented: $created) {
            Button("View My Deals") { showMyDeals() }
            Button("Create Another", role: .cancel) {}
        } message: {
            Text("Your offer is now available to nearby shoppers. You can open it from My Deals to edit it.")
        }
        .alert("Active deal limit reached", isPresented: $showingLimit) { Button("OK", role: .cancel) {} } message: { Text("Basic includes 3 active deals. Upgrade from the Business tab for unlimited deals.") }
    }
}

struct RedemptionHistory: View {
    @EnvironmentObject private var store: DealStore
    var redeemed: [Voucher] { store.vouchers.filter { $0.status == .redeemed } }
    var body: some View {
        Group { if redeemed.isEmpty { ContentUnavailableView("No redemptions yet", systemImage: "checkmark.seal", description: Text("Redeemed customer coupons will appear here.")) } else { List(redeemed) { voucher in VStack(alignment: .leading, spacing: 5) { Text(voucher.code).font(.headline.monospaced()); if let deal = store.deals.first(where: { $0.id == voucher.dealID }) { Text(deal.title) }; if let date = voucher.redeemedAt { Text(date.formatted()).font(.caption).foregroundStyle(.secondary) } } } } }.navigationTitle("Redemptions")
    }
}
