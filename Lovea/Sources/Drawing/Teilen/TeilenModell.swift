import Foundation
import Observation

// Drawing Level 2: sharing rights, stands and live messages (Spec 10, Schnittstellen "Zeichnen").

enum TeilenStufe: String, Codable, Sendable, CaseIterable, Identifiable {
    case aus, ansehen, bearbeiten

    var id: String { rawValue }
    var titel: String {
        switch self {
        case .aus: "Aus"
        case .ansehen: "Nur ansehen"
        case .bearbeiten: "Ansehen und bearbeiten"
        }
    }
}

struct ProjektTeilen: Codable, Equatable, Sendable {
    var projektId: String
    var name: String
    var stufe: TeilenStufe
}

struct ZeichnungRecht: Codable, Equatable, Sendable {
    var zeichnungId: String
    var bearbeiten: Bool
}

struct ZeichnungEinladung: Codable, Equatable, Sendable {
    var zeichnungId: String
    var name: String
}

/// Saved state of a drawing: document JSON, one PNG per layer and a preview, each its own medium.
struct ZeichnungStand: Codable, Equatable, Sendable {
    struct Ebene: Codable, Equatable, Sendable {
        var ebene: String
        var medienId: String
    }

    var zeichnungId: String
    /// The document JSON.
    var medienId: String
    /// Highest `seq` of this drawing's ops contained in the stand.
    var basis: Int
    var ebenen: [Ebene]
    var name: String?
    var projektId: String?
    var vorschau: String?
    /// Owner's own ops contained although still unconfirmed at saving: skipped when catching up.
    var offen: [String]?
    /// `updatedAt` of the uploaded document (seconds since 1970), so the owner can skip unchanged publishes.
    var gespeichert: Double?
}

/// One finished action. Strokes and fills are replayed from their data, so the partner's work
/// underneath stays; everything else (transform, adjust, clear, text …) travels as the resulting pixels.
enum ZeichnungAktion: Codable, Equatable, Sendable {
    /// The whole stroke. ponytail: exact points, so the replay matches the local pixels; a long
    /// stroke is some 10–30 KB of JSON. Delta-encode the points if the op log gets heavy.
    case strich(LiveStrich)
    case fuellen(x: Double, y: Double, farbe: String, toleranz: Double, alleEbenen: Bool, ebene: String)
    /// Region of a layer replaced by an uploaded PNG.
    case pixel(ebene: String, x: Int, y: Int, breite: Int, hoehe: Int, medienId: String)
    /// Layers added, removed, changed or moved (also the partner lock, Z-13.3).
    case ebenen(EbenenAenderung)
}

struct ZeichnungOp: Codable, Sendable {
    /// Domain id; `zeichnung.rueckgaengig.opId` points here, since `Raum.senden` hands out no `Op.id`.
    var id: String
    var zeichnungId: String
    /// Highest `seq` the sender had applied.
    var basis: Int
    var aktion: ZeichnungAktion
}

/// `zeichnung.rueckgaengig`: the author takes back one own op. `wieder` (extension): redo it.
struct ZeichnungRueckgaengig: Codable, Sendable {
    var zeichnungId: String
    var opId: String
    var wieder: Bool?
}

/// Pure fold of all drawing-sharing ops of both people.
struct TeilenStand: Sendable {
    struct Eintrag<T: Sendable>: Sendable {
        var id: String
        var seq: Int?
        var von: Person
        var wert: T
    }

    private(set) var projekte: [String: Eintrag<ProjektTeilen>] = [:]
    private(set) var rechte: [String: Eintrag<ZeichnungRecht>] = [:]
    private(set) var einladungen: [String: Eintrag<ZeichnungEinladung>] = [:]
    private(set) var staende: [String: Eintrag<ZeichnungStand>] = [:]
    /// Confirmed `zeichnung.op` and `zeichnung.rueckgaengig` newer than the drawing's latest stand.
    private var opsNachStand: [String: [Op]] = [:]

    private struct Kopf: Decodable {
        var zeichnungId: String
    }

    mutating func anwenden(_ op: Op) {
        switch op.art {
        case "projekt.teilen":
            if let d = op.daten(ProjektTeilen.self) { Self.setzen(&projekte, d.projektId, op, d) }
        case "zeichnung.recht":
            if let d = op.daten(ZeichnungRecht.self) { Self.setzen(&rechte, d.zeichnungId, op, d) }
        case "zeichnung.einladung":
            if let d = op.daten(ZeichnungEinladung.self) { Self.setzen(&einladungen, d.zeichnungId, op, d) }
        case "zeichnung.stand":
            guard let d = op.daten(ZeichnungStand.self) else { return }
            Self.setzen(&staende, d.zeichnungId, op, d)
            let basis = staende[d.zeichnungId]?.wert.basis ?? 0
            opsNachStand[d.zeichnungId]?.removeAll { ($0.seq ?? 0) <= basis }
        case "zeichnung.op", "zeichnung.rueckgaengig":
            guard let seq = op.seq, let d = op.daten(Kopf.self) else { return }
            let bekannt = opsNachStand[d.zeichnungId]?.contains { $0.id == op.id } ?? false
            if seq > staende[d.zeichnungId]?.wert.basis ?? 0, !bekannt { opsNachStand[d.zeichnungId, default: []].append(op) }
        default:
            break
        }
    }

    /// Every key here is written by one person only (the owner), so arrival order is their send order.
    /// The echo of an older op must not undo a newer optimistic one.
    private static func setzen<T: Sendable>(_ tabelle: inout [String: Eintrag<T>], _ schluessel: String, _ op: Op, _ wert: T) {
        if let alt = tabelle[schluessel], alt.id != op.id, let seq = op.seq {
            guard let altSeq = alt.seq, seq >= altSeq else { return }
        }
        tabelle[schluessel] = Eintrag(id: op.id, seq: op.seq, von: op.von, wert: wert)
    }

    // MARK: Queries

    func stufe(projekt: String) -> TeilenStufe {
        projekte[projekt]?.wert.stufe ?? .aus
    }

    /// Own drawing: the partner may see it (shared project or invitation).
    func istGeteilt(_ document: ArtworkDocument) -> Bool {
        let imProjekt = document.projectID.map { stufe(projekt: $0.uuidString) != .aus } ?? false
        return imProjekt || einladungen[document.id.uuidString] != nil
    }

    /// Partner drawing: I may still see it.
    func sichtbar(_ stand: ZeichnungStand) -> Bool {
        let imProjekt = stand.projektId.map { stufe(projekt: $0) != .aus } ?? false
        return imProjekt || einladungen[stand.zeichnungId] != nil
    }

    /// The partner may edit (project level or per drawing, Z-13.1).
    func darfBearbeiten(zeichnungId: String, projektId: String?) -> Bool {
        projektId.map { stufe(projekt: $0) == .bearbeiten } ?? false || rechte[zeichnungId]?.wert.bearbeiten == true
    }

    func geteilteProjekte(von person: Person) -> [ProjektTeilen] {
        projekte.values.filter { $0.von == person && $0.wert.stufe != .aus }.map(\.wert)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func geteilteStaende(von person: Person) -> [ZeichnungStand] {
        staende.values.filter { $0.von == person && sichtbar($0.wert) }.map(\.wert)
            .sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }
    }

    func ops(nach basis: Int, zeichnungId: String) -> [Op] {
        (opsNachStand[zeichnungId] ?? []).filter { ($0.seq ?? 0) > basis }.sorted { ($0.seq ?? 0) < ($1.seq ?? 0) }
    }
}

/// App-wide fold plus the send side of the rights. Partner drawings live in their own library.
@MainActor @Observable
final class TeilenModell {
    static let shared = TeilenModell()

    private(set) var stand = TeilenStand()
    let bibliothek: ArtworkLibrary

    private init() {
        bibliothek = ArtworkLibrary(
            rootURL: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Lovea/Geteilt", isDirectory: true)
        )
        Raum.shared.beobachten([
            "projekt.teilen", "zeichnung.recht", "zeichnung.einladung", "zeichnung.stand", "zeichnung.op", "zeichnung.rueckgaengig"
        ]) { [weak self] op in
            guard let self else { return }
            self.stand.anwenden(op)
            guard let offen = LiveZeichnung.shared.offen else { return }
            if op.art == "zeichnung.stand", op.von != Raum.shared.ich, let d = op.daten(ZeichnungStand.self) { offen.standEmpfangen(d) }
            // Own echoes too: they confirm the own ops.
            if op.art == "zeichnung.op" || op.art == "zeichnung.rueckgaengig" { offen.opEmpfangen(op) }
        }
    }

    /// Sets the project level. Sharing publishes every drawing of the project once.
    func projektTeilen(_ project: ArtworkProject, stufe: TeilenStufe, library: ArtworkLibrary) {
        Raum.shared.senden("projekt.teilen", ProjektTeilen(projektId: project.id.uuidString, name: project.name, stufe: stufe))
        guard stufe != .aus else { return }
        for artwork in library.artworks where artwork.projectID == project.id {
            StandPaket.planen(artwork.id, library: library)
        }
    }

    func bearbeitenErlauben(_ artworkID: UUID, _ erlaubt: Bool) {
        Raum.shared.senden("zeichnung.recht", ZeichnungRecht(zeichnungId: artworkID.uuidString, bearbeiten: erlaubt))
    }
}
