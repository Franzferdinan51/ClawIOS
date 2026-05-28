import SwiftUI

struct NodesView: View {
    static let screenTitle = "Nodes"

    @Environment(GatewayOperatorStore.self) private var gatewayStore
    @State private var isRefreshing = false

    var body: some View {
        Group {
            if gatewayStore.nodes.isEmpty && !isRefreshing {
                ContentUnavailableView {
                    Label("No Nodes Connected", systemImage: "desktopcomputer.trianglebadge.exclamationmark")
                } description: {
                    Text("Connected desktop, phone, and voice nodes will appear here.")
                } actions: {
                    Button {
                        Task { await self.refresh() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                List {
                    if !gatewayStore.nodes.isEmpty {
                        fleetOverviewSection
                    }

                    ForEach(gatewayStore.nodes) { node in
                        NodeRow(node: node)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(Self.screenTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await self.refresh() }
                } label: {
                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(isRefreshing)
            }
        }
    }

    private var fleetOverviewSection: some View {
        Section {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(gatewayStore.nodes.count)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(OpenClawTheme.primary)
                    Text("nodes online")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(totalCapabilities)")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("capabilities")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Node Fleet")
        }
    }

    private var totalCapabilities: Int {
        gatewayStore.nodes.reduce(0) { $0 + $1.capabilityNames.count }
    }

    private func refresh() async {
        isRefreshing = true
        try? await gatewayStore.refreshDashboard()
        isRefreshing = false
    }
}

// MARK: - Node Row

struct NodeRow: View {
    let node: GatewayNodeSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: nodeIcon)
                    .font(.title2)
                    .foregroundStyle(OpenClawTheme.primary)
                    .frame(width: 36, height: 36)
                    .background(OpenClawTheme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(node.name)
                        .font(.subheadline.weight(.semibold))
                    Text(node.id)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Text("\(node.capabilityNames.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color(.tertiarySystemBackground), in: Circle())
            }

            if node.capabilityNames.isEmpty {
                Text("No capabilities")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                capabilityWrap(node.capabilityNames)
            }
        }
        .padding(.vertical, 8)
    }

    private var nodeIcon: String {
        let lowercased = node.name.lowercased()
        if lowercased.contains("iphone") || lowercased.contains("ios") || lowercased.contains("phone") {
            return "iphone"
        } else if lowercased.contains("mac") || lowercased.contains("desktop") {
            return "desktopcomputer"
        } else if lowercased.contains("ipad") {
            return "ipad"
        } else if lowercased.contains("android") || lowercased.contains("phone") {
            return "smartphone"
        } else {
            return "desktopcomputer.and.arrow.down"
        }
    }

    private func capabilityWrap(_ capabilities: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(capabilities, id: \.self) { cap in
                capabilityChip(cap)
            }
        }
    }

    private func capabilityChip(_ cap: String) -> some View {
        Text(cap)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(OpenClawTheme.primary.opacity(0.1), in: Capsule())
            .foregroundStyle(OpenClawTheme.primary)
    }
}