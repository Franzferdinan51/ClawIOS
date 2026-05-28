import SwiftUI

struct SettingsView: View {
    static let screenTitle = "Gateway Settings"

    @Environment(AppSessionModel.self) private var sessionModel
    @Environment(GatewayOperatorStore.self) private var gatewayStore
    @State private var statusMessage = ""
    @State private var discoveredEndpoints: [String] = []
    @State private var isDiscovering = false
    @State private var discoverySource: String?

    var body: some View {
        Form {
            Section("Gateway") {
                TextField("http://127.0.0.1:18789", text: Bindable(self.sessionModel).gatewayEndpointInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Bearer token (optional)", text: Bindable(self.sessionModel).gatewayTokenInput)

                LabeledContent("Status") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(self.connectionColor)
                            .frame(width: 8, height: 8)
                        Text(self.statusText)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Connect") {
                    Task {
                        await self.connectGateway()
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            Section("Discovery") {
                HStack(spacing: 12) {
                    Button("Scan Local") {
                        Task {
                            await self.discoverEndpoints(source: "local")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isDiscovering)

                    Button("Scan Tailnet") {
                        Task {
                            await self.discoverEndpoints(source: "tailscale")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isDiscovering || self.sessionModel.tailscaleApiKey.nilIfBlank == nil)
                }

                if isDiscovering {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Scanning...")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if !discoveredEndpoints.isEmpty {
                    ForEach(discoveredEndpoints, id: \.self) { endpoint in
                        Button {
                            self.sessionModel.gatewayEndpointInput = endpoint
                        } label: {
                            HStack {
                                Image(systemName: discoverySource == "tailscale" ? "network" : "wifi")
                                    .foregroundStyle(.secondary)
                                Text(endpoint)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("Remote Access (Tailscale)") {
                SecureField("Tailscale API key (tskey-koclat-...)", text: Bindable(self.sessionModel).tailscaleApiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Text("Get an API key from tailscale.com/settings/api. Required for remote gateway access when away from your local network.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("Connected to") {
                    Text(self.sessionModel.gatewayEndpointInput)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                LabeledContent("App version") {
                    Text("Phase 1")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(Self.screenTitle)
        .task {
            self.statusMessage = self.sessionModel.gatewayConnectionSummary
            self.loadSavedCredentialsIfAvailable()
        }
    }

    private var connectionLabel: String {
        switch self.gatewayStore.connectionState {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        }
    }

    private var connectionColor: Color {
        switch self.gatewayStore.connectionState {
        case .disconnected:
            return .gray
        case .connecting:
            return .yellow
        case .connected:
            return .green
        }
    }

    private var statusText: String {
        self.statusMessage.isEmpty ? self.connectionLabel : self.statusMessage
    }

    private func discoverEndpoints(source: String) async {
        isDiscovering = true
        discoveredEndpoints = []
        discoverySource = source

        let service: GatewayDiscoveryService
        if source == "tailscale" {
            let apiKey = self.sessionModel.tailscaleApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            service = TailscaleDiscoveryService(apiKey: apiKey)
        } else {
            service = BonjourDiscoveryService()
        }

        discoveredEndpoints = await service.discoverGatewayBaseURLs()
        isDiscovering = false
    }

    private func connectGateway() async {
        do {
            let endpoint = try GatewayEndpoint(userInput: self.sessionModel.gatewayEndpointInput)
            self.sessionModel.gatewayEndpointInput = endpoint.httpBaseURL.absoluteString

            let trimmedToken = self.sessionModel.gatewayTokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedToken.isEmpty {
                try self.sessionModel.credentialsStore.save(.token(trimmedToken), for: endpoint)
            }

            self.statusMessage = "Connecting to \(endpoint.httpBaseURL.host ?? endpoint.httpBaseURL.absoluteString)"
            self.sessionModel.gatewayConnectionSummary = self.statusMessage

            try await self.gatewayStore.refreshDashboard()

            self.statusMessage = "Connected to \(endpoint.httpBaseURL.host ?? endpoint.httpBaseURL.absoluteString)"
            self.sessionModel.gatewayConnectionSummary = self.statusMessage
        } catch {
            self.statusMessage = error.localizedDescription
            self.sessionModel.gatewayConnectionSummary = self.statusMessage
        }
    }

    private func loadSavedCredentialsIfAvailable() {
        guard let endpoint = try? GatewayEndpoint(userInput: self.sessionModel.gatewayEndpointInput) else {
            return
        }

        guard let credentials = try? self.sessionModel.credentialsStore.load(for: endpoint) else {
            return
        }

        switch credentials {
        case let .token(value):
            self.sessionModel.gatewayTokenInput = value
        case let .password(value):
            self.sessionModel.gatewayTokenInput = value
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}