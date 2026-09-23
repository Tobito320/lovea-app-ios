import Foundation

/// What `Raum` needs from a socket. Production uses `WebSocketTransport`; tests inject a fake
/// that stores the closures and calls `nachricht` directly to simulate server messages.
protocol RaumTransport: Sendable {
    func verbinden(
        url: URL,
        headers: [String: String],
        nachricht: @escaping @Sendable (String) async -> Void,
        getrennt: @escaping @Sendable (Error?) async -> Void
    )
    func senden(_ text: String)
    func trennen()
}

/// One `URLSessionWebSocketTask`, a loop that awaits `receive()` and forwards text frames.
// ponytail: `task` is only ever touched from Raum's MainActor call sites, so a real lock
// buys nothing here — @unchecked documents that assumption instead of hiding it.
final class WebSocketTransport: RaumTransport, @unchecked Sendable {
    private var task: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)

    func verbinden(
        url: URL,
        headers: [String: String],
        nachricht: @escaping @Sendable (String) async -> Void,
        getrennt: @escaping @Sendable (Error?) async -> Void
    ) {
        var request = URLRequest(url: url)
        for (feld, wert) in headers { request.setValue(wert, forHTTPHeaderField: feld) }
        let neu = session.webSocketTask(with: request)
        // C-1: the default is 1 MB. A bigger frame made receive() throw and reconnect forever with
        // the same cursor. The server keeps pages near 512 KB; this is the headroom for one big op.
        neu.maximumMessageSize = 32 * 1024 * 1024
        task = neu
        neu.resume()
        Task { await Self.empfangsSchleife(neu, nachricht: nachricht, getrennt: getrennt) }
    }

    func senden(_ text: String) {
        task?.send(.string(text)) { _ in }
    }

    func trennen() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private static func empfangsSchleife(
        _ task: URLSessionWebSocketTask,
        nachricht: @escaping @Sendable (String) async -> Void,
        getrennt: @escaping @Sendable (Error?) async -> Void
    ) async {
        while true {
            do {
                let empfangen = try await task.receive()
                if case .string(let text) = empfangen { await nachricht(text) }
            } catch {
                await getrennt(error)
                return
            }
        }
    }
}
