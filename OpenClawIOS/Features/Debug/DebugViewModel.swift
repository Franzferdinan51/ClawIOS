import Foundation

/// Debug tools for manual RPC inspection.
@Observable
@MainActor
final class DebugViewModel {
    var rpcMethod = ""
    var rpcParams = "{}"
    var rpcResult = ""
    var rpcError = ""
    var isLoading = false

    private let store: GatewayOperatorStore

    init(store: GatewayOperatorStore) {
        self.store = store
    }

    var canSend: Bool {
        let methodNotEmpty = !rpcMethod.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return methodNotEmpty && store.selectedSessionKey != nil
    }

    func sendRPC() async {
        let trimmedMethod = rpcMethod.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMethod.isEmpty else { return }

        guard let transport = store.transport else {
            rpcError = "No transport connected"
            return
        }

        isLoading = true
        rpcResult = ""
        rpcError = ""

        do {
            let data = try await transport.request(
                method: trimmedMethod,
                paramsJSON: rpcParams,
                timeoutSeconds: 15
            )
            if let json = try? JSONSerialization.jsonObject(with: data),
               let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let pretty = String(data: prettyData, encoding: .utf8) {
                rpcResult = pretty
            } else {
                rpcResult = String(data: data, encoding: .utf8) ?? "<binary data>"
            }
        } catch {
            rpcError = error.localizedDescription
        }

        isLoading = false
    }

    func clear() {
        rpcMethod = ""
        rpcParams = "{}"
        rpcResult = ""
        rpcError = ""
    }
}