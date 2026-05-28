import Foundation
import Observation

/// Manages saved gateway connections using UserDefaults.
@Observable
final class GatewayConnectionStore: @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let savedConnectionsKey = "savedGatewayConnections"
    private let lastConnectedIdKey = "lastConnectedGatewayId"
    private let hasCompletedOnboardingKey = "hasCompletedGatewayOnboarding"

    private(set) var savedConnections: [SavedGateway] = []

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    // MARK: - CRUD

    func save(_ connection: SavedGateway) {
        if let index = savedConnections.firstIndex(where: { $0.id == connection.id }) {
            savedConnections[index] = connection
        } else {
            savedConnections.append(connection)
        }
        persist()
    }

    func delete(id: UUID) {
        savedConnections.removeAll { $0.id == id }
        if lastConnectedId == id {
            lastConnectedId = nil
        }
        persist()
    }

    func updateLastConnected(id: UUID) {
        guard let index = savedConnections.firstIndex(where: { $0.id == id }) else { return }
        savedConnections[index].lastConnectedAt = Date()
        if lastConnectedId != id {
            lastConnectedId = id
        }
        persist()
    }

    func allConnections() -> [SavedGateway] {
        savedConnections
    }

    func connection(id: UUID) -> SavedGateway? {
        savedConnections.first { $0.id == id }
    }

    func lastConnection() -> SavedGateway? {
        guard let id = lastConnectedId else { return nil }
        return connection(id: id)
    }

    // MARK: - Last Connected

    var lastConnectedId: UUID? {
        get {
            guard let uuidString = userDefaults.string(forKey: lastConnectedIdKey) else { return nil }
            return UUID(uuidString: uuidString)
        }
        set {
            if let newId = newValue {
                userDefaults.set(newId.uuidString, forKey: lastConnectedIdKey)
            } else {
                userDefaults.removeObject(forKey: lastConnectedIdKey)
            }
        }
    }

    // MARK: - Onboarding

    var hasCompletedOnboarding: Bool {
        get { userDefaults.bool(forKey: hasCompletedOnboardingKey) }
        set { userDefaults.set(newValue, forKey: hasCompletedOnboardingKey) }
    }

    var hasSavedConnections: Bool {
        !savedConnections.isEmpty
    }

    // MARK: - Private

    private func load() {
        guard let data = userDefaults.data(forKey: savedConnectionsKey),
              let connections = try? JSONDecoder().decode([SavedGateway].self, from: data)
        else {
            savedConnections = []
            return
        }
        savedConnections = connections
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(savedConnections) else { return }
        userDefaults.set(data, forKey: savedConnectionsKey)
    }
}
