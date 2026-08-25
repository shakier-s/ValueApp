import SwiftUI

struct MerchantDashboard: View {
    @EnvironmentObject private var store: DealStore
    @Binding var showingRolePicker: Bool
    var totalRedemptions: Int { store.deals.reduce(0) { $0 + $1.redeemed } }
    var body: some View {
        ScrollView { LazyVStack(alignment: .leading, spacing: 18) {
            HStack { VStack(alignment: .leading) { Text("Shop dashboard").font(.largeTitle.bold()); Text("Manage offers and track results").foregroundStyle(.secondary) }; Spacer(); Button { showingRolePicker = true } label: { Image(systemName: "person.2.fill").padding(12).background(Color.valueCream).clipShape(Circle()) } }
            HStack(spacing: 12) { metric("Active deals", value: "\(store.deals.filter(\.isActive).count)", icon: "tag.fill"); metric("Redemptions", value: "\(totalRedemptions)", icon: "checkmark.seal.fill") }
            Text("Your deals").font(.title2.bold())
            ForEach(store.deals) { deal in VStack(alignment: .leading, spacing: 12) { HStack { VStack(alignment: .leading) { Text(deal.title).font(.headline); Text(deal.offerText).font(.caption.bold()).foregroundStyle(Color.valuePurple) }; Spacer(); Toggle("", isOn: Binding(get: { deal.isActive }, set: { _ in store.toggleActive(deal) })).labelsHidden() }; ProgressView(value: Double(deal.redeemed), total: Double(max(deal.quantity, 1))); HStack { Text("\(deal.redeemed) redeemed"); Spacer(); Text("\(deal.quantity - deal.redeemed) remaining") }.font(.caption).foregroundStyle(.secondary) }.padding(16).background(Color.valueCream).clipShape(RoundedRectangle(cornerRadius: 18)) }
        }.padding(20) }.toolbar(.hidden, for: .navigationBar)
    }
    private func metric(_ title: String, value: String, icon: String) -> some View { VStack(alignment: .leading, spacing: 12) { Image(systemName: icon).foregroundStyle(Color.valueCoral); Text(value).font(.largeTitle.bold()); Text(title).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(Color.valueCream).clipShape(RoundedRectangle(cornerRadius: 18)) }
}

struct CreateDealView: View {
    @EnvironmentObject private var store: DealStore
    @State private var merchant = "My Store"
    @State private var title = ""
    @State private var detail = ""
    @State private var type = DealType.buyOneGetOne
    @State private var value = 20.0
    @State private var category = "Restaurants"
    @State private var expiry = Calendar.current.date(byAdding: .day, value: 14, to: .now)!
    @State private var quantity = 50
    @State private var created = false
    var body: some View {
        Form {
            Section("Offer") { TextField("Store name", text: $merchant); TextField("Deal title", text: $title); TextField("Describe the terms", text: $detail, axis: .vertical).lineLimit(3...6); Picker("Deal type", selection: $type) { ForEach(DealType.allCases) { Text($0.rawValue).tag($0) } }; if type != .buyOneGetOne { HStack { Text(type == .percentage ? "Discount %" : "Amount (R)"); Spacer(); TextField("Value", value: $value, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) } } }
            Section("Availability") { Picker("Category", selection: $category) { ForEach(["Restaurants", "Groceries", "Cafés", "Health", "Retail"], id: \.self) { Text($0) } }; DatePicker("Expires", selection: $expiry, in: Date.now..., displayedComponents: .date); Stepper("\(quantity) vouchers", value: $quantity, in: 1...10_000) }
            Section { Button("Publish deal") { store.create(Deal(merchant: merchant, title: title, detail: detail, type: type, value: type == .buyOneGetOne ? 100 : value, category: category, distance: 0, expiry: expiry, quantity: quantity)); title = ""; detail = ""; created = true }.disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || detail.trimmingCharacters(in: .whitespaces).isEmpty) }
        }.navigationTitle("Create a deal").alert("Deal published", isPresented: $created) { Button("Done", role: .cancel) {} } message: { Text("Your offer is now available to nearby shoppers.") }
    }
}

struct RedemptionHistory: View {
    @EnvironmentObject private var store: DealStore
    var redeemed: [Voucher] { store.vouchers.filter { $0.status == .redeemed } }
    var body: some View {
        Group { if redeemed.isEmpty { ContentUnavailableView("No redemptions yet", systemImage: "checkmark.seal", description: Text("Redeemed customer vouchers will appear here.")) } else { List(redeemed) { voucher in VStack(alignment: .leading, spacing: 5) { Text(voucher.code).font(.headline.monospaced()); if let deal = store.deals.first(where: { $0.id == voucher.dealID }) { Text(deal.title) }; if let date = voucher.redeemedAt { Text(date.formatted()).font(.caption).foregroundStyle(.secondary) } } } } }.navigationTitle("Redemptions")
    }
}
