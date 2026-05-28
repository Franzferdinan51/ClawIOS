import SwiftUI

struct DebugView: View {
    static let screenTitle = "Debug"

    @Environment(GatewayOperatorStore.self) private var gatewayStore
    @State private var selectedSection = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $selectedSection) {
                Text("RPC").tag(0)
                Text("Events").tag(1)
                Text("Health").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            switch selectedSection {
            case 0: rpcTesterSection
            case 1: eventLogSection
            case 2: healthSection
            default: rpcTesterSection
            }
        }
        .navigationTitle(Self.screenTitle)
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - RPC Tester

    private var rpcTesterSection: some View {
        VStack(spacing: 0) {
            let vm = DebugViewModel(store: gatewayStore)

            ScrollView {
                VStack(spacing: 16) {
                    methodInputSection(vm)
                    paramsInputSection(vm)
                    actionButtons(vm)
                    resultSection(vm)
                }
                .padding()
            }
        }
    }

    private func methodInputSection(_ vm: DebugViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Method", systemImage: "terminal")
                .font(.headline)

            TextField("sessions.list", text: Binding(
                get: { vm.rpcMethod },
                set: { vm.rpcMethod = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.system(.body, design: .monospaced))
        }
    }

    private func paramsInputSection(_ vm: DebugViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Parameters (JSON)")
                .font(.subheadline.weight(.medium))

            TextEditor(text: Binding(
                get: { vm.rpcParams },
                set: { vm.rpcParams = $0 }
            ))
            .font(.system(.caption, design: .monospaced))
            .frame(minHeight: 80)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.tertiarySystemBackground), lineWidth: 1)
            )
        }
    }

    private func actionButtons(_ vm: DebugViewModel) -> some View {
        HStack(spacing: 12) {
            Button {
                Task { await vm.sendRPC() }
            } label: {
                HStack {
                    if vm.isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                    Text("Send")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(OpenClawTheme.primary)
            .disabled(!vm.canSend || vm.isLoading)

            Button {
                vm.clear()
            } label: {
                Text("Clear")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func resultSection(_ vm: DebugViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !vm.rpcError.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("Error")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.red)
                    }
                    Text(vm.rpcError)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            }

            if !vm.rpcResult.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Result")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = vm.rpcResult
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                        }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(vm.rpcResult)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Event Log

    private var eventLogSection: some View {
        Group {
            if gatewayStore.eventLog.isEmpty {
                ContentUnavailableView {
                    Label("No Events", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("Events appear here when the agent is running.")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(gatewayStore.eventLog.reversed()) { event in
                            ActivityEventRow(event: event)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: - Health

    private var healthSection: some View {
        ScrollView {
            VStack(spacing: 16) {
                connectionCard
                statsCard
                sessionCard
                errorCard
            }
            .padding()
        }
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Connection", systemImage: "link")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Circle()
                            .fill(connectionColor)
                            .frame(width: 10, height: 10)
                        Text(connectionLabel)
                            .font(.subheadline.weight(.semibold))
                    }
                }

                Spacer()
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Statistics", systemImage: "chart.bar.fill")
                .font(.headline)

            HStack(spacing: 20) {
                statItem(value: "\(gatewayStore.sessions.count)", label: "Sessions")
                statItem(value: "\(gatewayStore.nodes.count)", label: "Nodes")
                statItem(value: "\(gatewayStore.channels.count)", label: "Channels")
                statItem(value: "\(gatewayStore.eventLog.count)", label: "Events")
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(OpenClawTheme.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Active Session", systemImage: "bubble.left.and.bubble.right.fill")
                .font(.headline)

            if let selectedKey = gatewayStore.selectedSessionKey {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Key")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(selectedKey)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.primary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Messages")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(gatewayStore.transcript.count)")
                        .font(.subheadline)
                }
            } else {
                Text("No active session")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var errorCard: some View {
        if let error = gatewayStore.lastErrorMessage {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Label("Last Error", systemImage: "exclamationmark.triangle")
                        .font(.headline)
                        .foregroundStyle(.orange)
                }
                Text(error)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
            }
            .padding(16)
            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Helpers

    private var connectionLabel: String {
        switch gatewayStore.connectionState {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting"
        case .connected: return "Connected"
        }
    }

    private var connectionColor: Color {
        switch gatewayStore.connectionState {
        case .disconnected: return .gray
        case .connecting: return .yellow
        case .connected: return .green
        }
    }
}