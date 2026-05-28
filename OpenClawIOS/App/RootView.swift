import SwiftUI

struct RootView: View {
    @Environment(AppSessionModel.self) private var sessionModel
    @Environment(GatewayOperatorStore.self) private var gatewayStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TabView(selection: Bindable(self.sessionModel).selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label(RootTab.home.title, systemImage: RootTab.home.systemImage)
            }
            .tag(RootTab.home)

            NavigationStack {
                ChatView()
            }
            .tabItem {
                Label(RootTab.chat.title, systemImage: RootTab.chat.systemImage)
            }
            .tag(RootTab.chat)

            NavigationStack {
                NodesView()
            }
            .tabItem {
                Label(RootTab.nodes.title, systemImage: RootTab.nodes.systemImage)
            }
            .tag(RootTab.nodes)

            NavigationStack {
                DeviceView()
            }
            .tabItem {
                Label(RootTab.device.title, systemImage: RootTab.device.systemImage)
            }
            .tag(RootTab.device)

            NavigationStack {
                ChannelsView()
            }
            .tabItem {
                Label(RootTab.channels.title, systemImage: RootTab.channels.systemImage)
            }
            .tag(RootTab.channels)

            NavigationStack {
                ActivityView()
            }
            .tabItem {
                Label(RootTab.activity.title, systemImage: RootTab.activity.systemImage)
            }
            .tag(RootTab.activity)

            NavigationStack {
                DebugView()
            }
            .tabItem {
                Label(RootTab.settings.title, systemImage: RootTab.settings.systemImage)
            }
            .tag(RootTab.settings)
        }
        .tint(OpenClawTheme.primary)
        .task {
            await self.gatewayStore.bootstrap()
        }
    }
}