import AuthenticationServices
import CryptoKit
import SwiftUI
import UIKit

/// Z-27.6 "hört gerade": PKCE-Login (`ASWebAuthenticationSession`), Poll von `GET /spotify/jetzt`
/// nur während eine Ansicht die Partner-Figur zeigt (`schauen()`/`wegschauen()`, ref-gezählt).
/// Server-Details (Token-Speicherung, Erneuerung, Cache) in `server/spotify.js`/`raum.js`.
@MainActor @Observable
final class SpotifyModell {
    static let shared = SpotifyModell()

    /// Alle Felder optional: der Server antwortet mit `{}`, wenn niemand etwas hört (schnittstellen.md).
    struct Song: Codable, Sendable, Equatable {
        var titel: String?
        var kuenstler: String?
        var cover: String?
        var url: String?
        var gueltig: Bool { !(titel ?? "").isEmpty }
    }

    private(set) var partner: Song?
    private var pollTask: Task<Void, Never>?
    private var beobachter = 0

    private init() {}

    /// Ref-gezählt, damit mehrere gleichzeitig sichtbare Stellen (Chat-Header + Karte) nur einen
    /// einzigen Poller laufen lassen — Spec 9: "der Server fragt Spotify nur, wenn der Partner hinschaut".
    func schauen() {
        beobachter += 1
        guard pollTask == nil else { return }
        pollTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                await self.laden()
                try? await Task.sleep(for: .seconds(20)) // deckt sich mit dem 20s-Server-Cache
            }
        }
    }

    func wegschauen() {
        beobachter = max(0, beobachter - 1)
        guard beobachter == 0 else { return }
        pollTask?.cancel()
        pollTask = nil
    }

    private func laden() async {
        guard let ich = Raum.shared.ich, let konfig = Raum.shared.httpKonfiguration() else { return }
        var comps = URLComponents(url: konfig.basis.appendingPathComponent("spotify/jetzt"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "person", value: ich.partner.rawValue)]
        guard let url = comps?.url else { return }
        var request = URLRequest(url: url)
        for (feld, wert) in konfig.headers { request.setValue(wert, forHTTPHeaderField: feld) }
        guard let (daten, _) = try? await URLSession.shared.data(for: request) else { return }
        guard let song = try? JSONDecoder().decode(Song.self, from: daten) else { return }
        partner = song.gueltig ? song : nil
    }
}

// MARK: - PKCE (RFC 7636)

enum SpotifyPKCE {
    private static let zeichen = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    static func verifier() -> String {
        String((0..<64).compactMap { _ in zeichen.randomElement() })
    }

    /// code_challenge = BASE64URL(SHA256(code_verifier)), Methode S256.
    static func challenge(_ verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Konfiguration (Build-Setting `SPOTIFY_CLIENT_ID` -> Info.plist, wie `LoveaAppKey`)

enum SpotifyKonfiguration {
    static var clientId: String { (Bundle.main.object(forInfoDictionaryKey: "LoveaSpotifyClientID") as? String) ?? "" }
    static let redirectUri = "lovea://spotify"
    static var eingerichtet: Bool { !clientId.isEmpty }
}

// MARK: - OAuth (ASWebAuthenticationSession)

@MainActor
final class SpotifyAuth: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = SpotifyAuth()
    private override init() {}
    // Retained here for the duration of the login — an unretained local `ASWebAuthenticationSession`
    // can be deallocated (and the flow silently cancelled) before its completion handler fires.
    private var aktiveSession: ASWebAuthenticationSession?

    /// Öffnet Spotifys Login, tauscht den Code danach über `POST /spotify/verbinden`. `true` bei Erfolg.
    func verbinden() async -> Bool {
        guard SpotifyKonfiguration.eingerichtet else { return false }
        let verifier = SpotifyPKCE.verifier()
        var comps = URLComponents(string: "https://accounts.spotify.com/authorize")!
        comps.queryItems = [
            URLQueryItem(name: "client_id", value: SpotifyKonfiguration.clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: SpotifyKonfiguration.redirectUri),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: SpotifyPKCE.challenge(verifier)),
            URLQueryItem(name: "scope", value: "user-read-currently-playing"),
        ]
        guard let authURL = comps.url else { return false }

        guard let callbackURL = await starteSession(authURL),
              let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "code" })?.value
        else { return false }

        return await codeEintauschen(code: code, verifier: verifier)
    }

    // ponytail: like `Raum.aktiv`'s background-task handler, `ASWebAuthenticationSession`'s
    // completion handler isn't documented as @MainActor even though Apple always calls it on the
    // main thread — `assumeIsolated` is the same safe way to touch MainActor state from it without
    // an (unavailable here, this isn't async) await.
    private func starteSession(_ authURL: URL) async -> URL? {
        await withCheckedContinuation { fortsetzen in
            // `aktiveSession != nil` = "noch nicht fortgesetzt": whichever side (completion or a failed
            // `start()`) gets there first resumes, the other one does nothing — never twice.
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "lovea") { [weak self] url, _ in
                let offen = MainActor.assumeIsolated { () -> Bool in
                    defer { self?.aktiveSession = nil }
                    return self?.aktiveSession != nil
                }
                if offen { fortsetzen.resume(returning: url) }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            aktiveSession = session
            // Minor 8: `start()` returning false never calls the completion — without this the
            // "Spotify verbinden" button stayed disabled until relaunch.
            if !session.start(), aktiveSession != nil {
                aktiveSession = nil
                fortsetzen.resume(returning: nil)
            }
        }
    }

    private func codeEintauschen(code: String, verifier: String) async -> Bool {
        guard let ich = Raum.shared.ich, let konfig = Raum.shared.httpKonfiguration() else { return false }
        var request = URLRequest(url: konfig.basis.appendingPathComponent("spotify/verbinden"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (feld, wert) in konfig.headers { request.setValue(wert, forHTTPHeaderField: feld) }
        // `person` steht mit im Body (schnittstellen.md), der Server nimmt aber den Header-Absender
        // als Quelle der Wahrheit (raum.js #spotifyVerbinden) -- hier trotzdem mitgeschickt, für den
        // Fall, dass ein künftiger Aufrufer sich nur auf den dokumentierten Body verlässt.
        request.httpBody = try? JSONEncoder().encode(VerbindenBody(person: ich.rawValue, code: code, verifier: verifier, redirectUri: SpotifyKonfiguration.redirectUri))
        guard let (_, response) = try? await URLSession.shared.data(for: request) else { return false }
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    // ponytail: nimmt das erste Key Window — reicht für diese Zwei-Personen-App (ein Fenster), kein
    // Multi-Window-iPad-Fall zu unterscheiden.
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}

private struct VerbindenBody: Encodable { let person: String; let code: String; let verifier: String; let redirectUri: String }

// MARK: - "Hört gerade" an der Partner-Figur (Spec 9)

/// Empty (`EmptyView`) while nobody's `partner` song is known — the chat header always includes
/// this, no visibility check needed at the call site.
struct SpotifyHoertGeradeChip: View {
    var body: some View {
        if let song = SpotifyModell.shared.partner, let titel = song.titel {
            Button {
                guard let urlText = song.url, let url = URL(string: urlText) else { return }
                UIApplication.shared.open(url)
            } label: {
                inhalt(song, titel: titel)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .glassEffect(.regular, in: .capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hört gerade: \(titel)\(song.kuenstler.map { ", \($0)" } ?? "")")
            .accessibilityHint("Öffnet Spotify")
        }
    }

    /// Minor 9 (Spec 9: "Titel, Künstler, Cover"): the server already sends all three.
    private func inhalt(_ song: SpotifyModell.Song, titel: String) -> some View {
        let kuenstler = song.kuenstler.flatMap { $0.isEmpty ? nil : $0 }
        return HStack(spacing: 4) {
            if let cover = song.cover.flatMap(URL.init(string:)) {
                AsyncImage(url: cover) { bild in
                    bild.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "music.note")
                }
                .frame(width: 16, height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                Image(systemName: "music.note")
            }
            Text(kuenstler.map { "\(titel) · \($0)" } ?? titel).lineLimit(1)
        }
    }
}

// MARK: - Einstellungen-Zeile

/// "Spotify verbinden" (Spec 9/13): ohne `SPOTIFY_CLIENT_ID` "nicht eingerichtet" (Ahmed muss die
/// Spotify-Developer-App noch anlegen, siehe brief-G-report.md).
struct SpotifyVerbindenRow: View {
    @State private var verbindetSich = false

    var body: some View {
        if SpotifyKonfiguration.eingerichtet {
            Button {
                verbindetSich = true
                Task {
                    _ = await SpotifyAuth.shared.verbinden()
                    verbindetSich = false
                }
            } label: {
                HStack {
                    Text("Spotify verbinden")
                    if verbindetSich { Spacer(); ProgressView() }
                }
            }
            .foregroundStyle(.primary)
            .disabled(verbindetSich)
        } else {
            HStack {
                Text("Spotify verbinden")
                Spacer()
                Text("nicht eingerichtet").foregroundStyle(.secondary)
            }
        }
    }
}
