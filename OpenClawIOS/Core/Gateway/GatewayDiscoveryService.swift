import Foundation

/// Protocol for discovering OpenClaw gateway base URLs from various network sources.
protocol GatewayDiscoveryService {
    /// Returns discovered gateway base URLs (e.g. "http://hostname:18789").
    func discoverGatewayBaseURLs() async -> [String]
}

/// Mock implementation for testing and pre-populated discovery.
struct MockGatewayDiscoveryService: GatewayDiscoveryService {
    var candidates: [String]

    func discoverGatewayBaseURLs() async -> [String] {
        self.candidates
    }
}