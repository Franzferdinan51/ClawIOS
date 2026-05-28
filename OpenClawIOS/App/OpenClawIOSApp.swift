import SwiftUI

@MainActor
@main
struct OpenClawIOSApp: App {
    @State private var sessionModel: AppSessionModel
    @State private var gatewayStore: GatewayOperatorStore

    init() {
        let sessionModel = AppSessionModel()
        let transport = GatewayWebSocketTransport()
        let service = LiveGatewayOperatorService(
            transport: transport,
            configurationProvider: {
                try sessionModel.currentGatewayConfiguration()
            })
        let gatewayStore = GatewayOperatorStore(service: service, transport: transport)
        self._sessionModel = State(initialValue: sessionModel)
        self._gatewayStore = State(initialValue: gatewayStore)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(self.sessionModel)
                .environment(self.gatewayStore)
        }
    }
}