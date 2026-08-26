import Foundation
import Security

enum AccountRole: String, Codable, CaseIterable, Identifiable {
    case shopper
    case merchant

    var id: String { rawValue }
    var title: String { self == .shopper ? "Shopper" : "Shop owner" }
}

struct AuthUser: Codable {
    let id: UUID
    let email: String
    let name: String?
    let role: AccountRole
}

struct AuthResponse: Codable {
    let token: String
    let user: AuthUser
}

@MainActor
final class AuthSession: ObservableObject {
    @Published private(set) var user: AuthUser?
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    private let tokenKey = "com.datawiz.valueapp.auth-token"
    private let userKey = "valueapp.auth.user"

    init() {
        if let data = UserDefaults.standard.data(forKey: userKey) {
            user = try? JSONDecoder().decode(AuthUser.self, from: data)
        }
        Task { await APIClient.shared.setAuthToken(Keychain.read(tokenKey)) }
    }

    func signIn(email: String, password: String) async -> Bool {
        await authenticate { try await APIClient.shared.login(email: email, password: password) }
    }

    func createAccount(email: String, password: String, role: AccountRole) async -> Bool {
        await authenticate { try await APIClient.shared.register(email: email, password: password, role: role) }
    }

    func updateProfile(name: String, email: String) async -> Bool {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let updatedUser = try await APIClient.shared.updateProfile(name: name, email: email)
            user = updatedUser
            persist(updatedUser)
            return true
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = "Unable to update your profile. Please try again."
        }
        return false
    }

    func changePassword(currentPassword: String, newPassword: String) async -> Bool {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await APIClient.shared.changePassword(currentPassword: currentPassword, newPassword: newPassword)
            return true
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = "Unable to change your password. Please try again."
        }
        return false
    }

    func signOut() {
        user = nil
        errorMessage = nil
        UserDefaults.standard.removeObject(forKey: userKey)
        Keychain.delete(tokenKey)
        Task { await APIClient.shared.setAuthToken(nil) }
    }

    private func authenticate(_ operation: () async throws -> AuthResponse) async -> Bool {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let response = try await operation()
            user = response.user
            persist(response.user)
            Keychain.save(response.token, key: tokenKey)
            await APIClient.shared.setAuthToken(response.token)
            return true
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = "Unable to connect. Please try again."
        }
        return false
    }

    private func persist(_ user: AuthUser) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }
}

private enum Keychain {
    static func save(_ value: String, key: String) {
        delete(key)
        let data = Data(value.utf8)
        SecItemAdd([kSecClass: kSecClassGenericPassword, kSecAttrAccount: key, kSecValueData: data] as CFDictionary, nil)
    }

    static func read(_ key: String) -> String? {
        let query = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key, kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne] as CFDictionary
        var result: AnyObject?
        guard SecItemCopyMatching(query, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrAccount: key] as CFDictionary)
    }
}
