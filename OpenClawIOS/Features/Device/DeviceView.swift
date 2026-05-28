import SwiftUI
import AVFoundation

struct DeviceView: View {
    static let screenTitle = "This iPhone"

    @Environment(GatewayOperatorStore.self) private var gatewayStore
    @State private var deviceService: DeviceService?

    var body: some View {
        Group {
            if let svc = deviceService {
                List {
                    nodeStatusSection(svc)
                    voiceSection(svc)
                    canvasSection(svc)
                    cameraSection(svc)
                    locationSection(svc)
                }
            } else {
                ProgressView()
                    .task {
                        let svc = DeviceService()
                        self.deviceService = svc
                    }
            }
        }
        .navigationTitle(Self.screenTitle)
    }

    // MARK: - Sections

    private func nodeStatusSection(_ svc: DeviceService) -> some View {
        Section("Node Status") {
            LabeledContent("Device") {
                Text(UIDevice.current.name)
            }
            LabeledContent("Model") {
                Text(UIDevice.current.model)
            }
            LabeledContent("Registered as") {
                let caps = svc.advertiseCapabilities()
                Text(caps.isEmpty ? "Console only" : caps.joined(separator: ", "))
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Gateway status") {
                HStack(spacing: 6) {
                    Circle()
                        .fill(connectionColor)
                        .frame(width: 8, height: 8)
                    Text(connectionLabel)
                        .font(.subheadline)
                }
            }
        }
    }

    private func voiceSection(_ svc: DeviceService) -> some View {
        Section("Voice") {
            Toggle("Enable voice", isOn: Binding(
                get: { svc.isVoiceEnabled },
                set: { newValue in
                    if newValue {
                        Task {
                            let granted = await svc.requestVoicePermission()
                            if granted {
                                try? svc.startListening()
                            }
                        }
                    } else {
                        svc.stopListening()
                    }
                }
            ))

            if svc.isListening {
                HStack {
                    Text("Listening...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    // Live audio level bar
                    AudioLevelBar(level: svc.audioLevel)
                }
            }

            Label("Wake word detection", systemImage: "waveform")
                .foregroundStyle(.secondary)
            Label("Voice playback", systemImage: "speaker.wave.3")
                .foregroundStyle(.secondary)
            Label("Talk mode (PTT)", systemImage: "mic.fill")
                .foregroundStyle(.secondary)
        }
    }

    private func canvasSection(_ svc: DeviceService) -> some View {
        Section("Canvas") {
            Toggle("Canvas preview", isOn: Binding(
                get: { svc.isCanvasActive },
                set: { svc.isCanvasActive = $0 }
            ))

            if svc.isCanvasActive, let url = svc.canvasURL {
                CanvasWebView(url: url)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Label("Live Canvas rendering", systemImage: "paintbrush")
                .foregroundStyle(.secondary)
            Label("Canvas snapshot handoff", systemImage: "photo")
                .foregroundStyle(.secondary)
        }
    }

    private func cameraSection(_ svc: DeviceService) -> some View {
        Section("Camera") {
            Toggle("Camera access", isOn: Binding(
                get: { svc.cameraAuthorized },
                set: { _ in
                    Task {
                        _ = await svc.requestCameraPermission()
                    }
                }
            ))

            if svc.cameraAuthorized {
                if let image = svc.lastCapturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Button("Take snapshot") {
                    // TODO: capture image
                }
                .buttonStyle(.bordered)
            }

            Label("Camera handoff to agent", systemImage: "camera")
                .foregroundStyle(.secondary)
        }
    }

    private func locationSection(_ svc: DeviceService) -> some View {
        Section("Location") {
            Toggle("Location access", isOn: Binding(
                get: { svc.locationAuthorized },
                set: { _ in svc.requestLocationPermission() }
            ))

            if svc.locationAuthorized, let loc = svc.currentLocation {
                LabeledContent("Last location") {
                    Text(String(format: "%.4f, %.4f", loc.coordinate.latitude, loc.coordinate.longitude))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            Label("Location context for agent", systemImage: "location")
                .foregroundStyle(.secondary)
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

// MARK: - Audio Level Bar

struct AudioLevelBar: View {
    let level: Float

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 80, height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(OpenClawTheme.primary)
                    .frame(width: CGFloat(min(max(level, 0), 1)) * 80, height: 8)
            }
        }
        .frame(height: 8)
    }
}