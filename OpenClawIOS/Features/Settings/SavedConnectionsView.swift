import SwiftUI

struct SavedConnectionsView: View {
    @Environment(GatewayConnectionStore.self) private var connectionStore
    @Environment(AppSessionModel.self) private var sessionModel
    @Environment(GatewayOperatorStore.self) private var gatewayStore
    @Environment(\.dismiss) private var dismiss

    @State private var showAddConnection = false
    @State private var editingConnection: SavedGateway?
    @State private var editName = ""
    @State private var isConnecting = false

    var body: some View {
        List {
            if connectionStore.savedConnections.isEmpty {
                emptyState
            } else {
                connectionsList
            }
        }
        .navigationTitle("Connections")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddConnection = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddConnection) {
            NavigationStack {
                AddConnectionView()
            }
        }
        .sheet(item: $editingConnection) { connection in
            NavigationStack {
                EditConnectionView(connection: connection)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "network.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Saved Connections")
                .font(.headline)

            Text("Add a gateway connection to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showAddConnection = true
            } label: {
                Label("Add Connection", systemImage: "plus.circle")
            }
            .buttonStyle(.borderedProminent)
            .tint(OpenClawTheme.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .listRowBackground(Color.clear)
    }

    private var connectionsList: some View {
        ForEach(connectionStore.savedConnections) { connection in
            ConnectionRow(
                connection: connection,
                isLastConnected: connectionStore.lastConnectedId == connection.id,
                onSelect: { selectConnection(connection) },
                onEdit: { editingConnection = connection }
            )
        }
        .onDelete { indexSet in
            for index in indexSet {
                let connection = connectionStore.savedConnections[index]
                connectionStore.delete(id: connection.id)
            }
        }
    }

    private func selectConnection(_ connection: SavedGateway) {
        sessionModel.gatewayEndpointInput = connection.endpointURL
        connectionStore.updateLastConnected(id: connection.id)

        Task {
            try? await gatewayStore.refreshDashboard()
        }
    }
}

// MARK: - Connection Row

struct ConnectionRow: View {
    let connection: SavedGateway
    let isLastConnected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(connection.displayTitle)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)

                        if isLastConnected {
                            Text("Last used")
                                .font(.caption2)
                                .foregroundStyle(OpenClawTheme.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(OpenClawTheme.primary.opacity(0.12)))
                        }
                    }

                    Text(connection.endpointURL)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isLastConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(OpenClawTheme.success)
                }

                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil.circle")
                        .foregroundStyle(OpenClawTheme.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Connection View

struct AddConnectionView: View {
    @Environment(GatewayConnectionStore.self) private var connectionStore
    @Environment(AppSessionModel.self) private var sessionModel
    @Environment(GatewayOperatorStore.self) private var gatewayStore
    @Environment(\.dismiss) private var dismiss

    @State private var endpointInput = ""
    @State private var connectionName = ""
    @State private var isDiscovering = false
    @State private var discoveredEndpoints: [String] = []
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @State private var currentStep: AddConnectionStep = .input

    enum AddConnectionStep {
        case input
        case connecting
    }

    var body: some View {
        Form {
            Section {
                TextField("http://192.168.1.100:18789", text: $endpointInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                Button {
                    Task { await scanLocalNetwork() }
                } label: {
                    Label("Scan Local Network", systemImage: "wifi")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isDiscovering)

                if isDiscovering {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Scanning...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !discoveredEndpoints.isEmpty {
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
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text("Gateway URL")
            }

            if !endpointInput.isEmpty {
                Section {
                    TextField("Name (optional)", text: $connectionName)
                } header: {
                    Text("Connection Name")
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Add Connection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveConnection()
                }
                .disabled(endpointInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isConnecting)
            }
        }
    }

    private func scanLocalNetwork() async {
        isDiscovering = true
        discoveredEndpoints = []
        let service = BonjourDiscoveryService()
        discoveredEndpoints = await service.discoverGatewayBaseURLs()
        isDiscovering = false
    }

    private func saveConnection() {
        let trimmed = endpointInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isConnecting = true
        errorMessage = nil

        let newConnection = SavedGateway(
            name: connectionName.isEmpty ? trimmed : connectionName,
            endpointURL: trimmed
        )

        connectionStore.save(newConnection)
        connectionStore.updateLastConnected(id: newConnection.id)
        sessionModel.gatewayEndpointInput = trimmed

        Task {
            do {
                try await gatewayStore.refreshDashboard()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isConnecting = false
            }
        }
    }
}

// MARK: - Edit Connection View

struct EditConnectionView: View {
    let connection: SavedGateway

    @Environment(GatewayConnectionStore.self) private var connectionStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
            } header: {
                Text("Connection Name")
            }

            Section {
                Text(connection.endpointURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Gateway URL")
            }

            if let lastConnected = connection.lastConnectedAt {
                Section {
                    Text(lastConnected, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Last Connected")
                }
            }
        }
        .navigationTitle("Edit Connection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveChanges()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            name = connection.name
        }
    }

    private func saveChanges() {
        var updated = connection
        updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        connectionStore.save(updated)
        dismiss()
    }
}
