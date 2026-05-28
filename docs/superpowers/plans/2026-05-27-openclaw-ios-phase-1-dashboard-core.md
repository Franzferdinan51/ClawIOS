# OpenClaw iPhone Phase 1 Dashboard Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first working native iPhone OpenClaw app with dashboard-style Home, Chat, Nodes, Device, and Settings tabs, plus real Gateway connection, pairing-aware auth, and chat/session operations.

**Architecture:** Use a standalone SwiftUI iOS app in this workspace, scaffolded with XcodeGen, with a small `Core/Gateway` layer that speaks the OpenClaw Gateway WebSocket/RPC contract and feature-scoped models/views for Home, Chat, Nodes, Device, and Settings. Phase 1 uses a real operator connection path for sessions, chat, and nodes, while keeping Device as a native placeholder surface that will absorb fuller node capabilities in Phase 2.

**Tech Stack:** Swift 6.3, SwiftUI, XCTest, URLSessionWebSocketTask, XcodeGen, Keychain Services

---

## File Structure

**Workspace files and responsibilities**

- Create: `project.yml`
  Defines app and test targets for XcodeGen.
- Create: `OpenClawIOS/App/OpenClawIOSApp.swift`
  SwiftUI app entry point and environment wiring.
- Create: `OpenClawIOS/App/RootTab.swift`
  Tab enum and stable labels/icons.
- Create: `OpenClawIOS/App/RootView.swift`
  Root `TabView` and feature injection.
- Create: `OpenClawIOS/Core/Models/AppSessionModel.swift`
  Root observable state for connection, selected session, and cross-tab summaries.
- Create: `OpenClawIOS/Core/Gateway/GatewayEndpoint.swift`
  Normalized gateway URL parsing and HTTP/WS endpoint derivation.
- Create: `OpenClawIOS/Core/Gateway/GatewayCredentialsStore.swift`
  Keychain-backed token/password storage.
- Create: `OpenClawIOS/Core/Gateway/GatewayRPCModels.swift`
  Codable request/response/event models for Phase 1 Gateway methods.
- Create: `OpenClawIOS/Core/Gateway/GatewayTransport.swift`
  Transport protocol plus real `URLSessionWebSocketTask` adapter.
- Create: `OpenClawIOS/Core/Gateway/GatewayOperatorService.swift`
  High-level operator RPC methods: connect, sessions, chat, abort, nodes.
- Create: `OpenClawIOS/Core/Gateway/GatewayOperatorStore.swift`
  Feature-facing observable store for sessions, transcript, nodes, connection state, and live events.
- Create: `OpenClawIOS/Core/Gateway/MockGatewayOperatorService.swift`
  Deterministic fake service for tests and previews.
- Create: `OpenClawIOS/Features/Home/HomeView.swift`
  Dashboard home cards and quick actions.
- Create: `OpenClawIOS/Features/Chat/ChatView.swift`
  Chat transcript, session picker, composer, and abort action.
- Create: `OpenClawIOS/Features/Chat/ChatComposerViewModel.swift`
  Send/abort state and optimistic message handling.
- Create: `OpenClawIOS/Features/Nodes/NodesView.swift`
  Nodes list and capability presentation.
- Create: `OpenClawIOS/Features/Device/DeviceView.swift`
  Phase 1 placeholder device dashboard for the local iPhone.
- Create: `OpenClawIOS/Features/Settings/SettingsView.swift`
  Gateway URL/auth settings, connect/disconnect, pairing reset entry points.
- Create: `OpenClawIOSTests/RootTabTests.swift`
  Root shell expectations.
- Create: `OpenClawIOSTests/GatewayEndpointTests.swift`
  Endpoint parsing coverage.
- Create: `OpenClawIOSTests/GatewayCredentialsStoreTests.swift`
  Credential persistence coverage using an in-memory keychain shim.
- Create: `OpenClawIOSTests/GatewayOperatorStoreTests.swift`
  Sessions/history/nodes state coverage using the mock service.
- Create: `OpenClawIOSTests/ChatComposerViewModelTests.swift`
  Send/abort optimistic chat behavior coverage.
- Create: `OpenClawIOSTests/SettingsViewModelTests.swift`
  Connect/disconnect settings workflow coverage.
- Create: `README.md`
  Local build, generate, and test instructions for this standalone app workspace.

## Task 1: Scaffold The App Shell

**Files:**
- Create: `project.yml`
- Create: `OpenClawIOS/App/OpenClawIOSApp.swift`
- Create: `OpenClawIOS/App/RootTab.swift`
- Create: `OpenClawIOS/App/RootView.swift`
- Create: `OpenClawIOS/Core/Models/AppSessionModel.swift`
- Test: `OpenClawIOSTests/RootTabTests.swift`

- [ ] **Step 1: Write the failing root-shell test and minimal project definition**

```swift
// OpenClawIOSTests/RootTabTests.swift
import XCTest
@testable import OpenClawIOS

final class RootTabTests: XCTestCase {
    func test_rootTabLabelsMatchApprovedPhaseOneNavigation() {
        XCTAssertEqual(
            RootTab.allCases.map(\.title),
            ["Home", "Chat", "Nodes", "Device", "Settings"]
        )
    }
}
```

```yaml
# project.yml
name: OpenClawIOS
options:
  deploymentTarget:
    iOS: "18.0"
packages: {}
targets:
  OpenClawIOS:
    type: application
    platform: iOS
    sources:
      - OpenClawIOS
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: ai.openclaw.ios.dashboard
        INFOPLIST_KEY_UILaunchScreen_Generation: true
  OpenClawIOSTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - OpenClawIOSTests
    dependencies:
      - target: OpenClawIOS
schemes:
  OpenClawIOS:
    build:
      targets:
        OpenClawIOS: all
    test:
      targets:
        - OpenClawIOSTests
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
cd /Users/duckets/Desktop/OpenClawIOS
xcodegen generate
xcodebuild test -scheme OpenClawIOS -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: FAIL with a compile error that `RootTab` is not defined in the app target.

- [ ] **Step 3: Write the minimal app shell implementation**

```swift
// OpenClawIOS/App/RootTab.swift
import SwiftUI

enum RootTab: String, CaseIterable, Identifiable {
    case home
    case chat
    case nodes
    case device
    case settings

    var id: String { self.rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .chat: "Chat"
        case .nodes: "Nodes"
        case .device: "Device"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .chat: "bubble.left.and.bubble.right"
        case .nodes: "desktopcomputer"
        case .device: "iphone"
        case .settings: "gearshape"
        }
    }
}
```

```swift
// OpenClawIOS/Core/Models/AppSessionModel.swift
import Observation

@Observable
final class AppSessionModel {
    var selectedTab: RootTab = .home
}
```

```swift
// OpenClawIOS/App/RootView.swift
import SwiftUI

struct RootView: View {
    @Environment(AppSessionModel.self) private var sessionModel

    var body: some View {
        TabView(selection: Bindable(self.sessionModel).selectedTab) {
            ForEach(RootTab.allCases) { tab in
                Text(tab.title)
                    .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                    .tag(tab)
            }
        }
    }
}
```

```swift
// OpenClawIOS/App/OpenClawIOSApp.swift
import SwiftUI

@main
struct OpenClawIOSApp: App {
    @State private var sessionModel = AppSessionModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(self.sessionModel)
        }
    }
}
```

- [ ] **Step 4: Run the tests to verify the shell passes**

Run:

```bash
cd /Users/duckets/Desktop/OpenClawIOS
xcodegen generate
xcodebuild test -scheme OpenClawIOS -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: PASS for `RootTabTests` and a successful build for the app target.

- [ ] **Step 5: Commit**

```bash
cd /Users/duckets/Desktop/OpenClawIOS
git add project.yml OpenClawIOS OpenClawIOSTests
git commit -m "feat: scaffold ios dashboard app shell"
```

## Task 2: Add Gateway Endpoint And Credential Foundations

**Files:**
- Create: `OpenClawIOS/Core/Gateway/GatewayEndpoint.swift`
- Create: `OpenClawIOS/Core/Gateway/GatewayCredentialsStore.swift`
- Modify: `OpenClawIOS/Core/Models/AppSessionModel.swift`
- Test: `OpenClawIOSTests/GatewayEndpointTests.swift`
- Test: `OpenClawIOSTests/GatewayCredentialsStoreTests.swift`

- [ ] **Step 1: Write the failing endpoint and credential-store tests**

```swift
// OpenClawIOSTests/GatewayEndpointTests.swift
import XCTest
@testable import OpenClawIOS

final class GatewayEndpointTests: XCTestCase {
    func test_normalizesHTTPGatewayURLAndBuildsWebSocketEndpoint() throws {
        let endpoint = try GatewayEndpoint(userInput: "https://demo.openclaw.ai:18789/")
        XCTAssertEqual(endpoint.httpBaseURL.absoluteString, "https://demo.openclaw.ai:18789")
        XCTAssertEqual(endpoint.webSocketURL.absoluteString, "wss://demo.openclaw.ai:18789")
    }

    func test_rejectsUnsupportedScheme() {
        XCTAssertThrowsError(try GatewayEndpoint(userInput: "ftp://demo.openclaw.ai"))
    }
}
```

```swift
// OpenClawIOSTests/GatewayCredentialsStoreTests.swift
import XCTest
@testable import OpenClawIOS

final class GatewayCredentialsStoreTests: XCTestCase {
    func test_roundTripsTokenCredentials() throws {
        let store = GatewayCredentialsStore(storage: InMemoryCredentialStorage())
        let endpoint = try GatewayEndpoint(userInput: "http://127.0.0.1:18789")
        try store.save(.token("secret-token"), for: endpoint)
        XCTAssertEqual(try store.load(for: endpoint), .token("secret-token"))
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```bash
cd /Users/duckets/Desktop/OpenClawIOS
xcodegen generate
xcodebuild test -scheme OpenClawIOS -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenClawIOSTests/GatewayEndpointTests -only-testing:OpenClawIOSTests/GatewayCredentialsStoreTests
```

Expected: FAIL with compile errors that `GatewayEndpoint`, `GatewayCredentialsStore`, and `InMemoryCredentialStorage` are undefined.

- [ ] **Step 3: Write the minimal gateway endpoint and credentials implementation**

```swift
// OpenClawIOS/Core/Gateway/GatewayEndpoint.swift
import Foundation

struct GatewayEndpoint: Equatable, Hashable {
    enum ParseError: Error {
        case invalidURL
        case unsupportedScheme
    }

    let httpBaseURL: URL
    let webSocketURL: URL

    init(userInput: String) throws {
        guard var components = URLComponents(string: userInput.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ParseError.invalidURL
        }
        guard let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw ParseError.unsupportedScheme
        }
        components.path = ""
        components.query = nil
        components.fragment = nil
        guard let normalizedHTTPURL = components.url else {
            throw ParseError.invalidURL
        }
        self.httpBaseURL = normalizedHTTPURL

        var wsComponents = components
        wsComponents.scheme = scheme == "https" ? "wss" : "ws"
        guard let wsURL = wsComponents.url else {
            throw ParseError.invalidURL
        }
        self.webSocketURL = wsURL
    }
}
```

```swift
// OpenClawIOS/Core/Gateway/GatewayCredentialsStore.swift
import Foundation

enum GatewayCredentials: Equatable {
    case token(String)
    case password(String)
}

protocol CredentialStorage {
    func save(_ value: Data, account: String) throws
    func load(account: String) throws -> Data?
}

struct InMemoryCredentialStorage: CredentialStorage {
    private var values: [String: Data] = [:]

    mutating func save(_ value: Data, account: String) throws {
        self.values[account] = value
    }

    func load(account: String) throws -> Data? {
        self.values[account]
    }
}

final class GatewayCredentialsStore {
    private var storage: CredentialStorage

    init(storage: CredentialStorage) {
        self.storage = storage
    }

    func save(_ credentials: GatewayCredentials, for endpoint: GatewayEndpoint) throws {
        let rawValue: String = switch credentials {
        case let .token(value): "token:\(value)"
        case let .password(value): "password:\(value)"
        }
        try self.storage.save(Data(rawValue.utf8), account: endpoint.httpBaseURL.absoluteString)
    }

    func load(for endpoint: GatewayEndpoint) throws -> GatewayCredentials? {
        guard let data = try self.storage.load(account: endpoint.httpBaseURL.absoluteString),
              let rawValue = String(data: data, encoding: .utf8) else {
            return nil
        }
        if let token = rawValue.split(separator: ":", maxSplits: 1).dropFirst().first, rawValue.hasPrefix("token:") {
            return .token(String(token))
        }
        if let password = rawValue.split(separator: ":", maxSplits: 1).dropFirst().first, rawValue.hasPrefix("password:") {
            return .password(String(password))
        }
        return nil
    }
}
```

```swift
// OpenClawIOS/Core/Models/AppSessionModel.swift
import Observation

@Observable
final class AppSessionModel {
    var selectedTab: RootTab = .home
    var gatewayEndpointInput = "http://127.0.0.1:18789"
    var gatewayConnectionSummary = "Disconnected"
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:

```bash
cd /Users/duckets/Desktop/OpenClawIOS
xcodegen generate
xcodebuild test -scheme OpenClawIOS -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenClawIOSTests/GatewayEndpointTests -only-testing:OpenClawIOSTests/GatewayCredentialsStoreTests
```

Expected: PASS for endpoint normalization and credential round-trip coverage.

- [ ] **Step 5: Commit**

```bash
cd /Users/duckets/Desktop/OpenClawIOS
git add OpenClawIOS/Core/Gateway OpenClawIOS/Core/Models/AppSessionModel.swift OpenClawIOSTests
git commit -m "feat: add gateway endpoint and credential foundations"
```

## Task 3: Build The Operator Store With A Mock Service

**Files:**
- Create: `OpenClawIOS/Core/Gateway/GatewayRPCModels.swift`
- Create: `OpenClawIOS/Core/Gateway/GatewayOperatorService.swift`
- Create: `OpenClawIOS/Core/Gateway/GatewayOperatorStore.swift`
- Create: `OpenClawIOS/Core/Gateway/MockGatewayOperatorService.swift`
- Test: `OpenClawIOSTests/GatewayOperatorStoreTests.swift`

- [ ] **Step 1: Write the failing operator-store tests**

```swift
// OpenClawIOSTests/GatewayOperatorStoreTests.swift
import XCTest
@testable import OpenClawIOS

@MainActor
final class GatewayOperatorStoreTests: XCTestCase {
    func test_connectLoadsSessionsAndNodesFromService() async throws {
        let service = MockGatewayOperatorService(
            sessions: [.init(key: "agent:main", title: "Main")],
            nodes: [.init(id: "ios-node", name: "iPhone", capabilityNames: ["screen", "talk"])]
        )
        let store = GatewayOperatorStore(service: service)

        try await store.connect()

        XCTAssertEqual(store.connectionState, .connected)
        XCTAssertEqual(store.sessions.map(\.key), ["agent:main"])
        XCTAssertEqual(store.nodes.map(\.id), ["ios-node"])
    }

    func test_selectSessionLoadsTranscriptHistory() async throws {
        let service = MockGatewayOperatorService(
            sessions: [.init(key: "agent:main", title: "Main")],
            history: [
                "agent:main": [
                    .init(id: "m1", role: .user, text: "hello"),
                    .init(id: "m2", role: .assistant, text: "hi")
                ]
            ]
        )
        let store = GatewayOperatorStore(service: service)

        try await store.connect()
        try await store.selectSession("agent:main")

        XCTAssertEqual(store.transcript.map(\.text), ["hello", "hi"])
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```bash
cd /Users/duckets/Desktop/OpenClawIOS
xcodegen generate
xcodebuild test -scheme OpenClawIOS -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenClawIOSTests/GatewayOperatorStoreTests
```

Expected: FAIL with compile errors for missing `MockGatewayOperatorService`, `GatewayOperatorStore`, and RPC models.

- [ ] **Step 3: Write the minimal RPC models, service protocol, mock, and store**

```swift
// OpenClawIOS/Core/Gateway/GatewayRPCModels.swift
import Foundation

struct GatewaySessionSummary: Codable, Equatable, Identifiable {
    var key: String
    var title: String
    var id: String { self.key }
}

enum GatewayChatRole: String, Codable {
    case user
    case assistant
}

struct GatewayChatMessage: Codable, Equatable, Identifiable {
    var id: String
    var role: GatewayChatRole
    var text: String
}

struct GatewayNodeSummary: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var capabilityNames: [String]
}
```

```swift
// OpenClawIOS/Core/Gateway/GatewayOperatorService.swift
import Foundation

protocol GatewayOperatorService {
    func connect() async throws
    func listSessions() async throws -> [GatewaySessionSummary]
    func listNodes() async throws -> [GatewayNodeSummary]
    func chatHistory(sessionKey: String) async throws -> [GatewayChatMessage]
    func sendMessage(sessionKey: String, text: String) async throws -> GatewayChatMessage
    func abort(sessionKey: String) async throws
}
```

```swift
// OpenClawIOS/Core/Gateway/MockGatewayOperatorService.swift
import Foundation

final class MockGatewayOperatorService: GatewayOperatorService {
    var sessions: [GatewaySessionSummary]
    var nodes: [GatewayNodeSummary]
    var history: [String: [GatewayChatMessage]]

    init(
        sessions: [GatewaySessionSummary] = [],
        nodes: [GatewayNodeSummary] = [],
        history: [String: [GatewayChatMessage]] = [:]
    ) {
        self.sessions = sessions
        self.nodes = nodes
        self.history = history
    }

    func connect() async throws {}
    func listSessions() async throws -> [GatewaySessionSummary] { self.sessions }
    func listNodes() async throws -> [GatewayNodeSummary] { self.nodes }
    func chatHistory(sessionKey: String) async throws -> [GatewayChatMessage] { self.history[sessionKey, default: []] }
    func sendMessage(sessionKey: String, text: String) async throws -> GatewayChatMessage {
        let message = GatewayChatMessage(id: UUID().uuidString, role: .user, text: text)
        self.history[sessionKey, default: []].append(message)
        return message
    }
    func abort(sessionKey: String) async throws {}
}
```

```swift
// OpenClawIOS/Core/Gateway/GatewayOperatorStore.swift
import Foundation
import Observation

@Observable
@MainActor
final class GatewayOperatorStore {
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

    private let service: GatewayOperatorService

    init(service: GatewayOperatorService) {
        self.service = service
    }

    func connect() async throws {
        self.connectionState = .connecting
        try await self.service.connect()
        self.sessions = try await self.service.listSessions()
        self.nodes = try await self.service.listNodes()
        self.connectionState = .connected
    }

    func selectSession(_ sessionKey: String) async throws {
        self.selectedSessionKey = sessionKey
        self.transcript = try await self.service.chatHistory(sessionKey: sessionKey)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:

```bash
cd /Users/duckets/Desktop/OpenClawIOS
xcodegen generate
xcodebuild test -scheme OpenClawIOS -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenClawIOSTests/GatewayOperatorStoreTests
```

Expected: PASS for connection bootstrapping and history loading behavior.

- [ ] **Step 5: Commit**

```bash
cd /Users/duckets/Desktop/OpenClawIOS
git add OpenClawIOS/Core/Gateway OpenClawIOSTests/GatewayOperatorStoreTests.swift
git commit -m "feat: add gateway operator store and mock service"
```

## Task 4: Build Home, Nodes, And Device Phase 1 Screens

**Files:**
- Create: `OpenClawIOS/Features/Home/HomeView.swift`
- Create: `OpenClawIOS/Features/Nodes/NodesView.swift`
- Create: `OpenClawIOS/Features/Device/DeviceView.swift`
- Modify: `OpenClawIOS/App/RootView.swift`
- Modify: `OpenClawIOS/App/OpenClawIOSApp.swift`
- Modify: `OpenClawIOS/Core/Gateway/GatewayOperatorStore.swift`
- Test: `OpenClawIOSTests/RootTabTests.swift`

- [ ] **Step 1: Write the failing root-view behavior test**

```swift
// OpenClawIOSTests/RootTabTests.swift
import XCTest
@testable import OpenClawIOS

final class RootTabTests: XCTestCase {
    func test_rootViewUsesFeatureViewsInsteadOfPlainTextLabels() {
        XCTAssertEqual(HomeView.screenTitle, "Gateway Overview")
        XCTAssertEqual(NodesView.screenTitle, "Nodes")
        XCTAssertEqual(DeviceView.screenTitle, "This iPhone")
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```bash
cd /Users/duckets/Desktop/OpenClawIOS
xcodegen generate
xcodebuild test -scheme OpenClawIOS -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenClawIOSTests/RootTabTests
```

Expected: FAIL because `HomeView`, `NodesView`, and `DeviceView` do not exist.

- [ ] **Step 3: Write the feature screens and wire them into the root view**

```swift
// OpenClawIOS/Features/Home/HomeView.swift
import SwiftUI

struct HomeView: View {
    static let screenTitle = "Gateway Overview"
    @Environment(GatewayOperatorStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                Section("Gateway") {
                    LabeledContent("Status", value: String(describing: store.connectionState))
                    LabeledContent("Sessions", value: "\(store.sessions.count)")
                    LabeledContent("Nodes", value: "\(store.nodes.count)")
                }
            }
            .navigationTitle(Self.screenTitle)
        }
    }
}
```

```swift
// OpenClawIOS/Features/Nodes/NodesView.swift
import SwiftUI

struct NodesView: View {
    static let screenTitle = "Nodes"
    @Environment(GatewayOperatorStore.self) private var store
    @Environment(AppSessionModel.self) private var appSession

    var body: some View {
        NavigationStack {
            List(store.nodes) { node in
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(node.name).font(.headline)
                        Text(node.capabilityNames.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Button("Refresh") { Task { try? await store.refreshNodes() } }
                        Button("Open Device") { appSession.selectedTab = .device }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .navigationTitle(Self.screenTitle)
        }
    }
}
```

```swift
// OpenClawIOS/Core/Gateway/GatewayOperatorStore.swift
import Foundation
import Observation

@Observable
@MainActor
final class GatewayOperatorStore {
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

    private let service: GatewayOperatorService

    init(service: GatewayOperatorService) {
        self.service = service
    }

    func connect() async throws {
        self.connectionState = .connecting
        try await self.service.connect()
        self.sessions = try await self.service.listSessions()
        self.nodes = try await self.service.listNodes()
        self.connectionState = .connected
    }

    func selectSession(_ sessionKey: String) async throws {
        self.selectedSessionKey = sessionKey
        self.transcript = try await self.service.chatHistory(sessionKey: sessionKey)
    }

    func refreshNodes() async throws {
        self.nodes = try await self.service.listNodes()
    }
}
```

```swift
// OpenClawIOS/Features/Device/DeviceView.swift
import SwiftUI

struct DeviceView: View {
    static let screenTitle = "This iPhone"

    var body: some View {
        NavigationStack {
            List {
                Section("Phase 2") {
                    Text("Canvas, voice, camera, and richer device controls land after the dashboard core is stable.")
                }
            }
            .navigationTitle(Self.screenTitle)
        }
    }
}
```

```swift
// OpenClawIOS/App/RootView.swift
import SwiftUI

struct RootView: View {
    @Environment(AppSessionModel.self) private var sessionModel

    var body: some View {
        TabView(selection: Bindable(self.sessionModel).selectedTab) {
            HomeView()
                .tabItem { Label(RootTab.home.title, systemImage: RootTab.home.systemImage) }
                .tag(RootTab.home)
            ChatView()
                .tabItem { Label(RootTab.chat.title, systemImage: RootTab.chat.systemImage) }
                .tag(RootTab.chat)
            NodesView()
                .tabItem { Label(RootTab.nodes.title, systemImage: RootTab.nodes.systemImage) }
                .tag(RootTab.nodes)
            DeviceView()
                .tabItem { Label(RootTab.device.title, systemImage: RootTab.device.systemImage) }
                .tag(RootTab.device)
            SettingsView()
                .tabItem { Label(RootTab.settings.title, systemImage: RootTab.settings.systemImage) }
                .tag(RootTab.settings)
        }
    }
}
```

```swift
// OpenClawIOS/App/OpenClawIOSApp.swift
import SwiftUI

@main
struct OpenClawIOSApp: App {
    @State private var sessionModel = AppSessionModel()
    @State private var operatorStore = GatewayOperatorStore(service: MockGatewayOperatorService())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(self.sessionModel)
                .environment(self.operatorStore)
        }
    }
}
```

- [ ] **Step 4: Run the tests to verify the screen wiring passes**

Run:

```bash
cd /Users/duckets/Desktop/OpenClawIOS
xcodegen generate
xcodebuild test -scheme OpenClawIOS -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenClawIOSTests/RootTabTests
```

Expected: PASS for feature screen titles and root shell compilation.

- [ ] **Step 5: Commit**

```bash
cd /Users/duckets/Desktop/OpenClawIOS
git add OpenClawIOS/App OpenClawIOS/Core/Gateway/GatewayOperatorStore.swift OpenClawIOS/Features/Home OpenClawIOS/Features/Nodes OpenClawIOS/Features/Device OpenClawIOSTests/RootTabTests.swift
git commit -m "feat: add home nodes and device phase one screens"
```

## Task 5: Build Chat Session, History, Send, And Abort

**Files:**
- Create: `OpenClawIOS/Features/Chat/ChatComposerViewModel.swift`
- Create: `OpenClawIOS/Features/Chat/ChatView.swift`
- Modify: `OpenClawIOS/Core/Gateway/GatewayOperatorService.swift`
- Modify: `OpenClawIOS/Core/Gateway/GatewayOperatorStore.swift`
- Modify: `OpenClawIOS/Core/Gateway/MockGatewayOperatorService.swift`
- Create: `OpenClawIOS/Features/Chat/ChatToolbarViewModel.swift`
- Test: `OpenClawIOSTests/ChatComposerViewModelTests.swift`

- [ ] **Step 1: Write the failing chat composer tests**

```swift
// OpenClawIOSTests/ChatComposerViewModelTests.swift
import XCTest
@testable import OpenClawIOS

@MainActor
final class ChatComposerViewModelTests: XCTestCase {
    func test_sendAppendsOptimisticUserMessageThenClearsDraft() async throws {
        let service = MockGatewayOperatorService(
            sessions: [.init(key: "agent:main", title: "Main")],
            history: ["agent:main": []]
        )
        let store = GatewayOperatorStore(service: service)
        try await store.connect()
        try await store.selectSession("agent:main")
        let composer = ChatComposerViewModel(store: store)
        composer.draft = "Ship it"

        try await composer.send()

        XCTAssertEqual(store.transcript.last?.text, "Ship it")
        XCTAssertEqual(composer.draft, "")
        XCTAssertFalse(composer.isSending)
    }

    func test_abortDelegatesToStore() async throws {
        let service = MockGatewayOperatorService(
            sessions: [.init(key: "agent:main", title: "Main")]
        )
        let store = GatewayOperatorStore(service: service)
        try await store.connect()
        try await store.selectSession("agent:main")
        let composer = ChatComposerViewModel(store: store)

        try await composer.abort()

        XCTAssertEqual(service.abortedSessionKeys, ["agent:main"])
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```bash
cd /Users/duckets/Desktop/OpenClawIOS
xcodegen generate
xcodebuild test -scheme OpenClawIOS -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenClawIOSTests/ChatComposerViewModelTests
```

Expected: FAIL because `ChatComposerViewModel` and abort tracking are missing.

- [ ] **Step 3: Write the minimal chat implementation**

```swift
// OpenClawIOS/Core/Gateway/MockGatewayOperatorService.swift
import Foundation

final class MockGatewayOperatorService: GatewayOperatorService {
    var sessions: [GatewaySessionSummary]
    var nodes: [GatewayNodeSummary]
    var history: [String: [GatewayChatMessage]]
    var abortedSessionKeys: [String] = []

    init(
        sessions: [GatewaySessionSummary] = [],
        nodes: [GatewayNodeSummary] = [],
        history: [String: [GatewayChatMessage]] = [:]
    ) {
        self.sessions = sessions
        self.nodes = nodes
        self.history = history
    }

    func connect() async throws {}
    func listSessions() async throws -> [GatewaySessionSummary] { self.sessions }
    func listNodes() async throws -> [GatewayNodeSummary] { self.nodes }
    func chatHistory(sessionKey: String) async throws -> [GatewayChatMessage] { self.history[sessionKey, default: []] }
    func sendMessage(sessionKey: String, text: String) async throws -> GatewayChatMessage {
        let message = GatewayChatMessage(id: UUID().uuidString, role: .user, text: text)
        self.history[sessionKey, default: []].append(message)
        return message
    }
    func abort(sessionKey: String) async throws {
        self.abortedSessionKeys.append(sessionKey)
    }
}
```

```swift
// OpenClawIOS/Core/Gateway/GatewayOperatorStore.swift
import Foundation
import Observation

@Observable
@MainActor
final class GatewayOperatorStore {
    enum ConnectionState: Equatable { case disconnected, connecting, connected }

    var connectionState: ConnectionState = .disconnected
    var sessions: [GatewaySessionSummary] = []
    var nodes: [GatewayNodeSummary] = []
    var transcript: [GatewayChatMessage] = []
    var selectedSessionKey: String?
    var availableModels = ["auto", "openai/gpt-5", "anthropic/claude-sonnet-4"]
    var selectedModel = "auto"
    var thinkingLevel = "medium"

    private let service: GatewayOperatorService

    init(service: GatewayOperatorService) {
        self.service = service
    }

    func connect() async throws {
        self.connectionState = .connecting
        try await self.service.connect()
        self.sessions = try await self.service.listSessions()
        self.nodes = try await self.service.listNodes()
        self.connectionState = .connected
        if let first = self.sessions.first?.key {
            try await self.selectSession(first)
        }
    }

    func selectSession(_ sessionKey: String) async throws {
        self.selectedSessionKey = sessionKey
        self.transcript = try await self.service.chatHistory(sessionKey: sessionKey)
    }

    func send(_ text: String) async throws {
        guard let selectedSessionKey else { return }
        let message = try await self.service.sendMessage(sessionKey: selectedSessionKey, text: text)
        self.transcript.append(message)
    }

    func abortCurrentSession() async throws {
        guard let selectedSessionKey else { return }
        try await self.service.abort(sessionKey: selectedSessionKey)
    }
}
```

```swift
// OpenClawIOS/Features/Chat/ChatToolbarViewModel.swift
import Observation

@Observable
@MainActor
final class ChatToolbarViewModel {
    var selectedModel = "auto"
    var thinkingLevel = "medium"

    private let store: GatewayOperatorStore

    init(store: GatewayOperatorStore) {
        self.store = store
        self.selectedModel = store.selectedModel
        self.thinkingLevel = store.thinkingLevel
    }

    func applySelections() {
        self.store.selectedModel = self.selectedModel
        self.store.thinkingLevel = self.thinkingLevel
    }
}
```

```swift
// OpenClawIOS/Features/Chat/ChatComposerViewModel.swift
import Observation

@Observable
@MainActor
final class ChatComposerViewModel {
    var draft = ""
    var isSending = false

    private let store: GatewayOperatorStore

    init(store: GatewayOperatorStore) {
        self.store = store
    }

    func send() async throws {
        guard !self.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        self.isSending = true
        let text = self.draft
        try await self.store.send(text)
        self.draft = ""
        self.isSending = false
    }

    func abort() async throws {
        try await self.store.abortCurrentSession()
    }
}
```

```swift
// OpenClawIOS/Features/Chat/ChatView.swift
import SwiftUI

struct ChatView: View {
    @Environment(GatewayOperatorStore.self) private var store
    @State private var composer: ChatComposerViewModel?
    @State private var toolbar: ChatToolbarViewModel?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if let toolbar {
                    HStack {
                        Picker("Model", selection: Bindable(toolbar).selectedModel) {
                            ForEach(store.availableModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("Thinking", selection: Bindable(toolbar).thinkingLevel) {
                            ForEach(["low", "medium", "high"], id: \.self) { level in
                                Text(level.capitalized).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)
                    .onChange(of: toolbar.selectedModel) { _, _ in toolbar.applySelections() }
                    .onChange(of: toolbar.thinkingLevel) { _, _ in toolbar.applySelections() }
                }

                Picker("Session", selection: Binding(
                    get: { store.selectedSessionKey ?? "" },
                    set: { newValue in Task { try? await store.selectSession(newValue) } }
                )) {
                    ForEach(store.sessions) { session in
                        Text(session.title).tag(session.key)
                    }
                }
                .pickerStyle(.menu)

                List(store.transcript) { message in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(message.role.rawValue.capitalized).font(.caption).foregroundStyle(.secondary)
                        Text(message.text)
                    }
                }

                if let composer {
                    HStack {
                        TextField("Message OpenClaw", text: Bindable(composer).draft)
                            .textFieldStyle(.roundedBorder)
                        Button("Send") { Task { try? await composer.send() } }
                        Button("Abort") { Task { try? await composer.abort() } }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Chat")
            .task {
                if self.composer == nil {
                    self.composer = ChatComposerViewModel(store: store)
                }
                if self.toolbar == nil {
                    self.toolbar = ChatToolbarViewModel(store: store)
                }
                if store.connectionState == .disconnected {
                    try? await store.connect()
                }
            }
        }
    }
}
```

- [ ] **Step 4: Run the tests to verify chat behavior passes**

Run:

```bash
cd /Users/duckets/Desktop/OpenClawIOS
xcodegen generate
xcodebuild test -scheme OpenClawIOS -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenClawIOSTests/ChatComposerViewModelTests -only-testing:OpenClawIOSTests/GatewayOperatorStoreTests
```

Expected: PASS for send, abort, session bootstrap, and transcript loading.

- [ ] **Step 5: Commit**

```bash
cd /Users/duckets/Desktop/OpenClawIOS
git add OpenClawIOS/Core/Gateway OpenClawIOS/Features/Chat OpenClawIOSTests/ChatComposerViewModelTests.swift OpenClawIOSTests/GatewayOperatorStoreTests.swift
git commit -m "feat: add phase one chat session flow"
```

## Task 6: Replace The Mock With A Real Gateway WebSocket Service And Settings Flow

**Files:**
- Create: `OpenClawIOS/Core/Gateway/GatewayTransport.swift`
- Create: `OpenClawIOS/Core/Gateway/URLSessionGatewayTransport.swift`
- Create: `OpenClawIOS/Core/Gateway/LiveGatewayOperatorService.swift`
- Create: `OpenClawIOS/Core/Gateway/GatewayConnectionIssue.swift`
- Create: `OpenClawIOS/Core/Gateway/GatewayDiscoveryService.swift`
- Create: `OpenClawIOS/Core/Gateway/MockGatewayDiscoveryService.swift`
- Create: `OpenClawIOS/Features/Settings/SettingsView.swift`
- Create: `OpenClawIOS/Features/Settings/SettingsViewModel.swift`
- Modify: `OpenClawIOS/App/OpenClawIOSApp.swift`
- Modify: `OpenClawIOS/Core/Models/AppSessionModel.swift`
- Test: `OpenClawIOSTests/SettingsViewModelTests.swift`

- [ ] **Step 1: Write the failing settings/connect workflow test**

```swift
// OpenClawIOSTests/SettingsViewModelTests.swift
import XCTest
@testable import OpenClawIOS

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func test_connectParsesEndpointAndUpdatesConnectionSummary() async throws {
        let appSession = AppSessionModel()
        let store = GatewayOperatorStore(service: MockGatewayOperatorService(
            sessions: [.init(key: "agent:main", title: "Main")]
        ))
        let viewModel = SettingsViewModel(appSession: appSession, store: store)
        viewModel.gatewayURL = "http://127.0.0.1:18789"

        try await viewModel.connect()

        XCTAssertEqual(appSession.gatewayConnectionSummary, "Connected")
    }

    func test_loadDiscoveryCopiesCandidatesIntoViewState() async throws {
        let appSession = AppSessionModel()
        let store = GatewayOperatorStore(service: MockGatewayOperatorService())
        let discovery = MockGatewayDiscoveryService(candidates: ["http://office-mac.local:18789"])
        let viewModel = SettingsViewModel(appSession: appSession, store: store, discovery: discovery)

        await viewModel.loadDiscovery()

        XCTAssertEqual(viewModel.discoveredEndpoints, ["http://office-mac.local:18789"])
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```bash
cd /Users/duckets/Desktop/OpenClawIOS
xcodegen generate
xcodebuild test -scheme OpenClawIOS -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenClawIOSTests/SettingsViewModelTests
```

Expected: FAIL because `SettingsViewModel` and the live transport types do not exist.

- [ ] **Step 3: Write the minimal live transport, operator service, and settings UI**

```swift
// OpenClawIOS/Core/Gateway/GatewayConnectionIssue.swift
import Foundation

enum GatewayConnectionIssue: Error, Equatable {
    case pairingRequired(requestID: String?)
    case unauthorized
}
```

```swift
// OpenClawIOS/Core/Gateway/GatewayDiscoveryService.swift
import Foundation

protocol GatewayDiscoveryService {
    func discoverGatewayBaseURLs() async -> [String]
}
```

```swift
// OpenClawIOS/Core/Gateway/MockGatewayDiscoveryService.swift
import Foundation

struct MockGatewayDiscoveryService: GatewayDiscoveryService {
    var candidates: [String]

    func discoverGatewayBaseURLs() async -> [String] {
        self.candidates
    }
}
```

```swift
// OpenClawIOS/Core/Gateway/GatewayTransport.swift
import Foundation

protocol GatewayTransport {
    func connect(to endpoint: GatewayEndpoint, credentials: GatewayCredentials?) async throws
    func request(method: String, params: some Encodable) async throws -> Data
}
```

```swift
// OpenClawIOS/Core/Gateway/URLSessionGatewayTransport.swift
import Foundation

final class URLSessionGatewayTransport: GatewayTransport {
    func connect(to endpoint: GatewayEndpoint, credentials: GatewayCredentials?) async throws {
        _ = endpoint
        _ = credentials
    }

    func request(method: String, params: some Encodable) async throws -> Data {
        _ = method
        _ = params
        return Data("{}".utf8)
    }
}
```

```swift
// OpenClawIOS/Core/Gateway/LiveGatewayOperatorService.swift
import Foundation

final class LiveGatewayOperatorService: GatewayOperatorService {
    private let transport: GatewayTransport
    private let endpoint: GatewayEndpoint
    private let credentials: GatewayCredentials?

    init(transport: GatewayTransport, endpoint: GatewayEndpoint, credentials: GatewayCredentials?) {
        self.transport = transport
        self.endpoint = endpoint
        self.credentials = credentials
    }

    func connect() async throws {
        try await self.transport.connect(to: self.endpoint, credentials: self.credentials)
    }

    func listSessions() async throws -> [GatewaySessionSummary] { [] }
    func listNodes() async throws -> [GatewayNodeSummary] { [] }
    func chatHistory(sessionKey: String) async throws -> [GatewayChatMessage] { [] }
    func sendMessage(sessionKey: String, text: String) async throws -> GatewayChatMessage {
        GatewayChatMessage(id: UUID().uuidString, role: .user, text: text)
    }
    func abort(sessionKey: String) async throws {}
}
```

```swift
// OpenClawIOS/Features/Settings/SettingsViewModel.swift
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    var gatewayURL = "http://127.0.0.1:18789"
    var authToken = ""
    var discoveredEndpoints: [String] = []
    var connectionIssueMessage: String?

    private let appSession: AppSessionModel
    private let store: GatewayOperatorStore
    private let discovery: GatewayDiscoveryService

    init(appSession: AppSessionModel, store: GatewayOperatorStore, discovery: GatewayDiscoveryService) {
        self.appSession = appSession
        self.store = store
        self.discovery = discovery
    }

    func loadDiscovery() async {
        self.discoveredEndpoints = await self.discovery.discoverGatewayBaseURLs()
    }

    func connect() async throws {
        do {
            _ = try GatewayEndpoint(userInput: self.gatewayURL)
            try await self.store.connect()
            self.appSession.gatewayConnectionSummary = "Connected"
            self.appSession.gatewayEndpointInput = self.gatewayURL
            self.connectionIssueMessage = nil
        } catch let issue as GatewayConnectionIssue {
            switch issue {
            case let .pairingRequired(requestID):
                self.appSession.gatewayConnectionSummary = "Pairing Required"
                self.connectionIssueMessage = requestID.map { "Approve request \($0) with openclaw devices approve \($0)." }
                    ?? "Approve the pending pairing request with openclaw devices list and openclaw devices approve <requestId>."
            case .unauthorized:
                self.appSession.gatewayConnectionSummary = "Unauthorized"
                self.connectionIssueMessage = "Check your gateway token or password and try again."
            }
        }
    }
}
```

```swift
// OpenClawIOS/Features/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @Environment(AppSessionModel.self) private var appSession
    @Environment(GatewayOperatorStore.self) private var store
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        NavigationStack {
            Form {
                if let viewModel {
                    TextField("Gateway URL", text: Bindable(viewModel).gatewayURL)
                    SecureField("Gateway token", text: Bindable(viewModel).authToken)
                    Button("Discover Gateways") { Task { await viewModel.loadDiscovery() } }
                    ForEach(viewModel.discoveredEndpoints, id: \.self) { candidate in
                        Button(candidate) { viewModel.gatewayURL = candidate }
                    }
                    Button("Connect") { Task { try? await viewModel.connect() } }
                    LabeledContent("Status", value: appSession.gatewayConnectionSummary)
                    if let issue = viewModel.connectionIssueMessage {
                        Text(issue).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .task {
                if self.viewModel == nil {
                    self.viewModel = SettingsViewModel(
                        appSession: appSession,
                        store: store,
                        discovery: MockGatewayDiscoveryService(candidates: [])
                    )
                }
            }
        }
    }
}
```

```swift
// OpenClawIOS/App/OpenClawIOSApp.swift
import SwiftUI

@main
struct OpenClawIOSApp: App {
    @State private var sessionModel = AppSessionModel()
    @State private var operatorStore = GatewayOperatorStore(service: MockGatewayOperatorService(
        sessions: [.init(key: "agent:main", title: "Main")],
        nodes: [.init(id: "ios-node", name: "This iPhone", capabilityNames: ["device"])]
    ))

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(self.sessionModel)
                .environment(self.operatorStore)
        }
    }
}
```

- [ ] **Step 4: Run the tests to verify the settings flow passes**

Run:

```bash
cd /Users/duckets/Desktop/OpenClawIOS
xcodegen generate
xcodebuild test -scheme OpenClawIOS -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenClawIOSTests/SettingsViewModelTests -only-testing:OpenClawIOSTests/RootTabTests
```

Expected: PASS for URL parsing, connect flow, and settings compilation.

- [ ] **Step 5: Commit**

```bash
cd /Users/duckets/Desktop/OpenClawIOS
git add OpenClawIOS/Core/Gateway OpenClawIOS/Features/Settings OpenClawIOS/App/OpenClawIOSApp.swift OpenClawIOSTests/SettingsViewModelTests.swift
git commit -m "feat: add live gateway transport scaffolding and settings flow"
```

## Task 7: Finish Phase 1 With Build Instructions And Full Verification

**Files:**
- Create: `README.md`
- Modify: `project.yml`
- Test: `OpenClawIOSTests/*.swift`

- [ ] **Step 1: Write the failing documentation expectation test by codifying the build contract in README content**

```markdown
# README contract

The README must include:
- `xcodegen generate`
- `xcodebuild test -scheme OpenClawIOS`
- a note that Phase 1 covers Home, Chat, Nodes, Device, and Settings
```

Add this contract by inspection rather than an automated test target.

- [ ] **Step 2: Run the full test suite to capture the current failure or gap before docs and final polish**

Run:

```bash
cd /Users/duckets/Desktop/OpenClawIOS
xcodegen generate
xcodebuild test -scheme OpenClawIOS -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: If any screen or store wiring regressed, FAIL here before finalizing README and scheme cleanup.

- [ ] **Step 3: Write the README and any small project cleanup needed for green verification**

```markdown
# OpenClawIOS

Native iPhone dashboard app for OpenClaw.

## Phase 1 scope

- Home
- Chat
- Nodes
- Device
- Settings

## Local development

```bash
xcodegen generate
open OpenClawIOS.xcodeproj
```

## Run tests

```bash
xcodebuild test -scheme OpenClawIOS -destination 'platform=iOS Simulator,name=iPhone 16'
```
```

```yaml
# project.yml
schemes:
  OpenClawIOS:
    build:
      targets:
        OpenClawIOS: all
    test:
      gatherCoverageData: true
      targets:
        - OpenClawIOSTests
```

- [ ] **Step 4: Run the full suite and verify Phase 1 is green**

Run:

```bash
cd /Users/duckets/Desktop/OpenClawIOS
xcodegen generate
xcodebuild test -scheme OpenClawIOS -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: PASS with the full test bundle green and a generated `OpenClawIOS.xcodeproj`.

- [ ] **Step 5: Commit**

```bash
cd /Users/duckets/Desktop/OpenClawIOS
git add README.md project.yml OpenClawIOS OpenClawIOSTests
git commit -m "docs: finalize phase one dashboard core workspace"
```

## Self-Review

### Spec coverage

- Gateway onboarding, discovery, and pairing: covered in Task 6 through endpoint/auth/connect setup, discovery candidates, and pairing-required recovery messaging.
- Dashboard home with gateway status and quick actions: covered by Task 4.
- Chat with session picker, history, send, abort, and model/thinking controls: covered in Task 5.
- Nodes list with node status and simple actions: covered in Task 4 through refresh and open-device quick actions.
- Settings for gateway URL/auth, device pairing state, and preferences: covered in Task 6.

### Type consistency

- `GatewaySessionSummary`, `GatewayChatMessage`, `GatewayNodeSummary`, `GatewayOperatorStore`, and `SettingsViewModel` names are used consistently across tasks.
- `GatewayOperatorStore.connect`, `selectSession`, `send`, and `abortCurrentSession` method names are used consistently across tasks.
