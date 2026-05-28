import SwiftUI

struct NodesView: View {
    static let screenTitle = "Nodes"

    @Environment(GatewayOperatorStore.self) private var gatewayStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryCard

                ForEach(self.gatewayStore.nodes) { node in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(node.name)
                                    .font(.headline)

                                Text(node.id)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(node.capabilityNames.count) caps")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.14), in: Capsule())
                        }

                        if node.capabilityNames.isEmpty {
                            Text("No capability metadata reported.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            capabilityWrap(node.capabilityNames)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
            .padding()
        }
        .navigationTitle(Self.screenTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        try? await self.gatewayStore.refreshDashboard()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .overlay {
            if self.gatewayStore.nodes.isEmpty {
                ContentUnavailableView(
                    "No Nodes Connected",
                    systemImage: "desktopcomputer.trianglebadge.exclamationmark",
                    description: Text("Connected desktop, phone, and voice nodes will appear here."))
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Node Fleet", systemImage: "desktopcomputer.and.arrow.down")
                .font(.headline)

            Text("\(self.gatewayStore.nodes.count) connected node\(self.gatewayStore.nodes.count == 1 ? "" : "s")")
                .font(.subheadline)

            Text("Capabilities update from `node.list`, similar to the dashboard overview in Control UI.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func capabilityWrap(_ capabilities: [String]) -> some View {
        FlexibleCapabilityLayout(capabilities: capabilities)
    }
}

private struct FlexibleCapabilityLayout: View {
    let capabilities: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(self.capabilityRows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { capability in
                        Text(capability)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var capabilityRows: [[String]] {
        var rows: [[String]] = [[]]

        for capability in self.capabilities {
            if rows[rows.count - 1].count == 3 {
                rows.append([capability])
            } else {
                rows[rows.count - 1].append(capability)
            }
        }

        return rows.filter { !$0.isEmpty }
    }
}
