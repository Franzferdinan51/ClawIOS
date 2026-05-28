import SwiftUI

@MainActor
@main
struct OpenClawIOSApp: App {
    @State private var sessionModel: AppSessionModel
    @State private var gatewayStore: GatewayOperatorStore
    @State private var connectionStore: GatewayConnectionStore
    @State private var showOnboarding = false

    init() {
        let connectionStore = GatewayConnectionStore()
        let lastEndpoint = connectionStore.lastConnection()?.endpointURL ?? "http://127.0.0.1:18789"
        let sessionModel = AppSessionModel(connectionStore: connectionStore, initialEndpoint: lastEndpoint)
        let transport = GatewayWebSocketTransport()
        let service = LiveGatewayOperatorService(
            transport: transport,
            configurationProvider: {
                try sessionModel.currentGatewayConfiguration()
            })
        let gatewayStore = GatewayOperatorStore(service: service, transport: transport)
        self._sessionModel = State(initialValue: sessionModel)
        self._gatewayStore = State(initialValue: gatewayStore)
        self._connectionStore = State(initialValue: connectionStore)
        self._showOnboarding = State(initialValue: !connectionStore.hasCompletedOnboarding)
    }

    var body: some Scene {
        WindowGroup {
            if showOnboarding {
                OnboardingView()
                    .environment(sessionModel)
                    .environment(gatewayStore)
                    .environment(connectionStore)
            } else {
                RootView()
                    .environment(sessionModel)
                    .environment(gatewayStore)
                    .environment(connectionStore)
            }
        }
    }
}
