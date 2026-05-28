import Observation

@Observable
final class AppSessionModel {
    var selectedTab: RootTab = .home
    var gatewayEndpointInput = "http://127.0.0.1:18789"
    var gatewayConnectionSummary = "Disconnected"
    var gatewayTokenInput = ""
    var tailscaleApiKey: String = ""

    @ObservationIgnored
    let credentialsStore: GatewayCredentialsStore

    init(credentialsStore: GatewayCredentialsStore = GatewayCredentialsStore(storage: KeychainCredentialStorage())) {
        self.credentialsStore = credentialsStore
    }

    func currentGatewayConfiguration() throws -> GatewayConnectionConfiguration {
        let endpoint = try GatewayEndpoint(userInput: self.gatewayEndpointInput)
        let trimmedToken = self.gatewayTokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let credentials: GatewayCredentials? = trimmedToken.isEmpty ? nil : .token(trimmedToken)
        return GatewayConnectionConfiguration(endpoint: endpoint, credentials: credentials)
    }
}
