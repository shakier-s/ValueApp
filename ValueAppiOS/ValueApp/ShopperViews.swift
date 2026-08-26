import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var store: DealStore
    @EnvironmentObject private var proximity: ProximityService
    @EnvironmentObject private var auth: AuthSession
    @Binding var showingRolePicker: Bool
    @State private var query = ""
    @State private var category = "All"
    private let categories = ["All", "Restaurants", "Groceries", "Cafés", "Health"]

    private var welcomeName: String {
        if let name = auth.user?.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        guard let email = auth.user?.email,
              let accountName = email.split(separator: "@").first else { return "Guest" }
        let words = accountName.split(whereSeparator: { $0 == "." || $0 == "_" || $0 == "-" })
        let name = words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
        return name.isEmpty ? "Shopper" : name
    }

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
        .background(Color.valueLandingBackground.ignoresSafeArea())
        .navigationDestination(for: Deal.self) { DealDetailView(deal: $0) }
        .refreshable { await store.refresh(); proximity.evaluateNearbyDeals() }
        .toolbar(.hidden, for: .navigationBar)
    }
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("Welcome, \(welcomeName)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.valuePurple)
                Text("ValueApp").font(.largeTitle.bold())
                Button { proximity.enableLocation() } label: { Label(proximity.location == nil ? "Use my location" : "Using your location", systemImage: "location.fill").font(.subheadline).foregroundStyle(.secondary) }
            }
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
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text(deal.merchant).font(.subheadline).foregroundStyle(.secondary); if deal.isFeatured == true { Label("Featured", systemImage: "star.fill").font(.caption2.bold()).foregroundStyle(Color.valueCoral) } }
                    Text(deal.title).font(.headline).foregroundStyle(.primary).lineLimit(2)
                }
                Spacer()
            }
            HStack { Text(deal.offerText).font(.caption.bold()).foregroundStyle(Color.valuePurple).padding(.horizontal, 10).padding(.vertical, 7).background(Color.valuePurple.opacity(0.1)).clipShape(Capsule()); Spacer(); Label(String(format: "%.1f km", deal.distance), systemImage: "location").font(.caption).foregroundStyle(.secondary) }
            HStack(spacing: 8) {
                Image(systemName: "ticket.fill").foregroundStyle(Color.valueCoral)
                Text("\(max(deal.quantity - deal.redeemed, 0)) of \(deal.quantity) coupons remaining")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }.padding(16).background(.white).clipShape(RoundedRectangle(cornerRadius: 22)).shadow(color: .black.opacity(0.05), radius: 12, y: 5)
    }
}

struct DealDetailView: View {
    @EnvironmentObject private var store: DealStore
    @EnvironmentObject private var auth: AuthSession
    let deal: Deal
    @State private var showSaved = false
    @State private var showGuestPrompt = false
    @State private var showAccountAccess = false
    private var savedCoupons: [Voucher] { store.coupons(for: deal) }
    private var canSaveCoupon: Bool { store.canSaveCoupon(for: deal) }

    private var voucherButtonTitle: String {
        if savedCoupons.count >= 10 { return "Coupon limit reached (10/10)" }
        if savedCoupons.isEmpty { return "Save coupon" }
        return "Save another coupon (\(savedCoupons.count)/10)"
    }

    private var voucherButtonIcon: String {
        savedCoupons.count >= 10 ? "checkmark.circle.fill" : "plus"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ZStack { LinearGradient(colors: [.valuePurple, .valueCoral], startPoint: .topLeading, endPoint: .bottomTrailing); VStack(spacing: 12) { Image(systemName: deal.type.symbol).font(.system(size: 48, weight: .bold)); Text(deal.offerText).font(.largeTitle.bold()) }.foregroundStyle(.white) }.frame(height: 230).clipShape(RoundedRectangle(cornerRadius: 28))
                VStack(alignment: .leading, spacing: 10) { Text(deal.merchant).foregroundStyle(.secondary); Text(deal.title).font(.title.bold()); Text(deal.detail).foregroundStyle(.secondary).lineSpacing(4) }
                Divider()
                Label("Expires \(deal.expiry.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                Label(String(format: "%.1f km away", deal.distance), systemImage: "location")
                Label("\(max(0, deal.quantity - deal.redeemed)) coupons remaining", systemImage: "ticket")
                Button {
                    if auth.user?.role != .shopper {
                        showGuestPrompt = true
                    } else if canSaveCoupon {
                        _ = store.save(deal: deal)
                        showSaved = true
                    }
                } label: {
                    Label(
                        auth.user?.role == .shopper ? voucherButtonTitle : "Sign in to save coupon",
                        systemImage: auth.user?.role == .shopper ? voucherButtonIcon : "person.badge.plus"
                    )
                    .frame(maxWidth: .infinity).padding()
                    .background(savedCoupons.count >= 10 ? Color.secondary : Color.valuePurple)
                    .foregroundStyle(.white).font(.headline).clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(auth.user?.role == .shopper && !canSaveCoupon)
            }.padding(20)
        }.navigationTitle("Deal").navigationBarTitleDisplayMode(.inline).alert("Coupon saved", isPresented: $showSaved) { Button("Great", role: .cancel) {} } message: { Text("This coupon has its own code and can be redeemed individually under My Coupons.") }
        .alert("Shopper account required", isPresented: $showGuestPrompt) { Button("Not now", role: .cancel) {}; Button("Sign in") { showAccountAccess = true } } message: { Text("Guest mode is browse-only. Sign in or create a shopper account to save and redeem coupons.") }
        .sheet(isPresented: $showAccountAccess) { AccountAccessView().presentationDetents([.large]) }
    }
}

struct CouponsView: View {
    @EnvironmentObject private var store: DealStore
    var body: some View {
        Group {
            if store.vouchers.isEmpty { ContentUnavailableView("No coupons yet", systemImage: "ticket", description: Text("Save a deal and its coupon will be ready here.")) }
            else { List(store.vouchers) { voucher in if let deal = store.deals.first(where: { $0.id == voucher.dealID }) { NavigationLink { CouponView(voucher: voucher, deal: deal) } label: { VStack(alignment: .leading, spacing: 6) { Text(deal.title).font(.headline); Text(deal.merchant); Text(voucher.status.rawValue).font(.caption.bold()).foregroundStyle(voucher.status == .saved ? Color.valuePurple : .secondary) }.padding(.vertical, 6) } } } }
        }.navigationTitle("My Coupons")
    }
}

struct RedeemedCouponsView: View {
    @EnvironmentObject private var store: DealStore

    private var redeemedVouchers: [Voucher] {
        store.vouchers
            .filter { $0.status == .redeemed }
            .sorted { ($0.redeemedAt ?? $0.savedAt) > ($1.redeemedAt ?? $1.savedAt) }
    }

    var body: some View {
        Group {
            if redeemedVouchers.isEmpty {
                ContentUnavailableView(
                    "No redeemed coupons",
                    systemImage: "checkmark.seal",
                    description: Text("Coupons you redeem will appear here as your personal savings history.")
                )
            } else {
                List(redeemedVouchers) { voucher in
                    if let deal = store.deals.first(where: { $0.id == voucher.dealID }) {
                        NavigationLink { CouponView(voucher: voucher, deal: deal) } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.title2).foregroundStyle(.green)
                                    .frame(width: 42, height: 42)
                                    .background(.green.opacity(0.12), in: Circle())
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(deal.title).font(.headline).lineLimit(2)
                                    Text(deal.merchant).foregroundStyle(.secondary)
                                    HStack {
                                        Text(voucher.code).font(.caption.monospaced().bold())
                                        Spacer()
                                        Text((voucher.redeemedAt ?? voucher.savedAt).formatted(date: .abbreviated, time: .shortened))
                                    }.font(.caption).foregroundStyle(.secondary)
                                }
                            }.padding(.vertical, 6)
                        }
                    }
                }
            }
        }
        .navigationTitle("Redeemed")
        .refreshable { await store.refresh() }
    }
}

struct CouponView: View {
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
            VStack(spacing: 8) { Text("COUPON CODE").font(.caption.bold()).foregroundStyle(.secondary); Text(current.code).font(.system(.title, design: .monospaced, weight: .bold)) }.frame(maxWidth: .infinity).padding(24).background(Color.valueCream).clipShape(RoundedRectangle(cornerRadius: 20))
            if current.status == .saved { Button("Redeem with store attendant") { showConfirmation = true }.buttonStyle(ValueButton()) } else { Label("Redeemed successfully", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.headline) }
            Text("Only redeem when a store attendant is present. A coupon can be used once.").font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding(24) }.navigationTitle("Coupon").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showConfirmation) { VStack(spacing: 18) { Text("Store verification").font(.title2.bold()); Text("Ask the attendant to enter their 4-digit store code.").foregroundStyle(.secondary).multilineTextAlignment(.center); SecureField("Attendant code", text: $attendantCode).keyboardType(.numberPad).textContentType(.oneTimeCode).padding().background(Color.valueCream).clipShape(RoundedRectangle(cornerRadius: 14)); Button("Confirm redemption") { result = store.redeem(voucherID: voucher.id, attendantCode: attendantCode); if result == true { showConfirmation = false } }.buttonStyle(ValueButton()); if result == false { Text("Enter a valid 4-digit store code.").foregroundStyle(.red).font(.footnote) } }.padding(24).presentationDetents([.height(360)]) }
    }
}

struct ValueButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.frame(maxWidth: .infinity).padding().background(Color.valuePurple.opacity(configuration.isPressed ? 0.75 : 1)).foregroundStyle(.white).font(.headline).clipShape(RoundedRectangle(cornerRadius: 16)) }
}
