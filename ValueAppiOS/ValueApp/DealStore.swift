import Foundation

@MainActor
final class DealStore: ObservableObject {
    @Published var deals: [Deal] = [] { didSet { persist() } }
    @Published var vouchers: [Voucher] = [] { didSet { persist() } }
    @Published var favourites = Set<UUID>()
    @Published private(set) var isCloudConnected = false

    private let dealsKey = "valueapp.deals.v2"
    private let vouchersKey = "valueapp.vouchers.v2"

    init() {
        if let data = UserDefaults.standard.data(forKey: dealsKey),
           let saved = try? JSONDecoder().decode([Deal].self, from: data) { deals = saved }
        else { deals = Self.samples }
        if let data = UserDefaults.standard.data(forKey: vouchersKey),
           let saved = try? JSONDecoder().decode([Voucher].self, from: data) { vouchers = saved }
        Task { await refresh() }
    }

    var activeDeals: [Deal] { deals.filter { $0.isActive && $0.expiry > .now && $0.redeemed < $0.quantity } }

    func voucher(for deal: Deal) -> Voucher? {
        vouchers.first { $0.dealID == deal.id && $0.status == .saved }
    }

    @discardableResult
    func save(deal: Deal) -> Voucher {
        if let current = voucher(for: deal) { return current }
        let code = String(format: "VAL-%04d", Int.random(in: 1000...9999))
        let voucher = Voucher(dealID: deal.id, code: code, savedAt: .now)
        vouchers.insert(voucher, at: 0)
        Task {
            if let cloudVoucher = try? await APIClient.shared.saveVoucher(dealID: deal.id),
               let index = vouchers.firstIndex(where: { $0.dealID == deal.id && $0.status == .saved }) {
                vouchers[index] = cloudVoucher
                isCloudConnected = true
            }
        }
        return voucher
    }

    func redeem(voucherID: UUID, attendantCode: String) -> Bool {
        guard attendantCode.trimmingCharacters(in: .whitespacesAndNewlines).count >= 4,
              let index = vouchers.firstIndex(where: { $0.id == voucherID && $0.status == .saved }) else { return false }
        vouchers[index].status = .redeemed
        vouchers[index].redeemedAt = .now
        if let dealIndex = deals.firstIndex(where: { $0.id == vouchers[index].dealID }) { deals[dealIndex].redeemed += 1 }
        Task {
            do { try await APIClient.shared.redeem(voucherID: voucherID, attendantCode: attendantCode); isCloudConnected = true }
            catch { await refresh() }
        }
        return true
    }

    func create(_ deal: Deal) {
        deals.insert(deal, at: 0)
        Task {
            if let cloudDeal = try? await APIClient.shared.createDeal(deal) {
                deals.removeAll { $0.id == deal.id }
                deals.insert(cloudDeal, at: 0)
                isCloudConnected = true
            }
        }
    }
    func toggleActive(_ deal: Deal) {
        guard let index = deals.firstIndex(where: { $0.id == deal.id }) else { return }
        deals[index].isActive.toggle()
        let active = deals[index].isActive
        Task { try? await APIClient.shared.setActive(active, dealID: deal.id) }
    }

    func refresh() async {
        do {
            async let cloudDeals = APIClient.shared.deals()
            async let cloudVouchers = APIClient.shared.vouchers()
            let (newDeals, newVouchers) = try await (cloudDeals, cloudVouchers)
            if !newDeals.isEmpty { deals = newDeals }
            vouchers = newVouchers
            isCloudConnected = true
        } catch { isCloudConnected = false }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(deals) { UserDefaults.standard.set(data, forKey: dealsKey) }
        if let data = try? JSONEncoder().encode(vouchers) { UserDefaults.standard.set(data, forKey: vouchersKey) }
    }

    static let samples: [Deal] = [
        Deal(merchant: "Harvest Table", title: "Buy one breakfast, get one free", detail: "Enjoy any two signature breakfasts and only pay for one. Dine-in only.", type: .buyOneGetOne, value: 100, category: "Restaurants", distance: 1.2, expiry: Calendar.current.date(byAdding: .day, value: 12, to: .now)!, quantity: 80, redeemed: 24),
        Deal(merchant: "Fresh Basket", title: "25% off your grocery shop", detail: "Save on a basket of R300 or more. Excludes alcohol and tobacco products.", type: .percentage, value: 25, category: "Groceries", distance: 2.4, expiry: Calendar.current.date(byAdding: .day, value: 8, to: .now)!, quantity: 120, redeemed: 47),
        Deal(merchant: "Urban Grind", title: "R40 off coffee & cake", detail: "The perfect afternoon pick-me-up when you spend R100 or more.", type: .fixedAmount, value: 40, category: "Cafés", distance: 0.7, expiry: Calendar.current.date(byAdding: .day, value: 18, to: .now)!, quantity: 60, redeemed: 12),
        Deal(merchant: "Active Life", title: "Two smoothies for the price of one", detail: "Choose any two regular smoothies from our classic range.", type: .buyOneGetOne, value: 100, category: "Health", distance: 3.1, expiry: Calendar.current.date(byAdding: .day, value: 21, to: .now)!, quantity: 100, redeemed: 39)
    ]
}
