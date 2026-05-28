import Foundation

/// Discovers OpenClaw gateways on the local network via Bonjour/mDNS.
final class BonjourDiscoveryService: GatewayDiscoveryService {
    private let serviceType = "_openclaw-gw._tcp"
    private let domain: String?

    init(domain: String? = "local.") {
        self.domain = domain
    }

    func discoverGatewayBaseURLs() async -> [String] {
        await withCheckedContinuation { continuation in
            var results: [String] = []
            let queue = DispatchQueue(label: "bonjour.discovery")

            let browser = NetServiceBrowser()
            let delegate = BonjourBrowserDelegate { services in
                for service in services {
                    if let url = self.resolveURL(from: service) {
                        results.append(url)
                    }
                }
                queue.async {
                    continuation.resume(returning: results)
                }
            }
            browser.delegate = delegate
            browser.searchForServices(ofType: self.serviceType, inDomain: self.domain ?? "local.")

            // Timeout after 5 seconds
            queue.asyncAfter(deadline: .now() + 5) {
                browser.stop()
                if !results.isEmpty {
                    continuation.resume(returning: results)
                }
            }
        }
    }

    private func resolveURL(from service: NetService) -> String? {
        guard service.port > 0 else { return nil }

        // Use the first resolved address
        if let hostname = service.hostName, !hostname.isEmpty {
            let scheme = "http"
            let port = service.port
            // Remove trailing dot from hostname if present
            let cleanHost = hostname.hasSuffix(".") ? String(hostname.dropLast()) : hostname
            return "\(scheme)://\(cleanHost):\(port)"
        }

        return nil
    }
}

private class BonjourBrowserDelegate: NSObject, NetServiceBrowserDelegate {
    private let onServices: ([NetService]) -> Void

    init(onServices: @escaping ([NetService]) -> Void) {
        self.onServices = onServices
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.resolve(withTimeout: 3.0)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFindDomain domainString: String, moreComing: Bool) {}

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {}

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {}

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemoveDomain domainString: String, moreComing: Bool) {}
}