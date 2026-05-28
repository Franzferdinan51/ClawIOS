import Foundation

struct GatewayEndpoint: Equatable, Hashable {
    enum ParseError: Error {
        case invalidURL
        case unsupportedScheme
    }

    let httpBaseURL: URL
    let webSocketURL: URL

    init(userInput: String) throws {
        let trimmedInput = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmedInput) else {
            throw ParseError.invalidURL
        }

        guard let scheme = components.scheme?.lowercased() else {
            throw ParseError.invalidURL
        }

        guard scheme == "http" || scheme == "https" else {
            throw ParseError.unsupportedScheme
        }

        components.path = ""
        components.query = nil
        components.fragment = nil

        guard let httpBaseURL = components.url else {
            throw ParseError.invalidURL
        }
        self.httpBaseURL = httpBaseURL

        var webSocketComponents = components
        webSocketComponents.scheme = scheme == "https" ? "wss" : "ws"
        guard let webSocketURL = webSocketComponents.url else {
            throw ParseError.invalidURL
        }
        self.webSocketURL = webSocketURL
    }
}
