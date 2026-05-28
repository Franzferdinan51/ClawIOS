import Observation
import Foundation

@Observable
final class AppSessionModel: @unchecked Sendable {
    var selectedTab: RootTab = .home
    var gatewayEndpointInput = "http://127.0.0.1:18789"
    var gatewayConnectionSummary = "Disconnected"
    var gatewayTokenInput = ""
    var tailscaleApiKey: String = ""

    @ObservationIgnored
    let credentialsStore: GatewayCredentialsStore

    @ObservationIgnored
    let connectionStore: GatewayConnectionStore

    init(connectionStore: GatewayConnectionStore? = nil, initialEndpoint: String = "http://127.0.0.1:18789") {
        self.credentialsStore = GatewayCredentialsStore(storage: KeychainCredentialStorage())
        self.connectionStore = connectionStore ?? GatewayConnectionStore()
        self.gatewayEndpointInput = initialEndpoint
    }

    /// Switches to a saved connection by ID, updating endpoint and triggering reconnect.
    func switchToConnection(_ connection: SavedGateway) {
        self.gatewayEndpointInput = connection.endpointURL
        connectionStore.updateLastConnected(id: connection.id)
    }

    func currentGatewayConfiguration() throws -> GatewayConnectionConfiguration {
        let endpoint = try GatewayEndpoint(userInput: self.gatewayEndpointInput)
        let trimmedToken = self.gatewayTokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let credentials: GatewayCredentials? = trimmedToken.isEmpty ? nil : .token(trimmedToken)
        return GatewayConnectionConfiguration(endpoint: endpoint, credentials: credentials)
    }
}
