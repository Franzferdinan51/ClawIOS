import Foundation

/// Aggregates discovery from multiple sources: Bonjour (local) and Tailscale (remote).
/// Returns deduplicated URLs with the source identified.
struct AggregateDiscoveryService: GatewayDiscoveryService {
    private let bonjourService: BonjourDiscoveryService
    private let tailscaleService: TailscaleDiscoveryService?

    init(tailscaleApiKey: String?) {
        self.bonjourService = BonjourDiscoveryService()
        self.tailscaleService = tailscaleApiKey?.nilIfBlank.map { TailscaleDiscoveryService(apiKey: $0) }
    }

    func discoverGatewayBaseURLs() async -> [String] {
        let bonjourResults = await bonjourService.discoverGatewayBaseURLs()
        let tailscaleResults = await tailscaleService?.discoverGatewayBaseURLs() ?? []

        var seen: Set<String> = []
        var results: [String] = []

        for url in bonjourResults {
            if !seen.contains(url) {
                seen.insert(url)
                results.append(url)
            }
        }

        for url in tailscaleResults {
            if !seen.contains(url) {
                seen.insert(url)
                results.append(url)
            }
        }

        return results
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}