import SwiftUI

struct DebugView: View {
    static let screenTitle = "Debug"

    @Environment(GatewayOperatorStore.self) private var gatewayStore
    @State private var viewModel: DebugViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        rpcTesterCard(vm: vm)
                        eventLogCard
                        healthCard
                    }
                    .padding()
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(Self.screenTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Clear log") {
                        gatewayStore.clearEventLog()
                    }
                    Button("Copy Gateway ID") {
                        // TODO: copy device ID
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = DebugViewModel(store: gatewayStore)
            }
        }
    }

    private func rpcTesterCard(vm: DebugViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("RPC Tester", systemImage: "terminal")
                .font(.headline)

            TextField("Method (e.g. sessions.list)", text: Bindable(vm).rpcMethod)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("Params JSON", text: Bindable(vm).rpcParams, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.system(.footnote, design: .monospaced))
                .lineLimit(3...6)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            HStack {
                Button("Send") {
                    Task { await vm.sendRPC() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!vm.canSend || vm.isLoading)

                Button("Clear") { vm.clear() }
                    .buttonStyle(.bordered)
            }

            if vm.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Sending...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if !vm.rpcError.nilIfBlank.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Error")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                    Text(vm.rpcError)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.red)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }

            if !vm.rpcResult.nilIfBlank.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Result")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(vm.rpcResult)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var eventLogCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Event Log", systemImage: "list.bullet.rectangle")
                    .font(.headline)
                Spacer()
                Text("\(gatewayStore.eventLog.count) events")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if gatewayStore.eventLog.isEmpty {
                Text("No events recorded. Events appear here when the agent is running.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(gatewayStore.eventLog.reversed()) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(event.type)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(eventColor(for: event.type))
                            Spacer()
                            Text(event.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Text(event.message)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                    .padding(8)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var healthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Gateway Health", systemImage: "heart.fill")
                .font(.headline)

            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Connection")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(connectionColor)
                            .frame(width: 8, height: 8)
                        Text(connectionLabel)
                            .font(.subheadline.weight(.medium))
                    }
                }

                VStack(alignment: .leading) {
                    Text("Sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(gatewayStore.sessions.count)")
                        .font(.subheadline.weight(.medium))
                }

                VStack(alignment: .leading) {
                    Text("Nodes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(gatewayStore.nodes.count)")
                        .font(.subheadline.weight(.medium))
                }

                Spacer()
            }

            if let error = gatewayStore.lastErrorMessage {
                Text("Last error: \(error)")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

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

    private func eventColor(for type: String) -> Color {
        switch type.lowercased() {
        case "error": return .red
        case "tool": return .blue
        case "thinking": return .purple
        case "message": return .green
        default: return .secondary
        }
    }
}

private extension String {
    var nilIfBlank: String {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : self
    }
}