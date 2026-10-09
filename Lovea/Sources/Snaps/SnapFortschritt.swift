import Foundation
import Observation
import SwiftUI

/// Ehrlicher Stand einer Medien-Übertragung (Snap, Foto, Video) auf einem Gerät.
/// Senden: vorbereiten, hochladen, zustellen, zugestellt. Empfangen: herunterladen, bereit.
/// Eine Phase zeigt nur, was wirklich passiert ist: "zugestellt" erst, wenn der Upload fertig UND
/// der Server die Nachricht bestätigt hat (`seq`). Ohne bekannte Gesamtgröße gibt es keine Prozent.
struct MedienFortschritt: Equatable, Sendable {
    enum Rolle: Equatable, Sendable { case senden, empfangen }
    enum Phase: Equatable, Sendable { case vorbereiten, hochladen, zustellen, zugestellt, herunterladen, bereit, fehlgeschlagen }

    enum Ereignis: Equatable, Sendable {
        /// Kodieren fertig, `gesamt` Bytes gehen raus (0 = unbekannt).
        case vorbereitet(gesamt: Int)
        /// Weitere `bytes` sind oben angekommen (Teile laufen parallel, darum Zuwachs statt Stand).
        case hochgeladen(bytes: Int)
        case uploadFertig
        /// Server hat die Nachricht angenommen (`seq` ist da). Reihenfolge zum Upload egal.
        case bestaetigt
        /// Download-Stand absolut; `gesamt` kann -1/0 sein (unbekannt).
        case erhalten(bytes: Int, gesamt: Int)
        case heruntergeladen
        /// Ein Versuch ist gescheitert. Senden: Phase `fehlgeschlagen`. Empfangen: Gegenseite hat
        /// noch nichts oder kein Netz, es wird weiter versucht (`wartet`).
        case fehler
        case neuerVersuch
    }

    let rolle: Rolle
    private(set) var phase: Phase
    private(set) var gesamt = 0
    private(set) var uebertragen = 0
    private(set) var bestaetigt = false
    /// Nur Empfang: letzter Versuch ohne Datei, nächster läuft schon.
    private(set) var wartet = false
    private var vorFehler: Phase = .vorbereiten

    init(rolle: Rolle) {
        self.rolle = rolle
        phase = rolle == .senden ? .vorbereiten : .herunterladen
    }

    var fertig: Bool { phase == .zugestellt || phase == .bereit }

    /// 0...1, `nil` = unbekannt (dann unbestimmter Balken, nie eine erfundene Zahl).
    var anteil: Double? {
        switch phase {
        case .hochladen, .herunterladen:
            return gesamt > 0 ? min(Double(uebertragen) / Double(gesamt), 1) : nil
        case .zugestellt, .bereit:
            return 1
        case .vorbereiten, .zustellen, .fehlgeschlagen:
            return nil
        }
    }

    var prozent: Int? { anteil.map { Int(($0 * 100).rounded(.down)) } }

    var text: String {
        switch phase {
        case .vorbereiten: return "Wird vorbereitet"
        case .hochladen: return prozent.map { "Hochladen \($0) %" } ?? "Hochladen"
        case .zustellen: return "Wird zugestellt"
        case .zugestellt: return "Zugestellt"
        case .herunterladen:
            if wartet { return "Wartet auf Absender" }
            return prozent.map { "Herunterladen \($0) %" } ?? "Herunterladen"
        case .bereit: return "Geladen"
        case .fehlgeschlagen: return "Senden steht aus, wird wiederholt"
        }
    }

    /// Wendet ein Ereignis an. Was in der aktuellen Phase keinen Sinn hat, wird ignoriert (ein
    /// verspätetes Teil nach "fertig" darf nichts zurückdrehen).
    mutating func anwenden(_ ereignis: Ereignis) {
        switch ereignis {
        case .vorbereitet(let neuGesamt):
            guard rolle == .senden, phase == .vorbereiten else { return }
            gesamt = max(neuGesamt, 0)
            uebertragen = 0
            phase = .hochladen
        case .hochgeladen(let bytes):
            guard rolle == .senden, phase == .hochladen, bytes > 0 else { return }
            uebertragen = gesamt > 0 ? min(uebertragen + bytes, gesamt) : uebertragen + bytes
        case .uploadFertig:
            guard rolle == .senden, phase == .hochladen else { return }
            if gesamt > 0 { uebertragen = gesamt }
            phase = bestaetigt ? .zugestellt : .zustellen
        case .bestaetigt:
            guard rolle == .senden, !bestaetigt else { return }
            bestaetigt = true
            if phase == .zustellen { phase = .zugestellt }
        case .erhalten(let bytes, let neuGesamt):
            guard rolle == .empfangen, phase == .herunterladen else { return }
            if neuGesamt > 0 { gesamt = neuGesamt }
            if bytes > uebertragen { uebertragen = gesamt > 0 ? min(bytes, gesamt) : bytes }
            wartet = false
        case .heruntergeladen:
            guard rolle == .empfangen, phase == .herunterladen else { return }
            if gesamt > 0 { uebertragen = gesamt }
            wartet = false
            phase = .bereit
        case .fehler:
            guard !fertig else { return }
            if rolle == .empfangen {
                wartet = true
            } else if phase != .fehlgeschlagen {
                vorFehler = phase
                phase = .fehlgeschlagen
            }
        case .neuerVersuch:
            guard rolle == .senden, phase == .fehlgeschlagen else { return }
            // Der neue Lauf meldet schon oben liegende Teile selbst erneut, darum von vorn zählen.
            uebertragen = 0
            phase = vorFehler
        }
    }

    /// Dieselbe Anzeige mit bestätigter Nachricht (`ChatModell.Nachricht.seq != nil`), ohne den
    /// gespeicherten Stand zu ändern — die Ansicht reicht nur durch, was sie gerade sieht.
    func mitBestaetigung(_ ist: Bool) -> MedienFortschritt {
        guard ist else { return self }
        var kopie = self
        kopie.anwenden(.bestaetigt)
        return kopie
    }

    /// Reicht die Änderung, um die Anzeige neu zu zeichnen? Download-Zuwachs unter 1 % nicht.
    func anzeigeAnders(als anderer: MedienFortschritt) -> Bool {
        phase != anderer.phase || prozent != anderer.prozent || wartet != anderer.wartet || bestaetigt != anderer.bestaetigt
    }
}

/// Alle laufenden Übertragungen dieses Geräts, nach Medien-ID. Nur im Speicher: nach einem Neustart
/// beginnt ein offener Upload/Download wieder bei null (die Übertragung selbst setzt fort).
@MainActor
@Observable
final class FortschrittsStand {
    static let shared = FortschrittsStand()
    /// Grenze, damit die Liste über Wochen nicht wächst; zuerst fliegen beendete Einträge raus.
    private static let hoechstens = 60

    private(set) var eintraege: [String: MedienFortschritt] = [:]

    func stand(_ id: String) -> MedienFortschritt? { eintraege[id] }

    /// Legt den Eintrag an, falls es ihn noch nicht gibt (ein zweiter Aufruf setzt nichts zurück).
    func beginnen(_ id: String, rolle: MedienFortschritt.Rolle) {
        guard eintraege[id] == nil else { return }
        if eintraege.count >= Self.hoechstens { eintraege = eintraege.filter { !$0.value.fertig } }
        eintraege[id] = MedienFortschritt(rolle: rolle)
    }

    func anwenden(_ ereignis: MedienFortschritt.Ereignis, id: String) {
        guard let alt = eintraege[id] else { return }
        var neu = alt
        neu.anwenden(ereignis)
        // Nur zuweisen, wenn die Anzeige anders aussieht: ein Download meldet viele Male pro Sekunde.
        if neu.anzeigeAnders(als: alt) { eintraege[id] = neu }
    }

    func vergessen(_ id: String) { eintraege[id] = nil }
}

/// Kleine Kapsel mit Ring und Text. Sichtbar nur, solange etwas läuft oder schief ging; ist alles
/// angekommen, verschwindet sie (die Nachricht zeigt dann ihren normalen Stand).
struct FortschrittsAnzeige: View {
    let medienId: String

    private var roh: MedienFortschritt? { FortschrittsStand.shared.stand(medienId) }

    /// Beim Senden: hat der Server die Nachricht schon angenommen? Nur gefragt, solange der Upload
    /// fertig ist und die Antwort fehlt (die Suche läuft über die Nachrichten, sonst unnötig).
    private var bestaetigt: Bool {
        guard let roh, roh.rolle == .senden, roh.phase == .zustellen else { return false }
        return ChatModell.shared.medienBestaetigt(medienId)
    }

    var body: some View {
        Group {
            if let stand = roh?.mitBestaetigung(bestaetigt), !stand.fertig { kapsel(stand) }
        }
        .task(id: bestaetigt) {
            if bestaetigt { FortschrittsStand.shared.anwenden(.bestaetigt, id: medienId) }
        }
    }

    private func kapsel(_ stand: MedienFortschritt) -> some View {
        HStack(spacing: 6) {
            ring(stand)
            Text(stand.text).font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(0.55), in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stand.text)
    }

    @ViewBuilder private func ring(_ stand: MedienFortschritt) -> some View {
        if let anteil = stand.anteil {
            ProgressView(value: anteil).progressViewStyle(.circular).controlSize(.mini).tint(.white)
        } else {
            ProgressView().controlSize(.mini).tint(.white)
        }
    }
}

extension ChatModell {
    /// Hat der Server die Nachricht mit diesem Medium angenommen (`seq` ist gesetzt)?
    func medienBestaetigt(_ medienId: String) -> Bool {
        nachrichten.last { nachricht in nachricht.medien.contains { $0.id == medienId } }?.seq != nil
    }
}

/// Download und Upload mit Fortschritt: ruft `Medien` auf und füttert `FortschrittsStand`.
/// Die Übertragung selbst bleibt unverändert (gleiche Wege, gleiche Wiederholungen).
@MainActor
enum MedienUebertragung {
    /// Wie `Medien.holen`. Liegt die Datei schon lokal, passiert nichts weiter (kein Eintrag).
    static func holen(_ id: String) async throws -> URL {
        if let lokal = Medien.lokal(id) { return lokal }
        let stand = FortschrittsStand.shared
        stand.beginnen(id, rolle: .empfangen)
        do {
            let url = try await Medien.holen(id) { erhalten, erwartet in
                Task { @MainActor in
                    FortschrittsStand.shared.anwenden(.erhalten(bytes: Int(erhalten), gesamt: Int(erwartet)), id: id)
                }
            }
            stand.anwenden(.heruntergeladen, id: id)
            return url
        } catch {
            stand.anwenden(.fehler, id: id)
            throw error
        }
    }

    /// Wie `Medien.hochladen`, mit Phase "Hochladen" und Bytezähler. Ein zweiter Aufruf für dieselbe
    /// ID, der nichts tut (läuft schon), meldet kein Ende; der erste tut das.
    static func hochladen(id: String, original: URL, klein: URL?) async throws {
        let stand = FortschrittsStand.shared
        stand.beginnen(id, rolle: .senden)
        stand.anwenden(.neuerVersuch, id: id)
        stand.anwenden(.vorbereitet(gesamt: dateiGroesse(original) + (klein.map(dateiGroesse) ?? 0)), id: id)
        do {
            let gemacht = try await Medien.hochladen(id: id, original: original, klein: klein) { zuwachs in
                Task { @MainActor in FortschrittsStand.shared.anwenden(.hochgeladen(bytes: zuwachs), id: id) }
            }
            if gemacht { stand.anwenden(.uploadFertig, id: id) }
        } catch {
            stand.anwenden(.fehler, id: id)
            throw error
        }
    }

    private static func dateiGroesse(_ url: URL) -> Int {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    }
}
