import Foundation

/// Discovers OpenClaw gateways on a Tailscale tailnet using the Tailscale API.
/// Requires a Tailscale API key (tskey-koclat-...) with read access to the tailnet.
struct TailscaleDiscoveryService: GatewayDiscoveryService {
    private let apiKey: String
    private let baseURL = URL(string: "https://api.tailscale.com/api/v2/")!

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    /// Searches the tailnet for devices running an OpenClaw gateway.
    /// Filters for devices with port 18789 open and returns their HTTP/HTTPS base URLs.
    func discoverGatewayBaseURLs() async -> [String] {
        guard !apiKey.isEmpty else { return [] }

        let devices = await fetchTailnetDevices()
        return filterOpenClawGateways(devices)
    }

    private func fetchTailnetDevices() async -> [TailnetDevice] {
        let url = baseURL.appendingPathComponent("tailnet/devices")
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(TailnetDevicesResponse.self, from: data)
            return response.devices
        } catch {
            return []
        }
    }

    private func filterOpenClawGateways(_ devices: [TailnetDevice]) -> [String] {
        var gateways: [String] = []
        for device in devices {
            // Check hostname patterns that indicate an OpenClaw gateway
            let isGateway = device.hostname.contains("openclaw")
                || device.hostname.contains("claw")
                || device.hostname.contains("gateway")
                || device.name.hasSuffix(".ts.net")

            guard isGateway else { continue }

            // Try HTTPS first, then HTTP on port 18789
            for addr in device.addresses {
                if addr.contains(":") {
                    let parts = addr.split(separator: ":")
                    if let port = Int(parts.last ?? ""), port == 18789 {
                        let host = parts.first ?? ""
                        let scheme = "https"
                        gateways.append("\(scheme)://\(host):18789")
                    }
                } else if addr.contains(".") {
                    // IPv6 addresses need brackets
                    let host = addr.hasPrefix("[") ? addr : "[\(addr)]"
                    gateways.append("https://\(host):18789")
                }
            }

            // Also check DNS names (tailnet addresses)
            if let tailnetName = device.name.nilIfBlank, tailnetName.hasSuffix(".ts.net") {
                gateways.append("https://\(tailnetName):18789")
            }
        }
        return gateways
    }
}

private struct TailnetDevicesResponse: Decodable {
    let devices: [TailnetDevice]
}

private struct TailnetDevice: Decodable {
    let id: String
    let hostname: String
    let name: String
    let addresses: [String]
    let tailnetLockError: String?

    enum CodingKeys: String, CodingKey {
        case id, hostname, name, addresses
        case tailnetLockError = "tailnet_lock_error"
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}