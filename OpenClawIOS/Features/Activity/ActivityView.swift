import SwiftUI

struct ActivityView: View {
    static let screenTitle = "Activity"

    @Environment(GatewayOperatorStore.self) private var gatewayStore
    @State private var autoScroll = true

    var body: some View {
        Group {
            if gatewayStore.eventLog.isEmpty {
                ContentUnavailableView(
                    "No Activity Yet",
                    systemImage: "ant",
                    description: Text("Agent tool calls and thinking will appear here as they happen.")
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(gatewayStore.eventLog.reversed()) { event in
                                ActivityEventRow(event: event)
                                    .id(event.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: gatewayStore.eventLog.count) { _, _ in
                        if autoScroll, let last = gatewayStore.eventLog.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(Self.screenTitle)
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
}

struct ActivityEventRow: View {
    let event: GatewayEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconFor(event.type))
                .foregroundStyle(colorFor(event.type))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.type.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(colorFor(event.type))
                    Spacer()
                    Text(event.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(event.message)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .background(cardColor(for: event.type), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func iconFor(_ type: String) -> String {
        switch type.lowercased() {
        case "tool": return "wrench.and.screwdriver"
        case "thinking": return "brain"
        case "message": return "bubble.left"
        case "error": return "exclamationmark.triangle"
        case "warning": return "exclamationmark.circle"
        case "session": return "rectangle.and.pencil.and.ellipsis"
        case "connect": return "link"
        case "disconnect": return "link.badge.plus"
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
        default: return .secondary
        }
    }

    private func cardColor(for type: String) -> Color {
        type.lowercased() == "error" ? Color.red.opacity(0.08) : Color(.secondarySystemBackground)
    }
}