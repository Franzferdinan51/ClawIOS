import SwiftUI
import AVFoundation
import Speech
import PhotosUI
import CoreLocation
import WebKit

/// Handles iPhone-specific capabilities for the OpenClaw node.
/// Registers this device as a node with the gateway and provides
/// voice, canvas, camera, and location services.
@Observable
@MainActor
final class DeviceService {
    // MARK: - Voice

    var isVoiceEnabled = false
    var isListening = false
    var wakeWordDetected = false
    var audioLevel: Float = 0

    private var audioEngine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?

    // MARK: - Canvas

    var canvasURL: URL?
    var isCanvasActive = false

    // MARK: - Camera

    var lastCapturedImage: UIImage?
    var cameraAuthorized = false

    // MARK: - Location

    var currentLocation: CLLocation?
    var locationAuthorized = false

    private let locationManager = CLLocationManager()

    init() {
        locationManager.delegate = locationDelegate
    }

    // MARK: - Node Registration

    func registerAsNode() async throws {
        // The gateway will register this device when it first connects.
        // Voice/camera/location capabilities are advertised in node.list response.
    }

    func advertiseCapabilities() -> [String] {
        var caps: [String] = []
        if isVoiceEnabled { caps.append("voice") }
        if canvasURL != nil { caps.append("canvas") }
        if cameraAuthorized { caps.append("camera") }
        if locationAuthorized { caps.append("location") }
        caps.append("device")
        return caps
    }

    // MARK: - Voice

    func requestVoicePermission() async -> Bool {
        let result = await AVAudioApplication.requestRecordPermission()
        await MainActor.run {
            isVoiceEnabled = result
        }
        return result
    }

    func startListening() throws {
        guard isVoiceEnabled else { return }
        audioEngine = AVAudioEngine()
        let inputNode = audioEngine!.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            let level = buffer.floatChannelData?[0].pointee ?? 0
            DispatchQueue.main.async {
                self?.audioLevel = abs(level)
            }
        }

        try audioEngine?.start()
        isListening = true
    }

    func stopListening() {
        audioEngine?.stop()
        audioEngine = nil
        isListening = false
        audioLevel = 0
    }

    // MARK: - Camera

    func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            cameraAuthorized = true
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraAuthorized = granted
            return granted
        default:
            cameraAuthorized = false
            return false
        }
    }

    // MARK: - Location

    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startLocationUpdates() {
        locationAuthorized = locationManager.authorizationStatus == .authorizedWhenInUse
        guard locationAuthorized else { return }
        locationManager.startUpdatingLocation()
    }

    private var locationDelegate = LocationDelegate()

    private class LocationDelegate: NSObject, CLLocationManagerDelegate {
        var currentLocation: CLLocation?

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            currentLocation = locations.last
        }
    }
}

// MARK: - Canvas WebView

struct CanvasWebView: UIViewRepresentable {
    let url: URL?

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = true
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if let url {
            webView.load(URLRequest(url: url))
        }
    }
}

// MARK: - Camera

struct CameraView: UIViewRepresentable {
    @Binding var capturedImage: UIImage?

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return view
        }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        context.coordinator.previewLayer = previewLayer

        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }

        return view
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    class Coordinator: NSObject {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}