import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var store: DealStore
    @EnvironmentObject private var proximity: ProximityService
    @Binding var showingRolePicker: Bool
    @State private var query = ""
    @State private var category = "All"
    private let categories = ["All", "Restaurants", "Groceries", "Cafés", "Health"]

    var filtered: [Deal] {
        store.activeDeals.filter { (category == "All" || $0.category == category) && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.merchant.localizedCaseInsensitiveContains(query)) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                header
                search
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack { ForEach(categories, id: \.self) { item in categoryButton(item) } }.padding(.horizontal, 20)
                }.padding(.horizontal, -20)
                HStack { Text("Deals near you").font(.title2.bold()); Spacer(); Text("\(filtered.count) offers").foregroundStyle(.secondary) }
                ForEach(filtered) { deal in NavigationLink(value: deal) { DealCard(deal: deal) }.buttonStyle(.plain) }
            }.padding(20)
        }
        .background(Color.valueCream.ignoresSafeArea())
        .navigationDestination(for: Deal.self) { DealDetailView(deal: $0) }
        .refreshable { await store.refresh(); proximity.evaluateNearbyDeals() }
        .toolbar(.hidden, for: .navigationBar)
    }
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) { Text("Good deals, nearby").font(.largeTitle.bold()); Button { proximity.enableLocation() } label: { Label(proximity.location == nil ? "Use my location" : "Using your location", systemImage: "location.fill").font(.subheadline).foregroundStyle(.secondary) } }
            Spacer(); Button { showingRolePicker = true } label: { Image(systemName: "storefront.fill").padding(12).background(.white).clipShape(Circle()).shadow(color: .black.opacity(0.08), radius: 8) }.accessibilityLabel("Switch account type")
        }
    }
    private var search: some View {
        HStack { Image(systemName: "magnifyingglass").foregroundStyle(.secondary); TextField("Search stores or deals", text: $query) }.padding(14).background(.white).clipShape(RoundedRectangle(cornerRadius: 16))
    }
    private func categoryButton(_ item: String) -> some View {
        Button(item) { category = item }.font(.subheadline.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10).foregroundStyle(category == item ? .white : .primary).background(category == item ? Color.valuePurple : .white).clipShape(Capsule())
    }
}

struct DealCard: View {
    let deal: Deal
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Image(systemName: deal.type.symbol).font(.title2.bold()).foregroundStyle(.white).frame(width: 54, height: 54).background(LinearGradient(colors: [.valuePurple, .valueCoral], startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 4) { Text(deal.merchant).font(.subheadline).foregroundStyle(.secondary); Text(deal.title).font(.headline).foregroundStyle(.primary).lineLimit(2) }
                Spacer()
            }
            HStack { Text(deal.offerText).font(.caption.bold()).foregroundStyle(Color.valuePurple).padding(.horizontal, 10).padding(.vertical, 7).background(Color.valuePurple.opacity(0.1)).clipShape(Capsule()); Spacer(); Label(String(format: "%.1f km", deal.distance), systemImage: "location").font(.caption).foregroundStyle(.secondary) }
        }.padding(16).background(.white).clipShape(RoundedRectangle(cornerRadius: 22)).shadow(color: .black.opacity(0.05), radius: 12, y: 5)
    }
}

struct DealDetailView: View {
    @EnvironmentObject private var store: DealStore
    @AppStorage("valueapp.role") private var role = "guest"
    let deal: Deal
    @State private var showSaved = false
    @State private var showGuestPrompt = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ZStack { LinearGradient(colors: [.valuePurple, .valueCoral], startPoint: .topLeading, endPoint: .bottomTrailing); VStack(spacing: 12) { Image(systemName: deal.type.symbol).font(.system(size: 48, weight: .bold)); Text(deal.offerText).font(.largeTitle.bold()) }.foregroundStyle(.white) }.frame(height: 230).clipShape(RoundedRectangle(cornerRadius: 28))
                VStack(alignment: .leading, spacing: 10) { Text(deal.merchant).foregroundStyle(.secondary); Text(deal.title).font(.title.bold()); Text(deal.detail).foregroundStyle(.secondary).lineSpacing(4) }
                Divider()
                Label("Expires \(deal.expiry.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                Label(String(format: "%.1f km away", deal.distance), systemImage: "location")
                Label("\(deal.quantity - deal.redeemed) vouchers remaining", systemImage: "ticket")
                Button { if role == "guest" { showGuestPrompt = true } else { _ = store.save(deal: deal); showSaved = true } } label: { Label(role == "guest" ? "Continue to save voucher" : (store.voucher(for: deal) == nil ? "Save voucher" : "Voucher saved"), systemImage: role == "guest" ? "person.badge.plus" : (store.voucher(for: deal) == nil ? "plus" : "checkmark")).frame(maxWidth: .infinity).padding().background(Color.valuePurple).foregroundStyle(.white).font(.headline).clipShape(RoundedRectangle(cornerRadius: 16)) }.disabled(role != "guest" && store.voucher(for: deal) != nil)
            }.padding(20)
        }.navigationTitle("Deal").navigationBarTitleDisplayMode(.inline).alert("Voucher saved", isPresented: $showSaved) { Button("Great", role: .cancel) {} } message: { Text("Find it under My Vouchers when you're ready to redeem in store.") }
        .alert("Continue as a shopper", isPresented: $showGuestPrompt) { Button("Not now", role: .cancel) {}; Button("Continue") { role = "shopper" } } message: { Text("Guest mode is browse-only. Continue as a shopper to save and redeem vouchers.") }
    }
}

struct VouchersView: View {
    @EnvironmentObject private var store: DealStore
    var body: some View {
        Group {
            if store.vouchers.isEmpty { ContentUnavailableView("No vouchers yet", systemImage: "ticket", description: Text("Save a deal and it will be ready here.")) }
            else { List(store.vouchers) { voucher in if let deal = store.deals.first(where: { $0.id == voucher.dealID }) { NavigationLink { VoucherView(voucher: voucher, deal: deal) } label: { VStack(alignment: .leading, spacing: 6) { Text(deal.title).font(.headline); Text(deal.merchant); Text(voucher.status.rawValue).font(.caption.bold()).foregroundStyle(voucher.status == .saved ? Color.valuePurple : .secondary) }.padding(.vertical, 6) } } } }
        }.navigationTitle("My Vouchers")
    }
}

struct VoucherView: View {
    @EnvironmentObject private var store: DealStore
    let voucher: Voucher
    let deal: Deal
    @State private var attendantCode = ""
    @State private var showConfirmation = false
    @State private var result: Bool?
    var current: Voucher { store.vouchers.first(where: { $0.id == voucher.id }) ?? voucher }
    var body: some View {
        ScrollView { VStack(spacing: 22) {
            Image(systemName: current.status == .saved ? "ticket.fill" : "checkmark.seal.fill").font(.system(size: 64)).foregroundStyle(current.status == .saved ? Color.valuePurple : .green)
            Text(deal.offerText).font(.largeTitle.bold()); Text(deal.title).font(.title3.bold()).multilineTextAlignment(.center); Text(deal.merchant).foregroundStyle(.secondary)
            VStack(spacing: 8) { Text("VOUCHER CODE").font(.caption.bold()).foregroundStyle(.secondary); Text(current.code).font(.system(.title, design: .monospaced, weight: .bold)) }.frame(maxWidth: .infinity).padding(24).background(Color.valueCream).clipShape(RoundedRectangle(cornerRadius: 20))
            if current.status == .saved { Button("Redeem with store attendant") { showConfirmation = true }.buttonStyle(ValueButton()) } else { Label("Redeemed successfully", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.headline) }
            Text("Only redeem when a store attendant is present. A voucher can be used once.").font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding(24) }.navigationTitle("Voucher").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showConfirmation) { VStack(spacing: 18) { Text("Store verification").font(.title2.bold()); Text("Ask the attendant to enter their 4-digit store code.").foregroundStyle(.secondary).multilineTextAlignment(.center); SecureField("Attendant code", text: $attendantCode).keyboardType(.numberPad).textContentType(.oneTimeCode).padding().background(Color.valueCream).clipShape(RoundedRectangle(cornerRadius: 14)); Button("Confirm redemption") { result = store.redeem(voucherID: voucher.id, attendantCode: attendantCode); if result == true { showConfirmation = false } }.buttonStyle(ValueButton()); if result == false { Text("Enter a valid 4-digit store code.").foregroundStyle(.red).font(.footnote) } }.padding(24).presentationDetents([.height(360)]) }
    }
}

struct ValueButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.frame(maxWidth: .infinity).padding().background(Color.valuePurple.opacity(configuration.isPressed ? 0.75 : 1)).foregroundStyle(.white).font(.headline).clipShape(RoundedRectangle(cornerRadius: 16)) }
}
