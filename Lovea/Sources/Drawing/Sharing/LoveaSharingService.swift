// ponytail: Level 2 eingefroren bis Level-1-Abnahme
import Combine
import Foundation
import UIKit

struct SharedSnapshot: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let artworkID: String?
    let name: String
    let bild: String
    let von: String
    let geaendert: String
}

struct SharedLiveArtwork: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let artworkID: String
    let projectID: String?
    let projectName: String?
    let name: String
    let bild: String
    let von: String
    let geaendert: String
}

struct SharedProject: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let projectID: String
    let name: String
    let von: String
    let geaendert: String
}

private struct SharingInbox: Codable, Sendable {
    let projekte: [SharedProject]
    let live: [SharedLiveArtwork]
    let snapshots: [SharedSnapshot]
}

private struct APIErrorBody: Codable {
    let fehler: String?
}

enum SharingConnectionState: Equatable {
    case checking
    case disconnected
    case connected
    case failed(String)
}

@MainActor
final class LoveaSharingService: ObservableObject {
    @Published private(set) var state: SharingConnectionState = .checking
    @Published private(set) var snapshots: [SharedSnapshot] = []
    @Published private(set) var liveArtworks: [SharedLiveArtwork] = []
    @Published private(set) var sharedProjects: [SharedProject] = []

    let person: LoveaPerson
    let baseURL: URL
    private let session: URLSession
    private var refreshTask: Task<Void, Never>?

    init(
        person: LoveaPerson,
        baseURL: URL = URL(string: "https://wir-live.pages.dev")!,
        session: URLSession = .shared
    ) {
        self.person = person
        self.baseURL = baseURL
        self.session = session
    }

    deinit {
        refreshTask?.cancel()
    }

    func checkSession() async {
        state = .checking
        do {
            _ = try await request(path: "ich", method: "GET", body: Optional<String>.none)
            state = .connected
            await refresh()
        } catch let error as SharingError where error.status == 401 {
            state = .disconnected
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func connect(month: Int, day: Int, pin: String) async throws {
        state = .checking
        do {
            _ = try await request(path: "schloss", method: "POST", body: ["monat": month, "tag": day])
            _ = try await request(
                path: "anmelden",
                method: "POST",
                body: ["person": person.apiID, "pin": pin]
            )
            state = .connected
            await refresh()
        } catch {
            state = .failed(error.localizedDescription)
            throw error
        }
    }

    func refresh() async {
        guard state == .connected else { return }
        do {
            let data = try await request(path: "freigaben", method: "GET", body: Optional<String>.none)
            let inbox = try JSONDecoder().decode(SharingInbox.self, from: data)
            snapshots = inbox.snapshots
            liveArtworks = inbox.live
            sharedProjects = inbox.projekte
        } catch let error as SharingError where error.status == 401 {
            state = .disconnected
            stopAutoRefresh()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func sendSnapshot(document: ArtworkDocument, image: UIImage) async throws {
        let body: SnapshotRequest = .init(
            artworkID: document.id.uuidString,
            name: document.name,
            bild: try await Self.encodedInBackground(image)
        )
        _ = try await request(path: "freigabe/snapshot", method: "POST", body: body)
    }

    func publishLive(
        document: ArtworkDocument,
        project: ArtworkProject?,
        image: UIImage
    ) async throws {
        let body = LiveRequest(
            artworkID: document.id.uuidString,
            projectID: project?.id.uuidString,
            projectName: project?.name,
            name: document.name,
            bild: try await Self.encodedInBackground(image)
        )
        _ = try await request(path: "freigabe/live", method: "POST", body: body)
    }

    func stopLive(artworkID: UUID) async throws {
        _ = try await request(
            path: "freigabe/live-stop",
            method: "POST",
            body: ["artworkID": artworkID.uuidString]
        )
    }

    func setProjectShared(_ project: ArtworkProject, enabled: Bool) async throws {
        _ = try await request(
            path: "freigabe/projekt",
            method: "POST",
            body: ProjectShareRequest(
                projectID: project.id.uuidString,
                name: project.name,
                enabled: enabled
            )
        )
    }

    func deleteSentSnapshot(id: String) async throws {
        _ = try await request(
            path: "freigabe/snapshot-loeschen",
            method: "POST",
            body: ["id": id]
        )
    }

    static func image(from dataURL: String) -> UIImage? {
        guard let comma = dataURL.firstIndex(of: ","),
              let data = Data(base64Encoded: String(dataURL[dataURL.index(after: comma)...])) else { return nil }
        return UIImage(data: data)
    }

    private func request<Body: Encodable>(path: String, method: String, body: Body?) async throws -> Data {
        let url = baseURL.appendingPathComponent("api").appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SharingError(status: 0, message: "Keine Serverantwort.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let api = try? JSONDecoder().decode(APIErrorBody.self, from: data)
            throw SharingError(status: http.statusCode, message: api?.fehler ?? "Serverfehler \(http.statusCode)")
        }
        return data
    }

    /// PNG encoding runs off the main thread.
    private static func encodedInBackground(_ image: UIImage) async throws -> String {
        try await Task.detached(priority: .userInitiated) { try dataURL(for: image) }.value
    }

    private nonisolated static func dataURL(for image: UIImage) throws -> String {
        let limits: [CGFloat] = [1400, 1100, 900, 720, 560]
        for maxSide in limits {
            let resized = resized(image, maxSide: maxSide)
            if let data = resized.pngData(), data.count < 820 * 1024 {
                return "data:image/png;base64,\(data.base64EncodedString())"
            }
        }
        throw SharingError(status: 0, message: "Das Bild ist für die Freigabe noch zu groß.")
    }

    private nonisolated static func resized(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxSide else { return image }
        let scale = maxSide / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return image.preparingThumbnail(of: size) ?? image
    }
}

struct SharingError: LocalizedError, Equatable {
    let status: Int
    let message: String
    var errorDescription: String? { message }
}

private struct SnapshotRequest: Encodable {
    let artworkID: String
    let name: String
    let bild: String
}

private struct LiveRequest: Encodable {
    let artworkID: String
    let projectID: String?
    let projectName: String?
    let name: String
    let bild: String
}

private struct ProjectShareRequest: Encodable {
    let projectID: String
    let name: String
    let enabled: Bool
}
