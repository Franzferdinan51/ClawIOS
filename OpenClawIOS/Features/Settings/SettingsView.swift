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
            savedConnectionsSection
            connectionStatusSection
            discoverySection
            tailscaleSection
            aboutSection
        }
        .navigationTitle(Self.screenTitle)
        .navigationBarTitleDisplayMode(.large)
        .task {
            self.statusMessage = self.sessionModel.gatewayConnectionSummary
            self.loadSavedCredentialsIfAvailable()
        }
    }

    // MARK: - Saved Connections Section

    private var savedConnectionsSection: some View {
        Section {
            NavigationLink {
                SavedConnectionsView()
            } label: {
                HStack {
                    Image(systemName: "network")
                        .foregroundStyle(OpenClawTheme.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Saved Connections")
                            .font(.subheadline)
                        Text("\(sessionModel.connectionStore.savedConnections.count) saved")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Connection Status Section

    private var connectionStatusSection: some View {
        Section {
            HStack {
                Circle()
                    .fill(self.connectionColor)
                    .frame(width: 8, height: 8)
                Text(self.statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack {
                TextField("http://127.0.0.1:18789", text: Bindable(self.sessionModel).gatewayEndpointInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                Button {
                    Task { await self.connectGateway() }
                } label: {
                    if self.gatewayStore.connectionState == .connecting {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(self.gatewayStore.connectionState == .connecting)
            }

            SecureField("Bearer token (optional)", text: Bindable(self.sessionModel).gatewayTokenInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("Current Connection")
        } footer: {
            if let error = self.gatewayStore.lastErrorMessage {
                Text(error)
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
    }

    // MARK: - Discovery Section

    private var discoverySection: some View {
        Section {
            HStack(spacing: 12) {
                Button {
                    Task { await self.discoverEndpoints(source: "local") }
                } label: {
                    Label("Scan Local", systemImage: "wifi")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isDiscovering)

                Button {
                    Task { await self.discoverEndpoints(source: "tailscale") }
                } label: {
                    Label("Scan Tailnet", systemImage: "network")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isDiscovering || self.sessionModel.tailscaleApiKey.nilIfBlank == nil)
            }

            if isDiscovering {
                HStack {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Scanning for gateways...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(discoveredEndpoints, id: \.self) { endpoint in
                Button {
                    self.sessionModel.gatewayEndpointInput = endpoint
                } label: {
                    HStack {
                        Image(systemName: discoverySource == "tailscale" ? "network" : "wifi")
                            .foregroundStyle(OpenClawTheme.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(endpoint)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Text(discoverySource == "tailscale" ? "Tailscale" : "Local network")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(OpenClawTheme.primary)
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Discovery")
        } footer: {
            Text("Scan Local uses Bonjour to find gateways on your network. Scan Tailnet uses Tailscale API to find gateways on your tailnet.")
        }
    }

    // MARK: - Tailscale Section

    private var tailscaleSection: some View {
        Section {
            SecureField("Tailscale API key (tskey-koclat-...)", text: Bindable(self.sessionModel).tailscaleApiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("Remote Access")
        } footer: {
            Text("Get an API key from tailscale.com/settings/api. Required for remote gateway access when away from your local network.")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            LabeledContent("App", value: "OpenClaw iOS")
            LabeledContent("Version", value: "Phase 1")
            LabeledContent("Sessions") {
                Text("\(self.gatewayStore.sessions.count)")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Nodes") {
                Text("\(self.gatewayStore.nodes.count)")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("About")
        }
    }

    // MARK: - Helpers

    private var connectionLabel: String {
        switch self.gatewayStore.connectionState {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting"
        case .connected: return "Connected"
        }
    }

    private var connectionColor: Color {
        switch self.gatewayStore.connectionState {
        case .disconnected: return .gray
        case .connecting: return .yellow
        case .connected: return .green
        }
    }

    private var statusText: String {
        self.statusMessage.isEmpty ? self.connectionLabel : self.statusMessage
    }

    // MARK: - Actions

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

            self.statusMessage = "Connecting..."
            self.sessionModel.gatewayConnectionSummary = self.statusMessage

            try await self.gatewayStore.refreshDashboard()

            self.statusMessage = "Connected"
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
        case let .token(value), let .password(value):
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
