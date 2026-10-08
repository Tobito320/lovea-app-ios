import AVFoundation
import Foundation

/// Schnittplan für ein Snap-Video vor dem Senden: vorn/hinten kürzen, Teile aus der Mitte
/// entfernen, Ton aus. Reine Rechnung (Sekunden), kein AVFoundation — `SnapSchnittExport` setzt den
/// Plan danach um. Nichts hier läuft von selbst: kein Timer, kein Laden.
struct SnapSchnitt: Equatable, Sendable {
    struct Bereich: Equatable, Sendable {
        var von: Double
        var bis: Double
        var laenge: Double { bis - von }
    }

    /// Was nach dem Schnitt mindestens übrig bleiben muss. Darunter lehnt der Plan den Schnitt ab.
    static let mindestdauer = 0.5
    /// Entfernte Stücke und Reste unter dieser Länge zählen nicht (Fingerzucken, kein Schnitt).
    static let kleinsterTeil = 0.1

    let dauer: Double
    private(set) var anfang: Double
    private(set) var ende: Double
    private(set) var entfernt: [Bereich] = []
    var stumm = false

    init(dauer: Double) {
        self.dauer = max(dauer, 0)
        anfang = 0
        ende = max(dauer, 0)
    }

    /// Die Teile, die im Ergebnis bleiben: [anfang, ende] ohne die entfernten Bereiche, sortiert,
    /// ohne Reste unter `kleinsterTeil`.
    var behalten: [Bereich] {
        var teile: [Bereich] = []
        var start = anfang
        for weg in entfernt.sorted(by: { $0.von < $1.von }) {
            let vorWeg = min(weg.von, ende)
            if vorWeg - start >= Self.kleinsterTeil { teile.append(Bereich(von: start, bis: vorWeg)) }
            start = max(start, weg.bis)
        }
        if ende - start >= Self.kleinsterTeil { teile.append(Bereich(von: start, bis: ende)) }
        return teile
    }

    var ergebnisDauer: Double { behalten.reduce(0) { $0 + $1.laenge } }

    /// Nur Ton aus ändert die Bildspur nicht, braucht aber trotzdem einen Export.
    var schnittNoetig: Bool { behalten != [Bereich(von: 0, bis: dauer)] }
    var veraendert: Bool { schnittNoetig || stumm }
    var gueltig: Bool { ergebnisDauer >= Self.mindestdauer }

    /// Kürzt vorn und hinten. `false` (und nichts geändert), wenn danach zu wenig übrig bliebe.
    @discardableResult
    mutating func kuerzen(anfang neuerAnfang: Double, ende neuesEnde: Double) -> Bool {
        let von = min(max(neuerAnfang, 0), dauer)
        let bis = min(max(neuesEnde, 0), dauer)
        var probe = self
        probe.anfang = von
        probe.ende = bis
        guard bis > von, probe.gueltig else { return false }
        self = probe
        return true
    }

    /// Entfernt `von`...`bis` aus der Mitte. `false`, wenn der Bereich zu kurz ist oder das Ergebnis
    /// unter `mindestdauer` fiele; dann bleibt der Plan, wie er war.
    @discardableResult
    mutating func entfernen(von: Double, bis: Double) -> Bool {
        let bereich = Bereich(von: min(max(min(von, bis), 0), dauer), bis: min(max(max(von, bis), 0), dauer))
        guard bereich.laenge >= Self.kleinsterTeil else { return false }
        var probe = self
        probe.entfernt = Self.verschmolzen(entfernt + [bereich])
        guard probe.gueltig else { return false }
        self = probe
        return true
    }

    mutating func entfernenRueckgaengig(bei index: Int) {
        guard entfernt.indices.contains(index) else { return }
        entfernt.remove(at: index)
    }

    /// Überlappende oder aneinanderstoßende Bereiche werden zu einem.
    static func verschmolzen(_ bereiche: [Bereich]) -> [Bereich] {
        var ergebnis: [Bereich] = []
        for bereich in bereiche.sorted(by: { $0.von < $1.von }) {
            if let letzter = ergebnis.last, bereich.von <= letzter.bis {
                ergebnis[ergebnis.count - 1].bis = max(letzter.bis, bereich.bis)
            } else {
                ergebnis.append(bereich)
            }
        }
        return ergebnis
    }

    /// "0:07" bzw. "1:05" — für Anzeige der Länge.
    static func zeit(_ sekunden: Double) -> String {
        let ganz = max(Int(sekunden.rounded()), 0)
        return "\(ganz / 60):" + String(format: "%02d", ganz % 60)
    }
}

/// Setzt einen `SnapSchnitt` mit `AVMutableComposition` um: die bleibenden Teile werden
/// hintereinander in eine neue Spur gelegt, bei `stumm` ohne Tonspur. Das Ergebnis geht danach wie
/// jedes andere Video durch `MedienKodierung.video` (720p), hier wird nicht doppelt skaliert.
enum SnapSchnittExport {
    /// Länge des Videos in Sekunden, `nil` wenn es sich nicht lesen lässt.
    static func dauer(von quelle: URL) async -> Double? {
        guard let zeit = try? await AVURLAsset(url: quelle).load(.duration), zeit.seconds.isFinite, zeit.seconds > 0 else { return nil }
        return zeit.seconds
    }

    /// Ohne Änderung kommt `quelle` unverändert zurück (kein Export). `nil` = Export gescheitert.
    static func exportieren(quelle: URL, plan: SnapSchnitt) async -> URL? {
        guard plan.veraendert else { return quelle }
        guard plan.gueltig else { return nil }
        let asset = AVURLAsset(url: quelle)
        guard let bildSpur = try? await asset.loadTracks(withMediaType: .video).first,
              let transform = try? await bildSpur.load(.preferredTransform)
        else { return nil }
        var tonQuelle: AVAssetTrack?
        if !plan.stumm { tonQuelle = try? await asset.loadTracks(withMediaType: .audio).first }

        let komposition = AVMutableComposition()
        guard let bildZiel = komposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { return nil }
        bildZiel.preferredTransform = transform
        var tonZiel: AVMutableCompositionTrack?
        if tonQuelle != nil {
            tonZiel = komposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        }
        var einfuegen = CMTime.zero
        for teil in plan.behalten {
            let bereich = CMTimeRange(
                start: CMTime(seconds: teil.von, preferredTimescale: 600),
                duration: CMTime(seconds: teil.laenge, preferredTimescale: 600)
            )
            do {
                try bildZiel.insertTimeRange(bereich, of: bildSpur, at: einfuegen)
                if let tonZiel, let tonQuelle { try tonZiel.insertTimeRange(bereich, of: tonQuelle, at: einfuegen) }
            } catch {
                return nil
            }
            einfuegen = CMTimeAdd(einfuegen, bereich.duration)
        }

        guard let session = AVAssetExportSession(asset: komposition, presetName: AVAssetExportPresetHighestQuality) else { return nil }
        let ausgabe = FileManager.default.temporaryDirectory.appendingPathComponent("snap-schnitt-\(UUID().uuidString).mov")
        session.outputURL = ausgabe
        session.outputFileType = .mov
        await withCheckedContinuation { (fortsetzung: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { fortsetzung.resume() }
        }
        return session.status == .completed ? ausgabe : nil
    }
}
