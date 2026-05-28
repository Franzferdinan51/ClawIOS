import SwiftUI

struct ActivityView: View {
    static let screenTitle = "Activity"

    @Environment(GatewayOperatorStore.self) private var gatewayStore
    @State private var autoScroll = true
    @State private var selectedFilter: String = "all"

    private let filters = ["all", "tool", "thinking", "message", "error", "session"]

    var body: some View {
        Group {
            if gatewayStore.eventLog.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    filterBar
                    eventList
                }
            }
        }
        .navigationTitle(Self.screenTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    gatewayStore.clearEventLog()
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.self) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.capitalized)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedFilter == filter ? OpenClawTheme.primary : Color(.tertiarySystemBackground), in: Capsule())
                            .foregroundStyle(selectedFilter == filter ? .white : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Event List

    private var eventList: some View {
        let filteredEvents = filteredEvents

        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(filteredEvents.reversed()) { event in
                        ActivityEventRow(event: event)
                            .id(event.id)
                    }
                }
                .padding()
            }
            .onChange(of: gatewayStore.eventLog.count) { _, _ in
                if autoScroll, let last = filteredEvents.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var filteredEvents: [GatewayEvent] {
        if selectedFilter == "all" {
            return gatewayStore.eventLog
        }
        return gatewayStore.eventLog.filter { $0.type.lowercased() == selectedFilter }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Activity Yet", systemImage: "ant.fill")
        } description: {
            Text("Agent tool calls and thinking will appear here as they happen.")
        } actions: {
            Button {
                Task { try? await self.gatewayStore.refreshDashboard() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - Activity Event Row

struct ActivityEventRow: View {
    let event: GatewayEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(colorFor(event.type).opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: iconFor(event.type))
                    .font(.caption)
                    .foregroundStyle(colorFor(event.type))
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(event.type.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(colorFor(event.type))

                    Spacer()

                    Text(relativeTime(event.timestamp))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Text(event.message)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)
                    .lineLimit(nil)
            }
        }
        .padding(14)
        .background(eventColor(for: event.type), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func iconFor(_ type: String) -> String {
        switch type.lowercased() {
        case "tool": return "wrench.and.screwdriver"
        case "thinking": return "brain"
        case "message": return "bubble.left.fill"
        case "error": return "exclamationmark.triangle.fill"
        case "warning": return "exclamationmark.circle.fill"
        case "session": return "rectangle.and.pencil.and.ellipsis"
        case "connect": return "link"
        case "disconnect": return "link.badge.plus"
        case "node": return "desktopcomputer"
        default: return "circle.fill"
        }
    }

    private func colorFor(_ type: String) -> Color {
        switch type.lowercased() {
        case "tool": return OpenClawTheme.primary
        case "thinking": return .purple
        case "message": return .green
        case "error": return .red
        case "warning": return .yellow
        case "session": return .blue
        case "connect": return .cyan
        case "disconnect": return .orange
        case "node": return .teal
        default: return .secondary
        }
    }

    private func eventColor(for type: String) -> Color {
        switch type.lowercased() {
        case "error": return Color.red.opacity(0.06)
        case "warning": return Color.yellow.opacity(0.06)
        default: return Color(.secondarySystemBackground)
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 {
            return "\(Int(seconds))s ago"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60))m ago"
        } else {
            return "\(Int(seconds / 3600))h ago"
        }
    }
}