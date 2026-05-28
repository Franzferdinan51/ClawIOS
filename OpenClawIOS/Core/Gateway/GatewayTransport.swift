import CryptoKit
import Foundation

struct GatewayConnectionConfiguration: Equatable {
    var endpoint: GatewayEndpoint
    var credentials: GatewayCredentials?
}

protocol GatewayTransport: AnyObject, Sendable {
    func connect(configuration: GatewayConnectionConfiguration) async throws
    func disconnect() async
    func request(method: String, paramsJSON: String?, timeoutSeconds: Int) async throws -> Data
}

enum GatewayTransportError: LocalizedError {
    case notConnected
    case challengeTimedOut
    case invalidResponse(String)
    case gateway(String)
    case requestTimedOut(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Gateway is not connected."
        case .challengeTimedOut:
            return "Gateway connect challenge timed out."
        case let .invalidResponse(message):
            return message
        case let .gateway(message):
            return message
        case let .requestTimedOut(method):
            return "\(method) timed out."
        }
    }
}

actor GatewayWebSocketTransport: GatewayTransport {
    private let session: URLSession
    private let identityStore: GatewayDeviceIdentityStore
    private var webSocketTask: URLSessionWebSocketTask?
    private var activeConfiguration: GatewayConnectionConfiguration?
    private var pendingResponses: [String: CheckedContinuation<Data, Error>] = [:]
    private var pendingTimeouts: [String: Task<Void, Never>] = [:]
    private var receiveLoopTask: Task<Void, Never>?

    init(session: URLSession = .shared) {
        self.session = session
        self.identityStore = .shared
    }

    func connect(configuration: GatewayConnectionConfiguration) async throws {
        if configuration == self.activeConfiguration, self.webSocketTask != nil {
            return
        }

        await self.disconnect()

        let task = self.session.webSocketTask(with: configuration.endpoint.webSocketURL)
        task.resume()

        let challengeNonce = try await self.waitForConnectChallenge(on: task)
        let requestId = UUID().uuidString
        let connectRequest = try self.makeConnectRequest(
            requestId: requestId,
            configuration: configuration,
            nonce: challengeNonce)
        try await task.send(.data(connectRequest))
        try await self.waitForConnectResponse(on: task, requestId: requestId)

        self.webSocketTask = task
        self.activeConfiguration = configuration
        self.receiveLoopTask = Task {
            await self.receiveLoop()
        }
    }

    func disconnect() async {
        self.receiveLoopTask?.cancel()
        self.receiveLoopTask = nil
        self.webSocketTask?.cancel(with: .goingAway, reason: nil)
        self.webSocketTask = nil
        self.activeConfiguration = nil

        for (id, timeoutTask) in self.pendingTimeouts {
            timeoutTask.cancel()
            self.pendingTimeouts[id] = nil
        }

        for (id, continuation) in self.pendingResponses {
            continuation.resume(throwing: GatewayTransportError.notConnected)
            self.pendingResponses[id] = nil
        }
    }

    func request(method: String, paramsJSON: String?, timeoutSeconds: Int = 15) async throws -> Data {
        guard let webSocketTask else {
            throw GatewayTransportError.notConnected
        }

        let requestId = UUID().uuidString
        let frame = try self.makeRequestFrame(
            requestId: requestId,
            method: method,
            paramsJSON: paramsJSON)

        return try await withCheckedThrowingContinuation { continuation in
            self.pendingResponses[requestId] = continuation
            self.pendingTimeouts[requestId] = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds) * 1_000_000_000)
                await self.failPendingRequest(
                    id: requestId,
                    error: GatewayTransportError.requestTimedOut(method))
            }

            Task {
                do {
                    try await webSocketTask.send(.data(frame))
                } catch {
                    await self.failPendingRequest(id: requestId, error: error)
                }
            }
        }
    }

    private func receiveLoop() async {
        guard let webSocketTask else { return }

        while !Task.isCancelled {
            do {
                let message = try await webSocketTask.receive()
                let data = try self.messageData(from: message)
                try await self.handleFrame(data)
            } catch {
                await self.finishAllPending(error: error)
                self.webSocketTask = nil
                self.activeConfiguration = nil
                return
            }
        }
    }

    private func waitForConnectChallenge(on task: URLSessionWebSocketTask) async throws -> String {
        try await self.withTimeout(seconds: 6) {
            while true {
                let message = try await task.receive()
                let object = try self.jsonObject(from: try self.messageData(from: message))
                if let nonce = Self.connectChallengeNonce(from: object) {
                    return nonce
                }
            }
        }
    }

    private func waitForConnectResponse(on task: URLSessionWebSocketTask, requestId: String) async throws {
        try await self.withTimeout(seconds: 12) {
            while true {
                let message = try await task.receive()
                let object = try self.jsonObject(from: try self.messageData(from: message))
                guard (object["type"] as? String) == "res" else { continue }
                guard (object["id"] as? String) == requestId else { continue }

                if let ok = object["ok"] as? Bool, ok {
                    return
                }

                throw Self.gatewayError(from: object)
            }
        }
    }

    private func handleFrame(_ data: Data) async throws {
        let object = try self.jsonObject(from: data)
        guard let type = object["type"] as? String else { return }
        guard type == "res", let requestId = object["id"] as? String else { return }

        if let ok = object["ok"] as? Bool, ok {
            let payloadData = try Self.payloadData(from: object["payload"])
            await self.resumePendingRequest(id: requestId, result: .success(payloadData))
            return
        }

        await self.resumePendingRequest(id: requestId, result: .failure(Self.gatewayError(from: object)))
    }

    private func makeConnectRequest(
        requestId: String,
        configuration: GatewayConnectionConfiguration,
        nonce: String
    ) throws -> Data {
        let identity = try self.identityStore.loadOrCreate()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let clientId = "openclaw-ios-dashboard"
        let clientMode = "ui"
        let scopes = ["operator.read", "operator.write", "operator.approvals", "operator.talk.secrets"]
        let signedAt = Int(Date().timeIntervalSince1970 * 1000)
        let deviceFamily = "iphone"
        let payload = [
            "v3",
            identity.deviceId,
            clientId,
            clientMode,
            "operator",
            scopes.joined(separator: ","),
            String(signedAt),
            identity.signatureToken(for: configuration.credentials),
            nonce,
            "ios",
            deviceFamily,
        ].joined(separator: "|")

        var params: [String: Any] = [
            "minProtocol": 3,
            "maxProtocol": 4,
            "client": [
                "id": clientId,
                "displayName": "OpenClaw iPhone",
                "version": version,
                "platform": "ios",
                "mode": clientMode,
            ],
            "role": "operator",
            "scopes": scopes,
            "caps": [],
            "locale": Locale.preferredLanguages.first ?? "en-US",
            "userAgent": "OpenClawIOS/\(version)",
            "device": try identity.deviceDictionary(payload: payload, signedAt: signedAt, nonce: nonce),
        ]

        if let auth = Self.authObject(for: configuration.credentials) {
            params["auth"] = auth
        }

        let frame: [String: Any] = [
            "type": "req",
            "id": requestId,
            "method": "connect",
            "params": params,
        ]

        return try JSONSerialization.data(withJSONObject: frame)
    }

    private func makeRequestFrame(
        requestId: String,
        method: String,
        paramsJSON: String?
    ) throws -> Data {
        var frame: [String: Any] = [
            "type": "req",
            "id": requestId,
            "method": method,
        ]

        if let paramsJSON, !paramsJSON.isEmpty {
            frame["params"] = try self.jsonValue(from: paramsJSON)
        }

        return try JSONSerialization.data(withJSONObject: frame)
    }

    private nonisolated func messageData(from message: URLSessionWebSocketTask.Message) throws -> Data {
        switch message {
        case let .data(data):
            return data
        case let .string(string):
            guard let data = string.data(using: .utf8) else {
                throw GatewayTransportError.invalidResponse("Gateway frame was not valid UTF-8.")
            }
            return data
        @unknown default:
            throw GatewayTransportError.invalidResponse("Gateway sent an unsupported WebSocket frame.")
        }
    }

    private nonisolated func jsonObject(from data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GatewayTransportError.invalidResponse("Gateway frame was not a JSON object.")
        }
        return object
    }

    private func jsonValue(from jsonString: String) throws -> Any {
        guard let data = jsonString.data(using: .utf8) else {
            throw GatewayTransportError.invalidResponse("Gateway params were not UTF-8.")
        }

        return try JSONSerialization.jsonObject(with: data)
    }

    private func failPendingRequest(id: String, error: Error) {
        guard let continuation = self.pendingResponses.removeValue(forKey: id) else { return }
        self.pendingTimeouts.removeValue(forKey: id)?.cancel()
        continuation.resume(throwing: error)
    }

    private func resumePendingRequest(id: String, result: Result<Data, Error>) {
        guard let continuation = self.pendingResponses.removeValue(forKey: id) else { return }
        self.pendingTimeouts.removeValue(forKey: id)?.cancel()

        switch result {
        case let .success(data):
            continuation.resume(returning: data)
        case let .failure(error):
            continuation.resume(throwing: error)
        }
    }

    private func finishAllPending(error: Error) {
        let pending = self.pendingResponses
        self.pendingResponses.removeAll()

        for (_, timeoutTask) in self.pendingTimeouts {
            timeoutTask.cancel()
        }
        self.pendingTimeouts.removeAll()

        for (_, continuation) in pending {
            continuation.resume(throwing: error)
        }
    }

    private func withTimeout<T: Sendable>(seconds: Int, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask(operation: operation)
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
                throw GatewayTransportError.challengeTimedOut
            }

            let value = try await group.next()!
            group.cancelAll()
            return value
        }
    }

    private static func connectChallengeNonce(from object: [String: Any]) -> String? {
        guard
            (object["type"] as? String) == "event",
            (object["event"] as? String) == "connect.challenge",
            let payload = object["payload"] as? [String: Any],
            let nonce = payload["nonce"] as? String
        else {
            return nil
        }

        let trimmed = nonce.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func payloadData(from payload: Any?) throws -> Data {
        if payload == nil {
            return Data("{}".utf8)
        }
        return try JSONSerialization.data(withJSONObject: payload ?? [:])
    }

    private static func gatewayError(from object: [String: Any]) -> GatewayTransportError {
        if let error = object["error"] as? [String: Any] {
            let message = (error["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return .gateway(message?.isEmpty == false ? message! : "Gateway request failed.")
        }

        return .gateway("Gateway request failed.")
    }

    private static func authObject(for credentials: GatewayCredentials?) -> [String: String]? {
        guard let credentials else { return nil }

        switch credentials {
        case let .token(value):
            return ["token": value]
        case let .password(value):
            return ["password": value]
        }
    }
}

private struct GatewayDeviceIdentity: Codable {
    let deviceId: String
    let publicKeyBase64: String
    let privateKeyBase64: String

    func signatureToken(for credentials: GatewayCredentials?) -> String {
        switch credentials {
        case let .token(value):
            return value
        case let .password(value):
            return value
        case nil:
            return ""
        }
    }

    func deviceDictionary(payload: String, signedAt: Int, nonce: String) throws -> [String: Any] {
        guard
            let privateKeyData = Data(base64Encoded: self.privateKeyBase64),
            let publicKeyData = Data(base64Encoded: self.publicKeyBase64)
        else {
            throw GatewayTransportError.invalidResponse("Stored gateway device identity is invalid.")
        }

        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData)
        let signature = try privateKey.signature(for: Data(payload.utf8))

        return [
            "id": self.deviceId,
            "publicKey": Self.base64URLEncoded(publicKeyData),
            "signature": Self.base64URLEncoded(signature),
            "signedAt": signedAt,
            "nonce": nonce,
        ]
    }

    private static func base64URLEncoded(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private struct GatewayDeviceIdentityStore: Sendable {
    static let shared = GatewayDeviceIdentityStore()

    private let storage: KeychainCredentialStorage
    private let account = "gateway.device.identity.v1"

    init(storage: KeychainCredentialStorage = KeychainCredentialStorage()) {
        self.storage = storage
    }

    func loadOrCreate() throws -> GatewayDeviceIdentity {
        if
            let data = try self.storage.load(account: self.account),
            let identity = try? JSONDecoder().decode(GatewayDeviceIdentity.self, from: data)
        {
            return identity
        }

        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKeyData = privateKey.publicKey.rawRepresentation
        let identity = GatewayDeviceIdentity(
            deviceId: SHA256.hash(data: publicKeyData).map { String(format: "%02x", $0) }.joined(),
            publicKeyBase64: publicKeyData.base64EncodedString(),
            privateKeyBase64: privateKey.rawRepresentation.base64EncodedString())
        try self.storage.save(try JSONEncoder().encode(identity), account: self.account)
        return identity
    }
}
