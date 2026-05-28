import Foundation

/// A saved gateway connection entry.
struct SavedGateway: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var endpointURL: String
    let createdAt: Date
    var lastConnectedAt: Date?

    init(id: UUID = UUID(), name: String, endpointURL: String, createdAt: Date = Date(), lastConnectedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.endpointURL = endpointURL
        self.createdAt = createdAt
        self.lastConnectedAt = lastConnectedAt
    }

    /// Returns the display title, falling back to the endpoint URL if name is empty.
    var displayTitle: String {
        name.isEmpty ? endpointURL : name
    }
}
