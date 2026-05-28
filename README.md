# OpenClaw

Native iPhone dashboard app for [OpenClaw](https://github.com/openclaw/openclaw). Connects to a local OpenClaw Gateway over WebSocket to provide operator chat, session management, node monitoring, device control, and messaging channels — mirroring the OpenClaw web dashboard on your iPhone.

## About OpenClaw

OpenClaw is a local AI agent platform with a gateway/agent architecture:

- **Gateway** — Local daemon managing sessions, channels, tools, and events. Run via `openclaw gateway --port 18789`
- **Agent** — AI assistant operating within a workspace (`~/.openclaw/workspace`) with injected prompt files (AGENTS.md, SOUL.md, TOOLS.md)
- **Control UI** — Web dashboard for gateway management; this iOS app provides the same functionality on mobile

The gateway exposes RPC methods over WebSocket (`sessions.list`, `chat.send`, `node.list`, etc.) that this app consumes.

## Features

### Home Tab
- Gateway connection status (connected/disconnected/connecting)
- Session count and node count summary cards
- Recent sessions quick-access list
- Active chat preview with latest message
- Agent activity indicator (shows when agent is thinking/running)
- Quick actions for navigation and refresh

### Chat Tab
- Session picker (segmented control for switching between sessions)
- Model selector (Default, Claude Sonnet, Claude Opus, GPT-4o)
- Thinking level control (Low, Medium, High)
- Full message history with user/agent bubbles
- Send message composer with multi-line support
- Session actions: Abort, Compact, Reset

### Nodes Tab
- List of all connected gateway nodes
- Node capability badges (device, voice, canvas, etc.)
- Node status indicators

### Device Tab
- iPhone as a gateway node with local capabilities:
  - Voice input and wake word detection
  - Audio level meter when listening
  - Canvas preview via WKWebView
  - Camera access and snapshot handoff
  - Location context for agent
  - Node registration with capability advertisement

### Channels Tab
- All connected messaging platforms (WhatsApp, Telegram, Slack, Discord, Signal, iMessage, IRC, Microsoft Teams, Matrix, etc.)
- Per-channel status indicators
- Enable/disable channel toggles
- Message count per channel

### Activity Tab
- Real-time scrolling event log
- Agent tool calls, thinking chains, and current actions
- Color-coded event types (tool, thinking, message, error, session, connect/disconnect)
- Auto-scroll with toggle, manual scroll, and clear

### Debug Tab
- RPC tester — send any gateway RPC method with custom JSON params
- Event log viewer (same log as Activity tab)
- Gateway health summary (connection state, session count, node count, last error)
- Copy log, copy device ID

### Settings Tab
- Gateway URL configuration (manual entry)
- Auth token input (stored securely in Keychain)
- **Scan Local** — Bonjour/mDNS discovery on your LAN (`_openclaw-gw._tcp`)
- **Scan Tailnet** — Tailscale API discovery for remote access when away from home
- Tailscale API key field (get from tailscale.com/settings/api)
- Connection status display

## Prerequisites

- iOS 18.0+
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/xcodegen) installed (`brew install xcodegen`)
- An OpenClaw Gateway running (`openclaw gateway --port 18789`)

## Getting Started

```bash
# Generate the Xcode project
xcodegen generate

# Open in Xcode
open OpenClawIOS.xcodeproj

# Build from command line
xcodebuild -scheme OpenClawIOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Running Tests

```bash
xcodegen generate
xcodebuild test -scheme OpenClawIOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Gateway Connection

The app connects to your OpenClaw Gateway via WebSocket (default port **18789**). Multiple discovery methods:

1. **Bonjour** — Auto-discovers `_openclaw-gw._tcp` services on your local network
2. **Tailscale** — Queries `api.tailscale.com/api/v2/tailnet/devices` for tailnet addresses with port 18789 open — works from anywhere
3. **Manual** — Enter host:port directly in Settings

**Pairing**: When connecting for the first time, the gateway will emit a pairing request. Approve it on the host:

```bash
openclaw devices approve <requestId>
```

## Architecture

```
OpenClawIOS/
├── App/
│   ├── OpenClawIOSApp.swift       # App entry point
│   ├── RootTab.swift              # Tab enum (home, chat, nodes, device, channels, activity, settings)
│   ├── RootView.swift            # TabView shell with NavigationStack per tab
│   └── OpenClawTheme.swift       # Brand colors (claw-orange #f97316), card/surface palette
├── Core/
│   ├── Models/
│   │   └── AppSessionModel.swift # Root observable state (selectedTab, gateway URL, tailscaleApiKey)
│   ├── Device/
│   │   └── DeviceService.swift   # Voice (AVAudioEngine), canvas (WKWebView), camera, location
│   ├── Gateway/
│   │   ├── GatewayEndpoint.swift           # URL/WS parsing
│   │   ├── GatewayCredentialsStore.swift   # Keychain storage
│   │   ├── GatewayRPCModels.swift          # Session, ChatMessage, Node, Channel types
│   │   ├── GatewayTransport.swift          # WebSocket transport
│   │   ├── GatewayOperatorService.swift    # RPC protocol + live implementation
│   │   ├── GatewayOperatorStore.swift      # Observable state hub (sessions, nodes, transcript, eventLog, channels)
│   │   ├── MockGatewayOperatorService.swift
│   │   ├── GatewayDiscoveryService.swift   # Protocol + Mock
│   │   ├── BonjourDiscoveryService.swift  # Local mDNS/Bonjour
│   │   ├── TailscaleDiscoveryService.swift # Tailnet device discovery via Tailscale API
│   │   └── AggregateDiscoveryService.swift # Bonjour + Tailscale combined
│   └── Theme/
│       └── OpenClawTheme.swift  # Brand colors, card backgrounds, View extension
└── Features/
    ├── Home/HomeView.swift
    ├── Chat/ChatView.swift
    ├── Nodes/NodesView.swift
    ├── Device/DeviceView.swift
    ├── Channels/ChannelsView.swift
    ├── Activity/ActivityView.swift
    ├── Debug/DebugView.swift
    ├── Debug/DebugViewModel.swift
    └── Settings/SettingsView.swift
```

**Key patterns:**
- `@Observable` / `@State` for reactive state management
- Environment injection for cross-tab state sharing
- Protocol-based services for testability (MockGatewayOperatorService)
- `GatewayOperatorStore` as central state hub for all gateway interactions

## Gateway RPC Reference

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

## iOS Platform Documentation

For more details on the iOS platform integration, see the [OpenClaw iOS documentation](https://docs.openclaw.ai/platforms/ios/).

## Future Enhancements

- Canvas rendering via WKWebView (live sync)
- Voice wake word detection (On-device Siri)
- Talk mode with PTT commands
- Push notifications via APNs relay
- Session history with search
- Multi-gateway support