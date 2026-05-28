import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case connect
    case name
    case connecting
    case success
}

struct OnboardingView: View {
    @Environment(GatewayConnectionStore.self) private var connectionStore
    @Environment(AppSessionModel.self) private var sessionModel
    @Environment(GatewayOperatorStore.self) private var gatewayStore

    @State private var currentStep: OnboardingStep = .welcome
    @State private var endpointInput = "http://127.0.0.1:18789"
    @State private var connectionName = ""
    @State private var isDiscovering = false
    @State private var discoveredEndpoints: [String] = []
    @State private var errorMessage: String?
    @State private var pendingGatewayId: UUID?

    private let bonjourService = BonjourDiscoveryService()

    private func scanLocalNetwork() async {
        isDiscovering = true
        discoveredEndpoints = []
        let service = BonjourDiscoveryService()
        discoveredEndpoints = await service.discoverGatewayBaseURLs()
        isDiscovering = false
    }

    var body: some View {
        ZStack {
            OpenClawTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                progressIndicator
                    .padding(.top, 16)

                TabView(selection: $currentStep) {
                    welcomeStep.tag(OnboardingStep.welcome)
                    connectStep.tag(OnboardingStep.connect)
                    nameStep.tag(OnboardingStep.name)
                    connectingStep.tag(OnboardingStep.connecting)
                    successStep.tag(OnboardingStep.success)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(visibleSteps, id: \.self) { step in
                Circle()
                    .fill(currentStep.rawValue >= step.rawValue ? OpenClawTheme.primary : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var visibleSteps: [OnboardingStep] {
        [.welcome, .connect, .name, .success]
    }

    // MARK: - Welcome Step

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "pawprint.fill")
                .font(.system(size: 72))
                .foregroundStyle(OpenClawTheme.primary)

            VStack(spacing: 12) {
                Text("Welcome to OpenClaw")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)

                Text("Connect to your OpenClaw gateway to manage sessions, nodes, and chats from your iPhone.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button {
                withAnimation { currentStep = .connect }
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(OpenClawTheme.primary)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .padding()
    }

    // MARK: - Connect Step

    private var connectStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Connect to Gateway")
                    .font(.title.bold())
                    .foregroundStyle(.primary)

                Text("Enter your gateway URL or scan your local network.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)

            VStack(spacing: 16) {
                TextField("http://192.168.1.100:18789", text: $endpointInput)
                    .textFieldStyle(.plain)
                    .padding(16)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                Button {
                    Task { await scanLocalNetwork() }
                } label: {
                    Label("Scan Local Network", systemImage: "wifi")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .disabled(isDiscovering)

                if isDiscovering {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Scanning for gateways...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !discoveredEndpoints.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Found on your network:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(discoveredEndpoints, id: \.self) { url in
                            Button {
                                endpointInput = url
                            } label: {
                                HStack {
                                    Image(systemName: "network")
                                        .foregroundStyle(OpenClawTheme.primary)
                                    Text(url)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "arrow.right.circle.fill")
                                        .foregroundStyle(OpenClawTheme.primary)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                validateAndProceed()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(OpenClawTheme.primary)
            .disabled(endpointInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Name Step

    private var nameStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Name Your Gateway")
                    .font(.title.bold())
                    .foregroundStyle(.primary)

                Text("Give this connection a friendly name so you can easily identify it later.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)

            VStack(spacing: 16) {
                TextField("My OpenClaw Gateway", text: $connectionName)
                    .textFieldStyle(.plain)
                    .padding(16)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Gateway URL:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(endpointInput)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                saveAndConnect()
            } label: {
                Text("Save & Connect")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(OpenClawTheme.primary)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Connecting Step

    private var connectingStep: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .padding(.bottom, 16)

            VStack(spacing: 12) {
                Text("Connecting...")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)

                Text("Establishing connection to your gateway.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button {
                withAnimation { currentStep = .connect }
            } label: {
                Text("Go Back")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Success Step

    private var successStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(OpenClawTheme.success)

            VStack(spacing: 12) {
                Text("Connected!")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)

                Text("You're all set up. Enjoy managing your OpenClaw gateway from your iPhone.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button {
                completeOnboarding()
            } label: {
                Text("Start Using OpenClaw")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(OpenClawTheme.primary)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Actions

    private func validateAndProceed() {
        let trimmed = endpointInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        endpointInput = trimmed
        connectionName = defaultName(for: trimmed)
        withAnimation { currentStep = .name }
    }

    private func defaultName(for url: String) -> String {
        guard let urlObj = URL(string: url), let host = urlObj.host else {
            return "My Gateway"
        }
        return host
    }

    private func saveAndConnect() {
        Task {
            await performConnect()
        }
    }

    private func performConnect() async {
        currentStep = .connecting
        errorMessage = nil

        let newGateway = SavedGateway(
            name: connectionName.isEmpty ? endpointInput : connectionName,
            endpointURL: endpointInput
        )
        pendingGatewayId = newGateway.id

        do {
            connectionStore.save(newGateway)
            connectionStore.updateLastConnected(id: newGateway.id)

            sessionModel.gatewayEndpointInput = endpointInput

            try await gatewayStore.refreshDashboard()

            let connectedGateway = SavedGateway(
                id: newGateway.id,
                name: newGateway.name,
                endpointURL: newGateway.endpointURL,
                createdAt: newGateway.createdAt,
                lastConnectedAt: Date()
            )
            connectionStore.save(connectedGateway)
            pendingGatewayId = nil

            withAnimation { currentStep = .success }
        } catch {
            errorMessage = error.localizedDescription
            if let id = pendingGatewayId {
                connectionStore.delete(id: id)
            }
            pendingGatewayId = nil
            withAnimation { currentStep = .connect }
        }
    }

    func completeOnboarding() {
        connectionStore.hasCompletedOnboarding = true
    }
}
