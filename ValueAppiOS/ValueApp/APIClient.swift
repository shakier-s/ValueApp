import Foundation

actor APIClient {
    static let shared = APIClient()
    private let baseURL = URL(string: "https://valueapp-api-production.up.railway.app")!
    private let userID: String
    private var authToken: String?

    init() {
        let key = "valueapp.cloud.userID"
        if let current = UserDefaults.standard.string(forKey: key) { userID = current }
        else {
            let value = UUID().uuidString
            UserDefaults.standard.set(value, forKey: key)
            userID = value
        }
    }

    func deals() async throws -> [Deal] { try await request("/v1/deals") }
    func setAuthToken(_ token: String?) { authToken = token }
    func login(email: String, password: String) async throws -> AuthResponse {
        try await request("/v1/auth/login", method: "POST", body: ["email": email, "password": password])
    }
    func register(email: String, password: String, role: AccountRole) async throws -> AuthResponse {
        try await request("/v1/auth/register", method: "POST", body: ["email": email, "password": password, "role": role.rawValue])
    }
    func updateProfile(name: String, email: String) async throws -> AuthUser {
        try await request("/v1/profile", method: "PATCH", body: ["name": name, "email": email])
    }
    func changePassword(currentPassword: String, newPassword: String) async throws {
        let _: APIResult = try await request("/v1/profile/password", method: "PATCH", body: ["currentPassword": currentPassword, "newPassword": newPassword])
    }
    func merchantDeals() async throws -> [Deal] { try await request("/v1/merchant/deals") }
    func merchantSubscription() async throws -> MerchantSubscription { try await request("/v1/merchant/subscription") }
    func updateMerchantSubscription(_ subscription: MerchantSubscription) async throws -> MerchantSubscription {
        try await request("/v1/merchant/subscription", method: "PUT", body: subscription)
    }
    func merchantAnalytics() async throws -> MerchantAnalytics { try await request("/v1/merchant/analytics") }
    func vouchers() async throws -> [Voucher] { try await request("/v1/vouchers") }

    func saveVoucher(dealID: UUID) async throws -> Voucher {
        try await request("/v1/deals/\(dealID)/vouchers", method: "POST")
    }

    func createDeal(_ deal: Deal) async throws -> Deal {
        try await request("/v1/deals", method: "POST", body: deal)
    }

    func setActive(_ active: Bool, dealID: UUID) async throws {
        let _: APIResult = try await request("/v1/deals/\(dealID)/status", method: "PATCH", body: ["isActive": active])
    }

    func updateDeal(_ deal: Deal) async throws -> Deal {
        try await request("/v1/deals/\(deal.id)", method: "PUT", body: deal)
    }

    func deleteDeal(_ dealID: UUID) async throws {
        let _: APIResult = try await request("/v1/deals/\(dealID)", method: "DELETE")
    }

    func redeem(voucherID: UUID, attendantCode: String) async throws {
        let _: APIResult = try await request("/v1/vouchers/\(voucherID)/redeem", method: "POST", body: ["attendantCode": attendantCode])
    }

    private func request<Response: Decodable>(_ path: String, method: String = "GET") async throws -> Response {
        try await request(path, method: method, bodyData: nil)
    }

    private func request<Response: Decodable, Body: Encodable>(_ path: String, method: String, body: Body) async throws -> Response {
        try await request(path, method: method, bodyData: try encoder.encode(body))
    }

    private func request<Response: Decodable>(_ path: String, method: String, bodyData: Data?) async throws -> Response {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userID, forHTTPHeaderField: "X-User-ID")
        if let authToken { request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard 200..<300 ~= http.statusCode else {
            let message = (try? JSONDecoder().decode(APIError.self, from: data).message) ?? "Request failed. Please try again."
            throw APIError(message: message)
        }
        return try decoder.decode(Response.self, from: data)
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

struct APIError: Error, Decodable {
    let message: String
    private enum CodingKeys: String, CodingKey { case message = "error" }
}

private struct APIResult: Decodable { let ok: Bool }
