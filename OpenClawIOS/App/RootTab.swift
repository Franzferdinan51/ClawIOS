import SwiftUI

enum RootTab: String, CaseIterable, Identifiable {
    case home
    case chat
    case nodes
    case device
    case channels
    case activity
    case settings

    var id: String { self.rawValue }

    var title: String {
        switch self {
        case .home:
            "Home"
        case .chat:
            "Chat"
        case .nodes:
            "Nodes"
        case .device:
            "Device"
        case .channels:
            "Channels"
        case .activity:
            "Activity"
        case .settings:
            "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            "house"
        case .chat:
            "bubble.left.and.bubble.right"
        case .nodes:
            "desktopcomputer"
        case .device:
            "iphone"
        case .channels:
            "bubble.left.and.bubble.right.fill"
        case .activity:
            "ant.fill"
        case .settings:
            "gearshape"
        }
    }
}
