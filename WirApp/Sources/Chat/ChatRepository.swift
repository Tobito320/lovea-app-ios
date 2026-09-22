protocol ChatRepository: Sendable {
    func messages() async throws -> [ChatMessage]
    func send(body: String) async throws -> ChatMessage
}
