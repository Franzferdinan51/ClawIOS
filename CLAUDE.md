# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Generate Xcode project from project.yml
xcodegen generate

# Build (substitute your simulator name)
xcodebuild -scheme OpenClawIOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Run tests
xcodebuild test -scheme OpenClawIOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

**Prerequisites:** XcodeGen must be installed (`brew install xcodegen`). iOS 18.0+ and Xcode 16+ required.

## Architecture

**State flow:** `OpenClawIOSApp` (entry point) wires `AppSessionModel` + `GatewayOperatorStore` into the SwiftUI environment via `.environment()`. All features access these via `@Environment`.

**Gateway layer has three tiers:**

1. `GatewayTransport` — Protocol for WebSocket JSON-RPC. `GatewayWebSocketTransport` is the live implementation using `URLSessionWebSocketTask`. A mock exists for unit tests.

2. `GatewayOperatorService` — Protocol defining RPC operations (`connect`, `listSessions`, `chatHistory`, `sendMessage`, `abort`, `resetSession`, `compactSession`, `patchSession`, `listChannels`, `toggleChannel`). `LiveGatewayOperatorService` is the real implementation; `MockGatewayOperatorService` is the test double.

3. `GatewayOperatorStore` — `@Observable @MainActor` central store holding `sessions`, `nodes`, `transcript`, `connectionState`, `selectedSessionKey`, `selectedModel`, `selectedThinking`, `isAgentRunning`, `lastAgentActivity`, `eventLog`, `channels`, and a `transport` reference for debug RPC calls. All features read from this store.

**Feature views are purely presentational** — they bind to `GatewayOperatorStore` and `AppSessionModel` via environment injection. No business logic lives in views.

**WebSocket protocol:** The gateway at `host:18789` uses challenge/response auth with Curve25519 device identity stored in Keychain.

## Project Structure

```
OpenClawIOS/          # Main app target
├── App/              # OpenClawIOSApp.swift entry point, RootTab enum, RootView TabView, OpenClawTheme
├── Core/
│   ├── Models/       # AppSessionModel (selectedTab, gateway URL, tailscaleApiKey, credentialsStore)
│   ├── Device/       # DeviceService (voice, canvas, camera, location for iPhone node)
│   ├── Gateway/      # All gateway communication (transport, service, store, RPC models, discovery)
│   └── Theme/        # OpenClawTheme (claw-orange #f97316 brand colors)
└── Features/         # Home, Chat, Nodes, Device, Channels, Activity, Debug, Settings
OpenClawIOSTests/     # Unit tests
project.yml           # XcodeGen config
```

## Tab Order (RootTab)

`home → chat → nodes → device → channels → activity → debug → settings`

## Discovery Services

Discovery is driven by `GatewayDiscoveryService` protocol with three implementations:

- `BonjourDiscoveryService` — Local network discovery via mDNS/Bonjour (`_openclaw-gw._tcp` service type)
- `TailscaleDiscoveryService` — Remote access via Tailscale API (`tskey-koclat-...` API key). Queries `api.tailscale.com/api/v2/tailnet/devices` and filters for gateway hosts (port 18789)
- `AggregateDiscoveryService` — Combines Bonjour + Tailscale results, deduplicates by URL

`AppSessionModel.tailscaleApiKey` stores the Tailscale API key.

## Gateway RPC Methods

| Method | Parameters | Purpose |
|--------|------------|---------|
| `connect` | — | Device auth handshake |
| `sessions.list` | — | List all sessions |
| `sessions.patch` | `key`, `model?`, `thinking?` | Patch session model/thinking |
| `chat.send` | `sessionKey`, `message`, `thinking`, `timeoutMs` | Send message, start agent run |
| `chat.history` | `sessionKey` | Get message history |
| `chat.abort` | `sessionKey` | Abort current run |
| `sessions.reset` | `key` | Clear session history |
| `sessions.compact` | `key` | Context summarization |
| `node.list` | — | List connected nodes |
| `channels.list` | — | List messaging channels |
| `channels.toggle` | `channelId`, `enabled` | Enable/disable channel |

## Key Types

- `GatewayEndpoint` — Parses user URL input, derives WebSocket URL (`http` → `wss`)
- `GatewayCredentials` — Token + password for gateway auth
- `GatewaySessionSummary` — `{ key, title }` for session picker
- `GatewayChatMessage` — `{ id, role: .user/.agent, text }`
- `GatewayNodeSummary` — `{ id, name, capabilityNames }`
- `GatewayChannel` — `{ id, name, platform, status, enabled }`
- `GatewayEvent` — `{ id, type, message, timestamp }` for event log

## Testing Pattern

Each `*Tests.swift` file has a corresponding type under `OpenClawIOS/`. Tests use `MockGatewayOperatorService` and direct instantiation of stores/services. Run a single test file:

```bash
xcodebuild test -scheme OpenClawIOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:OpenClawIOSTests/GatewayEndpointTests
```