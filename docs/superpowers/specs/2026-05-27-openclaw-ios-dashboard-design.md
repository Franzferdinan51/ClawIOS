# OpenClaw iPhone Dashboard App Design

Status: Draft based on source inspection and explicit assumptions pending user confirmation.

## Goal

Build an iPhone app for OpenClaw that starts from the existing iOS node concepts in the OpenClaw docs and upstream `apps/ios` code, but adds a native operator experience with chat and dashboard-style interaction similar to the OpenClaw web Control UI.

## Current Source Grounding

The design below is based on the current upstream OpenClaw surfaces:

- `apps/ios` already exists as a native iPhone app and currently behaves primarily as a `role: node` client.
- `apps/ios/Sources/Chat/IOSGatewayChatTransport.swift` already speaks operator-style Gateway RPCs such as `chat.send`, `chat.history`, `sessions.list`, and `sessions.reset`.
- `apps/ios/Sources/RootTabs.swift` shows the current app shell is node-oriented with `Screen`, `Voice`, and `Settings`.
- `docs/platforms/ios.md` describes the existing iOS app as an internal-preview node app that pairs to a Gateway over WebSocket, exposes canvas/screen/camera/location/talk/voice-wake, and supports manual host plus discovery paths.
- `docs/web/control-ui.md` describes the browser dashboard as a Gateway operator surface for chat, sessions, nodes, cron, config, logs, and approvals.

## Product Assumptions

Because the workspace is empty and the user has not yet chosen a product direction, this draft makes these assumptions:

1. The desired app should feel native on iPhone, not just embed the current web dashboard in a web view.
2. The desired app should preserve the useful node capabilities from the current iOS docs and upstream app.
3. The first meaningful version should prioritize chat and dashboard interaction over rarely used admin surfaces.
4. The app can target the same modern iOS baseline as upstream OpenClaw iOS, which is currently iOS 18 in `apps/ios/project.yml`.

If any of these are wrong, the architecture still supports narrowing to dashboard-only or node-only later.

## Approaches Considered

### Approach 1: Thin web-dashboard wrapper

Use a mostly native shell for auth/pairing/settings and load the existing Control UI in a `WKWebView`.

Pros:

- Fastest path to parity with the current dashboard.
- Reuses existing dashboard behavior with minimal RPC redesign.
- Lower initial native UI workload.

Cons:

- Does not feel truly native.
- Mobile dashboard ergonomics remain constrained by the browser UI architecture.
- Harder to integrate deeply with iPhone-native features like push state, share sheet flows, live activities, and voice.

### Approach 2: New native operator-only app

Build a clean iPhone dashboard app focused only on operator workflows: chat, sessions, nodes, approvals, status, and settings.

Pros:

- Cleanest product story for a mobile dashboard.
- Smaller scope than a full hybrid app.
- Easier to optimize navigation and compose native iPhone interactions.

Cons:

- Loses alignment with the existing iOS node docs and app identity.
- Would require a second app or a later merge for canvas, talk mode, camera, screen, and voice-wake features.

### Approach 3: Hybrid native app built on the upstream iOS app

Extend the existing upstream iOS app into a hybrid experience: a native dashboard/operator surface plus the existing node capabilities in one iPhone app.

Pros:

- Best match for the user request: based on the iOS app docs, but with chat and interaction closer to the web dashboard.
- Reuses the current pairing, transport, node, and voice groundwork already in upstream iOS code.
- Keeps room for dashboard chat, sessions, nodes, approvals, share flows, canvas, and live device capabilities in one app.

Cons:

- Largest product scope.
- Requires careful separation between operator session state and node session state.
- Needs a deliberate navigation redesign instead of simply bolting chat onto the current tabs.

## Recommendation

Recommend **Approach 3: Hybrid native app built on the upstream iOS app**.

This is the strongest fit for the request because it keeps the real OpenClaw iOS identity while moving the user-facing experience closer to the web dashboard. The app should become a mobile command center for OpenClaw, not just a passive node, but it should still expose the iPhone-specific capabilities that make an iPhone app worth having.

## Scope Decomposition

This project is too broad to implement safely as one undifferentiated feature. It should be treated as a phased product with one shared architecture.

### Phase 1: Native dashboard core

Ship the first version with:

- Gateway onboarding, discovery, and pairing.
- Dashboard home with gateway status and quick actions.
- Chat with session picker, history, send, abort, and model/thinking controls where supported.
- Nodes list with node status and simple actions.
- Settings for gateway URL/auth, device pairing state, and app preferences.

### Phase 2: Node capability integration

Add or re-home:

- Canvas/screen surface.
- Voice/talk controls.
- Camera and media capture flows.
- Share sheet into chat/session.
- Live activity and push-backed operator status.

### Phase 3: Advanced dashboard surfaces

Add:

- Exec approvals.
- Logs and diagnostics.
- Config editing.
- Cron/skills/admin surfaces if they prove useful on mobile.

## User Experience Design

### App identity

The iPhone app should feel like a compact native OpenClaw control room:

- fast operator chat
- clear gateway health
- lightweight session switching
- visible node/device state
- one-tap access to iPhone-native capabilities

It should not try to mirror every Control UI screen one-for-one on day one. Mobile needs prioritization and compression.

### Tab structure

Recommended root tab shell:

1. `Home`
2. `Chat`
3. `Nodes`
4. `Device`
5. `Settings`

#### Home

Purpose:

- show current gateway connection state
- show paired gateway identity
- expose quick actions into active session, voice, approvals, and node controls
- summarize recent agent activity and node health

Main content:

- gateway status card
- active session summary
- pending approvals card
- connected nodes snapshot
- quick-launch actions

#### Chat

Purpose:

- provide the primary operator experience, similar to Control UI chat

Main content:

- active agent/session header
- transcript view
- composer with send/abort
- optional attachment entry points
- session management actions like new, reset, compact

Day-one parity target:

- `chat.history`
- `chat.send`
- `chat.abort`
- `sessions.list`
- `sessions.reset`
- `sessions.compact`

Stretch but still near-term:

- live event stream for agent/tool updates
- thinking/model picker based on available session patch support

#### Nodes

Purpose:

- present the ecosystem around the gateway, especially the current iPhone device and any other nodes

Main content:

- node list and connection state
- capability badges
- quick actions like open screen/canvas, test talk, refresh state

#### Device

Purpose:

- preserve and modernize the current iPhone node-specific experience

Main content:

- local iPhone capability status
- canvas/screen surface
- voice/talk controls
- camera/location/privacy state

#### Settings

Purpose:

- networking, auth, pairing, permissions, theme, debug, and support

Main content:

- gateway URL/discovery settings
- auth token or password configuration
- device identity and pairing reset
- permission status
- diagnostics links

## Architecture

### High-level shape

The app should be a SwiftUI app with a small number of clearly bounded feature areas:

- `AppShell`
- `GatewayCore`
- `Dashboard`
- `NodeFeatures`
- `Settings`

### AppShell

Responsibilities:

- own root tabs, navigation stacks, sheet routing, and top-level environment injection
- decide whether the app is onboarding, connected, degraded, or ready

### GatewayCore

Responsibilities:

- discovery
- pairing and trust
- credential storage
- WebSocket session lifecycle
- auth bootstrap
- reconnect policy
- event fan-out

This layer should wrap the lower-level OpenClaw transport so the UI does not talk raw RPC everywhere.

### Dashboard

Responsibilities:

- session list and selection
- transcript loading
- sending and aborting runs
- active run state
- activity summaries
- node summaries and approvals summaries for home cards

This should be native SwiftUI, not a web wrapper.

### NodeFeatures

Responsibilities:

- existing screen, voice, camera, location, and canvas capabilities
- device permission orchestration
- background-aware device state reporting where already supported

### Settings

Responsibilities:

- gateway target configuration
- auth configuration
- pairing reset
- debug and support surfaces

## Data Flow

### Connection flow

1. App launches.
2. `GatewayCore` restores saved gateway target and auth state from keychain or settings store.
3. App attempts discovery or direct connection.
4. If pairing or trust approval is required, onboarding or an inline approval state is shown.
5. On successful connection, `GatewayCore` publishes a live operator session plus node/device status stream.
6. `Dashboard` and `NodeFeatures` subscribe to shared app state rather than creating separate socket stacks when possible.

### Chat flow

1. Chat screen selects the active session.
2. App loads `sessions.list`.
3. App requests `chat.history` for the selected session.
4. User sends a message through `chat.send`.
5. App tracks the returned `runId`.
6. Live events update the transcript and activity state.
7. User can abort with `chat.abort`.
8. Transcript refresh reconciles optimistic state with canonical history.

### Node control flow

1. Device and Nodes screens read current node capability state from shared app state.
2. User triggers node actions through typed service APIs.
3. Services map those actions to `node.invoke` or related Gateway methods.
4. UI receives local optimistic state plus confirmed result events.

## State Ownership

Use modern SwiftUI state boundaries similar to the upstream app:

- root app-owned state in one or more injected observable models
- feature-local view state in `@State`
- explicit dependency injection for services and stores

Recommended core models:

- `AppSessionModel`
- `GatewayConnectionModel`
- `DashboardModel`
- `NodeFeatureModel`
- `SettingsModel`

Avoid a single giant app model that owns every dashboard and node behavior.

## Error Handling

The mobile dashboard must make gateway problems understandable quickly.

Important error classes:

- gateway unreachable
- auth token/password invalid
- pairing required
- TLS trust changed
- scope approval required
- session history too large or temporarily unavailable
- node capability unavailable
- microphone/camera/location permission denied

UI strategy:

- show status banners for transient connection issues
- keep the last good data visible when possible
- route security-sensitive problems to focused recovery actions
- never silently discard send failures or pairing upgrades

## Security Model

The app is an admin surface, similar to the web dashboard, and must be treated that way.

Requirements:

- store secrets in Keychain
- prefer explicit user-visible gateway targets
- preserve pairing approval semantics from OpenClaw
- keep operator and node roles explicit in the code
- avoid logging raw secrets or long-lived tokens
- make destructive actions clearly confirmed

## Testing Strategy

### Unit tests

Cover:

- gateway auth and endpoint parsing
- session list and transcript mapping
- optimistic chat merge behavior
- reconnect and degradation states
- node capability routing
- permission state reducers

### Integration tests

Cover:

- pairing-required first connection
- successful chat send and streamed updates
- session switch and transcript refresh
- abort flow
- node list and capability display

### UI smoke tests

Cover:

- onboarding to connected dashboard
- opening chat and sending a message
- switching tabs with degraded gateway state

## Initial File Structure Recommendation

When implementation begins, prefer a structure like:

```text
OpenClawIOS/
  docs/
    superpowers/
      specs/
      plans/
  OpenClawApp/
    App/
    Core/
      Gateway/
      Models/
      DesignSystem/
    Features/
      Home/
      Chat/
      Nodes/
      Device/
      Settings/
    Tests/
```

If instead we fork or mirror upstream `apps/ios`, the same feature split should be applied within that project layout rather than inventing a second architecture.

## Open Questions To Confirm Before Implementation

1. Should the first release be dashboard-first or fully hybrid from day one?
2. Should chat support attachments immediately, or text-first for the first milestone?
3. Should the app include advanced admin surfaces like config/logs/cron in the first mobile version?
4. Do we want the final repo to be a standalone iOS app project here, or a fork/adaptation of upstream `apps/ios`?

## Decision

Unless the user says otherwise, proceed with:

- native SwiftUI app
- hybrid product direction
- dashboard core first
- reuse upstream OpenClaw iOS concepts and RPC surfaces
- no full-dashboard web wrapper as the primary UX

## Next Step

After user review, write a detailed implementation plan for **Phase 1: Native dashboard core** and then execute it with test-first slices.
