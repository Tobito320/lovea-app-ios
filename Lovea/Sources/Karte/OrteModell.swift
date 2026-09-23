import CoreLocation
import Foundation
import Observation

/// Folds `ort.setzen`/`ort.loeschen`/`ort.ereignis`, collects `CLVisit`s locally, proposes new
/// places (Z-8.4), watches saved places for arrival/leaving via `CLMonitor`, and - since it's the
/// natural place to observe the chat log without a second registration - also flags "Zufällig
/// nah" (Z-8.5) from `nachricht.neu {system:"nah"}`.
@MainActor
@Observable
final class OrteModell {
    static let shared = OrteModell()

    private(set) var orte: [Ort] = []
    private(set) var vorschlag: OrtVorschlagAnzeige?
    /// Z-27.4 "Unsere Orte": server-erkannte gemeinsame Aufenthalte (`ort.gemeinsam`, raum.js
    /// `#pruefeGemeinsam` — der Server sieht beide Standort-Ströme auch im Hintergrund, ein rein
    /// client-seitiger Verlauf hätte das nicht, siehe brief-G-report.md).
    private(set) var gemeinsameOrte: [GemeinsamerOrt] = []
    /// `"<ortId>|<person>"` -> letztes `ort.ereignis` dieser Person an diesem Ort. Für die
    /// Info-Karte ("seit") und um `CLMonitor` nicht doppelt senden zu lassen.
    private(set) var ereignisse: [String: (zeit: Date, art: String)] = [:]
    /// Set for 5 s when a "Zufällig nah" system message arrives; `KarteTab` reads this to
    /// animate both figures.
    private(set) var nahBis: Date?

    private let besuche = BesucheSpeicher()
    private var monitor: CLMonitor?
    private var monitorGestartet = false
    private var verworfeneVorschlaege: Set<String>

    private init() {
        verworfeneVorschlaege = Set(UserDefaults.standard.stringArray(forKey: "lovea.orte.verworfen") ?? [])
        Raum.shared.beobachten(["ort.setzen", "ort.loeschen", "ort.ereignis", "ort.gemeinsam", "nachricht.neu"]) { [weak self] op in
            self?.anwenden(op)
        }
    }

    private func anwenden(_ op: Op) {
        switch op.art {
        case "ort.setzen":
            guard let ort = op.daten(Ort.self) else { return }
            if let i = orte.firstIndex(where: { $0.id == ort.id }) { orte[i] = ort } else { orte.append(ort) }
            Task { @MainActor in await self.monitorAktualisieren() }
        case "ort.loeschen":
            guard let d = op.daten(OrtLoeschenD.self) else { return }
            orte.removeAll { $0.id == d.id }
            Task { @MainActor in await self.monitor?.remove(d.id) }
        case "ort.ereignis":
            guard let d = op.daten(OrtEreignisD.self) else { return }
            ereignisse["\(d.ortId)|\(op.von.rawValue)"] = (op.zeit, d.art)
        case "ort.gemeinsam":
            // Idempotent by op.id, wie jede andere Faltung hier (optimistischer Send + Echo teilen sich eine id).
            guard let d = op.daten(GemeinsamD.self) else { return }
            let neu = GemeinsamerOrt(id: op.id, lat: d.lat, lon: d.lon, datum: d.datum)
            if let i = gemeinsameOrte.firstIndex(where: { $0.id == op.id }) { gemeinsameOrte[i] = neu } else { gemeinsameOrte.append(neu) }
        case "nachricht.neu":
            guard Date().timeIntervalSince(op.zeit) < 30, op.daten(SystemD.self)?.system == "nah" else { return }
            nahBis = Date().addingTimeInterval(5)
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(5))
                guard let self, let bis = self.nahBis, bis <= Date() else { return }
                self.nahBis = nil
            }
        default:
            break
        }
    }

    // MARK: - Visits and proposals (Z-8.4)

    /// Called by `Standort` from `CLLocationManagerDelegate.didVisit`.
    func besuchAufzeichnen(lat: Double, lon: Double, ankunft: Date, verlassen: Date?) {
        let besuch = Besuch(lat: lat, lon: lon, ankunft: ankunft, verlassen: verlassen)
        Task { @MainActor in
            await self.besuche.hinzufuegen(besuch)
            await self.vorschlagAktualisieren()
        }
    }

    private func vorschlagAktualisieren() async {
        let kandidaten = Orte.vorschlaege(besuche: await besuche.alle(), gespeichert: orte)
        guard !kandidaten.isEmpty else { vorschlag = nil; return }
        // "Zuhause" bei den meisten Nächten (Z-8.4), sonst der Vorschlag mit den meisten Tagen.
        let zuhause = kandidaten.max { $0.naechte < $1.naechte }
        let beste = (zuhause?.naechte ?? 0) > 0 ? zuhause! : kandidaten.max { $0.tage < $1.tage }!
        guard !verworfeneVorschlaege.contains(schluessel(beste)) else { vorschlag = nil; return }
        if beste.naechte > 0, beste.lat == zuhause?.lat, beste.lon == zuhause?.lon {
            vorschlag = OrtVorschlagAnzeige(lat: beste.lat, lon: beste.lon, name: "Zuhause", kategorie: "zuhause")
        } else {
            let (name, kategorie) = await OrtePOI.shared.vorschlag(lat: beste.lat, lon: beste.lon)
            vorschlag = OrtVorschlagAnzeige(lat: beste.lat, lon: beste.lon, name: name, kategorie: kategorie)
        }
    }

    func vorschlagSpeichern(name: String, kategorie: String) {
        guard let v = vorschlag, let ich = Raum.shared.ich else { return }
        let ort = Ort(id: UUID().uuidString, person: ich, name: name, kategorie: kategorie, lat: v.lat, lon: v.lon, radius: 100, melden: "beides")
        Raum.shared.senden("ort.setzen", ort)
        vorschlag = nil
    }

    func vorschlagVerwerfen() {
        guard let v = vorschlag else { return }
        verworfeneVorschlaege.insert(schluessel(v.lat, v.lon))
        UserDefaults.standard.set(Array(verworfeneVorschlaege), forKey: "lovea.orte.verworfen")
        vorschlag = nil
    }

    private func schluessel(_ v: OrtVorschlag) -> String { schluessel(v.lat, v.lon) }
    private func schluessel(_ lat: Double, _ lon: Double) -> String { "\(lat),\(lon)" }

    // MARK: - Places list (Z-8.4)

    func umbenennen(_ ort: Ort, name: String) {
        var neu = ort
        neu.name = name
        Raum.shared.senden("ort.setzen", neu)
    }

    func meldenSetzen(_ ort: Ort, _ melden: String) {
        var neu = ort
        neu.melden = melden
        Raum.shared.senden("ort.setzen", neu)
    }

    func loeschen(_ ort: Ort) {
        Raum.shared.senden("ort.loeschen", OrtLoeschenD(id: ort.id))
    }

    /// For the info card: name and "since" for the place the given standort currently sits in.
    func aktuellerOrt(_ person: Person, lat: Double, lon: Double) -> (name: String, seit: Date?)? {
        guard let ort = orte.first(where: {
            CLLocation(latitude: $0.lat, longitude: $0.lon).distance(from: CLLocation(latitude: lat, longitude: lon)) <= $0.radius
        }) else { return nil }
        let letztes = ereignisse["\(ort.id)|\(person.rawValue)"]
        return (ort.name, letztes?.art == "ankunft" ? letztes?.zeit : nil)
    }

    // MARK: - Arrival/leaving via CLMonitor (Z-8.4)

    // ponytail: unsure of the exact `CLMonitor` call shapes below on iOS 26 (no local compiler) -
    // see block-8-report.md for what to double-check before merging.
    private func monitorSicherstellen() async -> CLMonitor {
        if let monitor { return monitor }
        let neu = await CLMonitor("lovea.orte")
        monitor = neu
        if !monitorGestartet {
            monitorGestartet = true
            Task { @MainActor in await self.beobachteEreignisse(neu) }
        }
        return neu
    }

    private func monitorAktualisieren() async {
        guard let ich = Raum.shared.ich else { return }
        let monitor = await monitorSicherstellen()
        let vorhandene = await monitor.identifiers
        for ort in orte where ort.person == ich && !vorhandene.contains(ort.id) {
            let bedingung = CLMonitor.CircularGeographicCondition(center: CLLocationCoordinate2D(latitude: ort.lat, longitude: ort.lon), radius: ort.radius)
            await monitor.add(bedingung, identifier: ort.id)
        }
    }

    private func beobachteEreignisse(_ monitor: CLMonitor) async {
        do {
            for try await event in await monitor.events {
                guard event.state == .satisfied || event.state == .unsatisfied else { continue }
                guard let ort = orte.first(where: { $0.id == event.identifier }), let ich = Raum.shared.ich else { continue }
                let angekommen = event.state == .satisfied
                let schluessel = "\(ort.id)|\(ich.rawValue)"
                guard ereignisse[schluessel]?.art != (angekommen ? "ankunft" : "verlassen") else { continue }
                let art = angekommen ? "ankunft" : "verlassen"
                ereignisse[schluessel] = (Date(), art)
                Raum.shared.senden("ort.ereignis", OrtEreignisD(ortId: ort.id, art: art))
            }
        } catch {}
    }
}

struct OrtVorschlagAnzeige: Equatable {
    let lat: Double
    let lon: Double
    let name: String
    let kategorie: String
}

private struct OrtLoeschenD: Codable { let id: String }
private struct OrtEreignisD: Codable { let ortId: String; let art: String }
private struct SystemD: Codable { let system: String? }
private struct GemeinsamD: Codable { let lat: Double; let lon: Double; let datum: String }

/// Z-27.4: one "Unsere Orte" pin — `datum` is the Berlin calendar day it happened, for the same-day
/// chat photo lookup in `GemeinsamerOrtDetail`.
struct GemeinsamerOrt: Identifiable, Sendable, Equatable {
    let id: String
    let lat: Double
    let lon: Double
    let datum: String
}

/// Local visit history at `Application Support/Lovea/orte/besuche.json` - only 30 days are kept,
/// well beyond the 14-day window `Orte.vorschlaege` looks at.
actor BesucheSpeicher {
    private let fileURL: URL
    private var besuche: [Besuch] = []
    private var geladen = false

    init(rootURL: URL? = nil) {
        let basis = rootURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lovea/orte", isDirectory: true)
        fileURL = basis.appendingPathComponent("besuche.json")
    }

    func hinzufuegen(_ besuch: Besuch) {
        laden()
        besuche.append(besuch)
        let grenze = Date().addingTimeInterval(-30 * 86_400)
        besuche.removeAll { ($0.verlassen ?? $0.ankunft) < grenze }
        speichern()
    }

    func alle() -> [Besuch] {
        laden()
        return besuche
    }

    private func laden() {
        guard !geladen else { return }
        geladen = true
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let daten = try? Data(contentsOf: fileURL) else { return }
        besuche = (try? JSONDecoder().decode([Besuch].self, from: daten)) ?? []
    }

    private func speichern() {
        guard let daten = try? JSONEncoder().encode(besuche) else { return }
        try? daten.write(to: fileURL)
    }
}
