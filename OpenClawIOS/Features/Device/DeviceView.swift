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
                .listStyle(.insetGrouped)
            } else {
                ProgressView()
                    .task {
                        let svc = DeviceService()
                        self.deviceService = svc
                    }
            }
        }
        .navigationTitle(Self.screenTitle)
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Node Status

    private func nodeStatusSection(_ svc: DeviceService) -> some View {
        Section {
            LabeledContent("Device", value: UIDevice.current.name)
            LabeledContent("Model", value: UIDevice.current.model)
            LabeledContent("Registered as") {
                Text(svc.advertiseCapabilities().isEmpty ? "Console only" : svc.advertiseCapabilities().joined(separator: ", "))
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Gateway") {
                HStack(spacing: 6) {
                    Circle()
                        .fill(connectionColor)
                        .frame(width: 7, height: 7)
                    Text(connectionLabel)
                        .font(.subheadline)
                }
            }
        } header: {
            Text("Node Status")
        }
    }

    // MARK: - Voice

    private func voiceSection(_ svc: DeviceService) -> some View {
        Section {
            Toggle("Voice input", isOn: voiceToggleBinding(svc))

            if svc.isListening {
                HStack {
                    Text("Listening...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    AudioLevelBar(level: svc.audioLevel)
                }
            }

            capabilityLabel(icon: "waveform", text: "Wake word detection")
            capabilityLabel(icon: "speaker.wave.3", text: "Voice playback")
            capabilityLabel(icon: "mic.fill", text: "Talk mode (PTT)")
        } header: {
            Text("Voice")
        } footer: {
            Text("Voice enables this iPhone as a voice node for the OpenClaw agent.")
        }
    }

    private func voiceToggleBinding(_ svc: DeviceService) -> Binding<Bool> {
        Binding(
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
        )
    }

    // MARK: - Canvas

    private func canvasSection(_ svc: DeviceService) -> some View {
        Section {
            Toggle("Canvas preview", isOn: Binding(
                get: { svc.isCanvasActive },
                set: { svc.isCanvasActive = $0 }
            ))

            if svc.isCanvasActive, let url = svc.canvasURL {
                CanvasWebView(url: url)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            capabilityLabel(icon: "paintbrush", text: "Live Canvas rendering")
            capabilityLabel(icon: "photo", text: "Canvas snapshot handoff")
        } header: {
            Text("Canvas")
        } footer: {
            Text("Canvas renders the agent's visual workspace via WKWebView.")
        }
    }

    // MARK: - Camera

    private func cameraSection(_ svc: DeviceService) -> some View {
        Section {
            Toggle("Camera access", isOn: Binding(
                get: { svc.cameraAuthorized },
                set: { _ in
                    Task { _ = await svc.requestCameraPermission() }
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
                    capturePhoto(svc)
                }
                .buttonStyle(.bordered)
                .disabled(!svc.cameraAuthorized)
            }

            capabilityLabel(icon: "camera", text: "Camera handoff to agent")
        } header: {
            Text("Camera")
        } footer: {
            Text("Camera allows the agent to see through this device's camera.")
        }
    }

    private func capturePhoto(_ svc: DeviceService) {
        // Camera capture is available on real device
        // Simulator doesn't have camera access
    }

    // MARK: - Location

    private func locationSection(_ svc: DeviceService) -> some View {
        Section {
            Toggle("Location access", isOn: Binding(
                get: { svc.locationAuthorized },
                set: { _ in svc.requestLocationPermission() }
            ))

            if svc.locationAuthorized, let loc = svc.currentLocation {
                LabeledContent("Last location") {
                    Text(String(format: "%.4f, %.4f", loc.coordinate.latitude, loc.coordinate.longitude))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            capabilityLabel(icon: "location", text: "Location context for agent")
        } header: {
            Text("Location")
        } footer: {
            Text("Location provides geographic context to the agent.")
        }
    }

    // MARK: - Helpers

    private func capabilityLabel(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .foregroundStyle(.tertiary)
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