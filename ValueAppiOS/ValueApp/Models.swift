import Foundation

enum DealType: String, Codable, CaseIterable, Identifiable {
    case buyOneGetOne = "Buy 1, Get 1 Free"
    case percentage = "Percentage Off"
    case fixedAmount = "Fixed Amount Off"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .buyOneGetOne: "gift.fill"
        case .percentage: "percent"
        case .fixedAmount: "tag.fill"
        }
    }
}

struct Deal: Identifiable, Codable, Hashable {
    var id = UUID()
    var merchant: String
    var title: String
    var detail: String
    var type: DealType
    var value: Double
    var category: String
    var distance: Double
    var latitude: Double? = nil
    var longitude: Double? = nil
    var expiry: Date
    var quantity: Int
    var redeemed: Int = 0
    var isActive = true
    var isOwned: Bool?

    var offerText: String {
        switch type {
        case .buyOneGetOne: "BOGO"
        case .percentage: "\(Int(value))% OFF"
        case .fixedAmount: "R\(Int(value)) OFF"
        }
    }
}

struct Voucher: Identifiable, Codable {
    enum Status: String, Codable { case saved = "Ready to use", redeemed = "Redeemed" }
    var id = UUID()
    let dealID: UUID
    let code: String
    let savedAt: Date
    var redeemedAt: Date?
    var status: Status = .saved
}
