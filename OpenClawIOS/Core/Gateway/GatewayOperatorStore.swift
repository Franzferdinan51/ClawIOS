import Foundation
import Observation

@Observable
@MainActor
final class GatewayOperatorStore {
    enum StoreError: LocalizedError {
        case noSelectedSession

        var errorDescription: String? {
            switch self {
            case .noSelectedSession:
                return "Select a session before sending a message."
            }
        }
    }

    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
    }

    var connectionState: ConnectionState = .disconnected
    var sessions: [GatewaySessionSummary] = []
    var nodes: [GatewayNodeSummary] = []
    var transcript: [GatewayChatMessage] = []
    var selectedSessionKey: String?
    var isSendingMessage = false
    var lastErrorMessage: String?
    var selectedModel: String?
    var selectedThinking: String = "low"
    var isAgentRunning = false
    var lastAgentActivity: String?
    var eventLog: [GatewayEvent] = []
    var channels: [GatewayChannel] = []

    private let service: GatewayOperatorService
    private var _transport: GatewayTransport?

    init(service: GatewayOperatorService, transport: GatewayTransport? = nil) {
        self.service = service
        self._transport = transport
    }

    var transport: GatewayTransport? {
        _transport
    }

    func connect() async throws {
        self.lastErrorMessage = nil
        self.connectionState = .connecting
        do {
            try await self.service.connect()
            self.sessions = try await self.service.listSessions()
            self.nodes = try await self.service.listNodes()
            self.connectionState = .connected
        } catch {
            self.connectionState = .disconnected
            self.lastErrorMessage = error.localizedDescription
            throw error
        }
    }

    func bootstrap() async {
        guard self.connectionState == .disconnected else { return }

        do {
            try await self.connect()

            if let firstSessionKey = self.sessions.first?.key {
                try await self.selectSession(firstSessionKey)
            }
        } catch {
            self.connectionState = .disconnected
            self.lastErrorMessage = error.localizedDescription
        }
    }

    func refreshDashboard() async throws {
        self.lastErrorMessage = nil
        do {
            self.sessions = try await self.service.listSessions()
            self.nodes = try await self.service.listNodes()
            self.connectionState = .connected

            let preferredSessionKey = self.selectedSessionKey.flatMap { selectedKey in
                self.sessions.contains(where: { $0.key == selectedKey }) ? selectedKey : nil
            } ?? self.sessions.first?.key

            if let preferredSessionKey {
                try await self.selectSession(preferredSessionKey)
            } else {
                self.selectedSessionKey = nil
                self.transcript = []
            }
        } catch {
            self.lastErrorMessage = error.localizedDescription
            throw error
        }
    }

    func refreshSessions() async throws {
        self.lastErrorMessage = nil
        do {
            self.sessions = try await self.service.listSessions()
            self.nodes = try await self.service.listNodes()
            self.connectionState = .connected
        } catch {
            self.lastErrorMessage = error.localizedDescription
            throw error
        }
    }

    func disconnect() {
        self.connectionState = .disconnected
        self.sessions = []
        self.nodes = []
        self.transcript = []
        self.selectedSessionKey = nil
        self.lastErrorMessage = nil
    }

    func selectSession(_ sessionKey: String) async throws {
        self.lastErrorMessage = nil
        do {
            self.selectedSessionKey = sessionKey
            self.transcript = try await self.service.chatHistory(sessionKey: sessionKey)
        } catch {
            self.lastErrorMessage = error.localizedDescription
            throw error
        }
    }

    func sendMessage(_ text: String) async throws {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        guard let selectedSessionKey else { throw StoreError.noSelectedSession }

        self.lastErrorMessage = nil
        self.isSendingMessage = true
        defer { self.isSendingMessage = false }
        do {
            _ = try await self.service.sendMessage(sessionKey: selectedSessionKey, text: trimmedText)
            self.transcript = try await self.service.chatHistory(sessionKey: selectedSessionKey)
        } catch {
            self.lastErrorMessage = error.localizedDescription
            throw error
        }
    }

    func abortCurrentRun() async throws {
        guard let selectedSessionKey else { throw StoreError.noSelectedSession }
        self.lastErrorMessage = nil
        do {
            try await self.service.abort(sessionKey: selectedSessionKey)
        } catch {
            self.lastErrorMessage = error.localizedDescription
            throw error
        }
    }

    func resetCurrentSession() async throws {
        guard let selectedSessionKey else { throw StoreError.noSelectedSession }
        self.lastErrorMessage = nil
        do {
            try await self.service.resetSession(sessionKey: selectedSessionKey)
            self.transcript = try await self.service.chatHistory(sessionKey: selectedSessionKey)
        } catch {
            self.lastErrorMessage = error.localizedDescription
            throw error
        }
    }

    func compactCurrentSession() async throws {
        guard let selectedSessionKey else { throw StoreError.noSelectedSession }
        self.lastErrorMessage = nil
        do {
            try await self.service.compactSession(sessionKey: selectedSessionKey)
            self.transcript = try await self.service.chatHistory(sessionKey: selectedSessionKey)
        } catch {
            self.lastErrorMessage = error.localizedDescription
            throw error
        }
    }

    func patchCurrentSession(model: String?, thinking: String?) async throws {
        guard let selectedSessionKey else { throw StoreError.noSelectedSession }
        self.lastErrorMessage = nil
        do {
            try await self.service.patchSession(sessionKey: selectedSessionKey, model: model, thinking: thinking)
            if let model {
                self.selectedModel = model
            }
            if let thinking {
                self.selectedThinking = thinking
            }
        } catch {
            self.lastErrorMessage = error.localizedDescription
            throw error
        }
    }

    func clearError() {
        self.lastErrorMessage = nil
    }

    func clearEventLog() {
        self.eventLog.removeAll()
    }

    func setTransport(_ transport: GatewayTransport) {
        self._transport = transport
    }
}

struct GatewayEvent: Identifiable {
    let id = UUID()
    let type: String
    let message: String
    let timestamp: Date
}

extension GatewayOperatorStore {
    func refreshChannels() async throws {
        self.lastErrorMessage = nil
        do {
            self.channels = try await self.service.listChannels()
        } catch {
            self.lastErrorMessage = error.localizedDescription
            throw error
        }
    }

    func toggleChannel(_ channel: GatewayChannel) async throws {
        self.lastErrorMessage = nil
        do {
            try await self.service.toggleChannel(id: channel.id, enabled: !channel.enabled)
            try await self.refreshChannels()
        } catch {
            self.lastErrorMessage = error.localizedDescription
            throw error
        }
    }
}
