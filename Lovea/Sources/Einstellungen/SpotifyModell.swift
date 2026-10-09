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
    /// Je nach Freigabe (`spotify.teilen` des Partners) fehlen Titel/Cover: dann nur `musik` oder
    /// `musik` + `kuenstler`. Ältere Server schicken kein `musik`, dafür immer einen Titel.
    struct Song: Codable, Sendable, Equatable {
        var titel: String?
        var kuenstler: String?
        var cover: String?
        var url: String?
        var musik: Bool?
        /// Nur bei Fehlern: Grund, warum Spotify nichts liefert (siehe `SpotifyFehler.text(fuerStatus:)`).
        var fehler: String?
        var gueltig: Bool { !(titel ?? "").isEmpty || musik == true }

        /// Eigener Titel-Link, sonst Künstlersuche in Spotify. Öffnet in der eigenen Spotify-App.
        var oeffnenURL: URL? {
            if let url, !url.isEmpty { return URL(string: url) }
            guard let kuenstler, !kuenstler.isEmpty,
                  let suche = kuenstler.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
            return URL(string: "https://open.spotify.com/search/\(suche)")
        }
    }

    /// Freigabe-Stufen, Rohwerte wie `STUFEN` in `server/spotify.js`.
    enum Freigabe: String, CaseIterable, Identifiable {
        case song, kuenstler, musik, aus
        var id: String { rawValue }
        var titel: String {
            switch self {
            case .song: "Song, Künstler und Cover"
            case .kuenstler: "Nur Künstler"
            case .musik: "Nur „hört Musik“"
            case .aus: "Nichts"
            }
        }
    }

    static let freigabeSchluessel = "spotify.teilen"
    private static let verbundenMerker = "lovea.spotify.verbunden"

    var freigabe: Freigabe {
        get { Freigabe(rawValue: EinstellungenModell.shared.string(Self.freigabeSchluessel, default: "song")) ?? .song }
        set { EinstellungenModell.shared.setzen(Self.freigabeSchluessel, .string(newValue.rawValue)) }
    }

    /// ponytail: lokaler Merker statt Server-Abfrage; nach Neuinstallation zeigt er "nicht verbunden",
    /// obwohl der Server noch den Token hat. Erneutes Verbinden überschreibt ihn einfach.
    private(set) var verbunden: Bool = UserDefaults.standard.bool(forKey: "lovea.spotify.verbunden")

    func setzeVerbunden(_ wert: Bool) {
        verbunden = wert
        UserDefaults.standard.set(wert, forKey: Self.verbundenMerker)
    }

    private(set) var partner: Song?
    /// Lesbarer Grund, warum die eigene Verbindung nicht funktioniert (`GET /spotify/status`); `nil` = alles gut.
    private(set) var statusFehler: String?
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

    /// Fragt den Server, ob die eigene Verbindung steht und was Spotify dazu sagt. Gleicht den lokalen
    /// "verbunden"-Merker mit dem Server ab (nach Neuinstallation stimmte er früher nicht). Ohne Netz
    /// bleibt alles, wie es war.
    func pruefen() async {
        guard let konfig = Raum.shared.httpKonfiguration() else { return }
        var request = URLRequest(url: konfig.basis.appendingPathComponent("spotify/status"))
        for (feld, wert) in konfig.headers { request.setValue(wert, forHTTPHeaderField: feld) }
        guard let (daten, antwort) = try? await URLSession.shared.data(for: request),
              (antwort as? HTTPURLResponse)?.statusCode == 200,
              let status = try? JSONDecoder().decode(Status.self, from: daten) else { return }
        setzeVerbunden(status.verbunden)
        statusFehler = status.fehler.map(SpotifyFehler.text(fuerStatus:))
    }

    private struct Status: Decodable { let verbunden: Bool; let fehler: String? }

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

// MARK: - Fehler (früher: `verbinden()` lieferte nur `false`, jeder Fehlschlag sah gleich aus)

/// Warum Spotify verbinden/abfragen nicht klappt, mit Text für die Einstellungen.
/// Reine Werte, ohne UI, damit die Zuordnung testbar bleibt.
enum SpotifyFehler: Error, Equatable, Sendable {
    case nichtEingerichtet
    case abgebrochen                    // Nutzer hat das Login-Fenster geschlossen: keine Meldung
    case startFehlgeschlagen
    case anmeldung(String)              // `error=` im Callback (z. B. access_denied) oder Fehler der Session
    case keinCode
    case netz
    case server(status: Int, grund: String?)

    /// `nil` = nichts anzeigen (bewusster Abbruch).
    var text: String? {
        switch self {
        case .abgebrochen: nil
        case .nichtEingerichtet: "Diese App-Version hat keine Spotify-Client-ID. Sie muss beim Bauen als SPOTIFY_CLIENT_ID mitgegeben werden."
        case .startFehlgeschlagen: "Das Spotify-Login-Fenster ließ sich nicht öffnen."
        case let .anmeldung(grund): grund == "access_denied" ? "Du hast den Zugriff in Spotify abgelehnt." : "Spotify meldet: \(grund)."
        case .keinCode: "Spotify hat keinen Anmelde-Code zurückgegeben."
        case .netz: "Keine Verbindung zum Lovea-Server."
        case let .server(status, grund):
            switch (status, grund) {
            case (503, _): "Der Lovea-Server hat keine Spotify-Client-ID."
            case (_, "invalid_client"?): "Spotify kennt diese Client-ID nicht. Sie muss zur App im Spotify-Dashboard passen, auf App und Server."
            case (_, "invalid_grant"?): "Spotify hat den Code abgelehnt. Ist \(SpotifyKonfiguration.redirectUri) im Spotify-Dashboard als Redirect-URI eingetragen?"
            default: "Spotify-Verbindung fehlgeschlagen (\(grund ?? String(status)))."
            }
        }
    }

    /// Werte von `fehler` aus `GET /spotify/status` und `GET /spotify/jetzt` (`server/spotify.js` `fehlerGrund`).
    static func text(fuerStatus fehler: String) -> String {
        switch fehler {
        case "abgelaufen": "Die Verbindung ist abgelaufen oder wurde widerrufen. Bitte neu verbinden."
        case "nicht-freigeschaltet": "Spotify lässt dieses Konto nicht zu: Die E-Mail muss im Spotify-Dashboard unter User Management eingetragen sein."
        case "zu-viele-anfragen": "Spotify bremst gerade (zu viele Anfragen). Später nochmal."
        case "nicht-eingerichtet": "Der Lovea-Server hat keine Spotify-Client-ID."
        default: "Spotify antwortet gerade nicht."
        }
    }

    /// Callback-URL der Anmeldung -> Code oder Fehler. Spotify hängt bei Ablehnung `?error=...` an.
    static func code(aus callback: URL) -> Result<String, SpotifyFehler> {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let fehler = items.first(where: { $0.name == "error" })?.value { return .failure(.anmeldung(fehler)) }
        guard let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else { return .failure(.keinCode) }
        return .success(code)
    }

    /// Antwort von `POST /spotify/verbinden` (`{ fehler, grund }` bei Fehlern).
    static func ausServer(status: Int, body: Data) -> SpotifyFehler {
        struct Antwort: Decodable { let grund: String? }
        return .server(status: status, grund: (try? JSONDecoder().decode(Antwort.self, from: body))?.grund)
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

    /// Öffnet Spotifys Login, tauscht den Code danach über `POST /spotify/verbinden`.
    func verbinden() async -> Result<Void, SpotifyFehler> {
        guard SpotifyKonfiguration.eingerichtet else { return .failure(.nichtEingerichtet) }
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
        guard let authURL = comps.url else { return .failure(.startFehlgeschlagen) }

        switch await starteSession(authURL) {
        case let .failure(fehler): return .failure(fehler)
        case let .success(callbackURL):
            switch SpotifyFehler.code(aus: callbackURL) {
            case let .failure(fehler): return .failure(fehler)
            case let .success(code):
                if let fehler = await codeEintauschen(code: code, verifier: verifier) { return .failure(fehler) }
                return .success(())
            }
        }
    }

    // ponytail: like `Raum.aktiv`'s background-task handler, `ASWebAuthenticationSession`'s
    // completion handler isn't documented as @MainActor even though Apple always calls it on the
    // main thread — `assumeIsolated` is the same safe way to touch MainActor state from it without
    // an (unavailable here, this isn't async) await.
    private func starteSession(_ authURL: URL) async -> Result<URL, SpotifyFehler> {
        await withCheckedContinuation { fortsetzen in
            // `aktiveSession != nil` = "noch nicht fortgesetzt": whichever side (completion or a failed
            // `start()`) gets there first resumes, the other one does nothing — never twice.
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "lovea") { [weak self] url, error in
                let offen = MainActor.assumeIsolated { () -> Bool in
                    defer { self?.aktiveSession = nil }
                    return self?.aktiveSession != nil
                }
                guard offen else { return }
                if let url { return fortsetzen.resume(returning: .success(url)) }
                // Fenster geschlossen = bewusster Abbruch, alles andere ist ein echter Fehler.
                let abbruch = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
                fortsetzen.resume(returning: .failure(abbruch ? .abgebrochen : .anmeldung(error?.localizedDescription ?? "unbekannt")))
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            aktiveSession = session
            // Minor 8: `start()` returning false never calls the completion — without this the
            // "Spotify verbinden" button stayed disabled until relaunch.
            if !session.start(), aktiveSession != nil {
                aktiveSession = nil
                fortsetzen.resume(returning: .failure(.startFehlgeschlagen))
            }
        }
    }

    private func codeEintauschen(code: String, verifier: String) async -> SpotifyFehler? {
        guard let ich = Raum.shared.ich, let konfig = Raum.shared.httpKonfiguration() else { return .netz }
        var request = URLRequest(url: konfig.basis.appendingPathComponent("spotify/verbinden"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (feld, wert) in konfig.headers { request.setValue(wert, forHTTPHeaderField: feld) }
        // `person` steht mit im Body (schnittstellen.md), der Server nimmt aber den Header-Absender
        // als Quelle der Wahrheit (raum.js #spotifyVerbinden) -- hier trotzdem mitgeschickt, für den
        // Fall, dass ein künftiger Aufrufer sich nur auf den dokumentierten Body verlässt.
        request.httpBody = try? JSONEncoder().encode(VerbindenBody(person: ich.rawValue, code: code, verifier: verifier, redirectUri: SpotifyKonfiguration.redirectUri))
        guard let (daten, response) = try? await URLSession.shared.data(for: request),
              let status = (response as? HTTPURLResponse)?.statusCode else { return .netz }
        return status == 200 ? nil : SpotifyFehler.ausServer(status: status, body: daten)
    }

    /// `POST /spotify/trennen`: der Server löscht den eigenen Token, der Partner sieht danach nichts mehr.
    func trennen() async -> Bool {
        guard let konfig = Raum.shared.httpKonfiguration() else { return false }
        var request = URLRequest(url: konfig.basis.appendingPathComponent("spotify/trennen"))
        request.httpMethod = "POST"
        for (feld, wert) in konfig.headers { request.setValue(wert, forHTTPHeaderField: feld) }
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
/// this, no visibility check needed at the call site. Antippen öffnet den Song (oder bei "Nur
/// Künstler" die Künstlersuche) in der eigenen Spotify-App. Kein Mithören.
struct SpotifyHoertGeradeChip: View {
    var body: some View {
        if let song = SpotifyModell.shared.partner {
            Button {
                if let url = song.oeffnenURL { UIApplication.shared.open(url) }
            } label: {
                inhalt(song)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .glassEffect(.regular, in: .capsule)
                    // p69: the pill is about 22 pt tall; twelve points more on every side make the hit area 44 pt.
                    .contentShape(Rectangle().inset(by: -12))
            }
            .buttonStyle(.plain)
            .disabled(song.oeffnenURL == nil)
            .accessibilityLabel("Hört gerade: \(text(song))")
            .accessibilityHint(song.oeffnenURL == nil ? "" : "Öffnet in deinem Spotify")
        }
    }

    private func text(_ song: SpotifyModell.Song) -> String {
        let titel = song.titel.flatMap { $0.isEmpty ? nil : $0 }
        let kuenstler = song.kuenstler.flatMap { $0.isEmpty ? nil : $0 }
        switch (titel, kuenstler) {
        case let (t?, k?): return "\(t) · \(k)"
        case let (t?, nil): return t
        case let (nil, k?): return k
        default: return "hört Musik"
        }
    }

    private func inhalt(_ song: SpotifyModell.Song) -> some View {
        HStack(spacing: 4) {
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
            Text(text(song)).lineLimit(1)
        }
    }
}

// MARK: - Einstellungen-Zeilen

/// Abschnitt "Spotify" in den Einstellungen: verbinden/trennen und was der Partner sieht.
/// Ohne `SPOTIFY_CLIENT_ID` "nicht eingerichtet" (Spotify-Developer-App, V-7).
struct SpotifyVerbindenRow: View {
    @State private var arbeitet = false
    /// Rote Zeile unter dem Knopf: warum das letzte Verbinden/Trennen nicht klappte (statt Schweigen).
    @State private var meldung: String?
    private var modell: SpotifyModell { SpotifyModell.shared }

    var body: some View {
        if SpotifyKonfiguration.eingerichtet {
            verbindenKnopf
            if let meldung {
                Text(meldung).font(.footnote).foregroundStyle(.red)
            } else if modell.verbunden, let fehler = modell.statusFehler {
                Text(fehler).font(.footnote).foregroundStyle(.orange)
            }
            if modell.verbunden {
                freigabeAuswahl
                Button("Spotify trennen", role: .destructive) { trennen() }
                    .disabled(arbeitet)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Spotify verbinden")
                    Spacer()
                    Text("nicht eingerichtet").foregroundStyle(.secondary)
                }
                Text(SpotifyFehler.nichtEingerichtet.text ?? "").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var verbindenKnopf: some View {
        Button { verbinden() } label: {
            HStack {
                Text(modell.verbunden ? "Spotify verbunden" : "Spotify verbinden")
                Spacer()
                if arbeitet { ProgressView() } else if modell.verbunden { Image(systemName: "checkmark").foregroundStyle(.green) }
            }
        }
        .foregroundStyle(.primary)
        .disabled(arbeitet)
        .task { await modell.pruefen() }
    }

    private var freigabeAuswahl: some View {
        Picker("\(Raum.shared.ich?.partner.name ?? "Partner") sieht", selection: Binding(
            get: { modell.freigabe },
            set: { modell.freigabe = $0 }
        )) {
            ForEach(SpotifyModell.Freigabe.allCases) { Text($0.titel).tag($0) }
        }
    }

    private func verbinden() {
        arbeitet = true
        meldung = nil
        Task {
            switch await SpotifyAuth.shared.verbinden() {
            case .success:
                modell.setzeVerbunden(true)
                await modell.pruefen() // zeigt sofort, falls Spotify das Konto trotz Login nicht zulässt
            case let .failure(fehler):
                meldung = fehler.text
            }
            arbeitet = false
        }
    }

    private func trennen() {
        arbeitet = true
        meldung = nil
        Task {
            if await SpotifyAuth.shared.trennen() {
                modell.setzeVerbunden(false)
            } else {
                meldung = SpotifyFehler.netz.text
            }
            arbeitet = false
        }
    }
}
