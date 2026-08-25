import Foundation

actor APIClient {
    static let shared = APIClient()
    private let baseURL = URL(string: "https://valueapp-api-production.up.railway.app")!
    private let userID: String

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
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw URLError(.badServerResponse) }
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

private struct APIResult: Decodable { let ok: Bool }
