import Foundation
import Security

enum GatewayCredentials: Equatable {
    case token(String)
    case password(String)
}

protocol CredentialStorage {
    func save(_ value: Data, account: String) throws
    func load(account: String) throws -> Data?
}

final class KeychainCredentialStorage: CredentialStorage {
    private let service = "ai.openclaw.ios.dashboard"

    func save(_ value: Data, account: String) throws {
        let query = self.query(account: account)
        let attributes: [String: Any] = [kSecValueData as String: value]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecSuccess {
            return
        }

        if status == errSecItemNotFound {
            var insertQuery = query
            insertQuery[kSecValueData as String] = value
            let insertStatus = SecItemAdd(insertQuery as CFDictionary, nil)
            guard insertStatus == errSecSuccess else {
                throw KeychainStorageError.unexpectedStatus(insertStatus)
            }
            return
        }

        throw KeychainStorageError.unexpectedStatus(status)
    }

    func load(account: String) throws -> Data? {
        var query = self.query(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainStorageError.unexpectedStatus(status)
        }

        return result as? Data
    }

    private func query(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: account,
        ]
    }
}

enum KeychainStorageError: Error {
    case unexpectedStatus(OSStatus)
}

final class InMemoryCredentialStorage: CredentialStorage {
    private var values: [String: Data] = [:]

    func save(_ value: Data, account: String) throws {
        self.values[account] = value
    }

    func load(account: String) throws -> Data? {
        self.values[account]
    }
}

final class GatewayCredentialsStore {
    private let storage: CredentialStorage

    init(storage: CredentialStorage) {
        self.storage = storage
    }

    func save(_ credentials: GatewayCredentials, for endpoint: GatewayEndpoint) throws {
        let rawValue: String
        switch credentials {
        case let .token(value):
            rawValue = "token:\(value)"
        case let .password(value):
            rawValue = "password:\(value)"
        }

        try self.storage.save(Data(rawValue.utf8), account: endpoint.httpBaseURL.absoluteString)
    }

    func load(for endpoint: GatewayEndpoint) throws -> GatewayCredentials? {
        guard
            let data = try self.storage.load(account: endpoint.httpBaseURL.absoluteString),
            let rawValue = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        if rawValue.hasPrefix("token:") {
            return .token(String(rawValue.dropFirst("token:".count)))
        }

        if rawValue.hasPrefix("password:") {
            return .password(String(rawValue.dropFirst("password:".count)))
        }

        return nil
    }
}
