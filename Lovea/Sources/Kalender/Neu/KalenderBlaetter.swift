import SwiftUI

/// Die Blätter der neuen Ansichten, eins zur Zeit. Dieselben Fälle wie das private `Blatt` der
/// alten `TagesAnsicht`, die unangetastet bleibt.
enum KalenderBlatt: Identifiable {
    case termin(Termin?)
    case ausnahme(Ausnahme?)
    case zumIPhone(Termin)
    case ausIPhone
    case arbeitszeit(Block)

    var id: String {
        switch self {
        case .termin(let termin): "termin-\(termin?.id ?? "neu")"
        case .ausnahme(let ausnahme): "ausnahme-\(ausnahme?.id ?? "neu")"
        case .zumIPhone(let termin): "export-\(termin.id)"
        case .ausIPhone: "import"
        case .arbeitszeit(let block): "arbeit-\(block.musterId ?? "")"
        }
    }
}

/// Was ein Tipp oder langes Drücken auf einer Zeile auslöst. Die Ansichten kennen nur diese
/// Funktionen, nie `Raum` oder das Modell: so lassen sie sich in der Render-Tafel zeichnen.
struct TagesAktionen {
    var bearbeiten: (Termin) -> Void = { _ in }
    var zumIPhone: (Termin) -> Void = { _ in }
    var loeschen: (Termin) -> Void = { _ in }
    var arbeitszeit: (Block) -> Void = { _ in }
    var ausnahme: (Ausnahme) -> Void = { _ in }
    var zuruecknehmen: (Ausnahme) -> Void = { _ in }
    var treffen: () -> Void = {}

    /// Die echten Aktionen: Blatt öffnen oder die Op senden (wie in der alten `TagesAnsicht`).
    @MainActor
    static func live(blatt: Binding<KalenderBlatt?>, treffen: @escaping () -> Void) -> TagesAktionen {
        TagesAktionen(
            bearbeiten: { blatt.wrappedValue = .termin($0) },
            zumIPhone: { blatt.wrappedValue = .zumIPhone($0) },
            loeschen: { termin in
                Raum.shared.senden("termin.loeschen", ["id": termin.id])
                Haptik.leicht()
            },
            arbeitszeit: { blatt.wrappedValue = .arbeitszeit($0) },
            ausnahme: { blatt.wrappedValue = .ausnahme($0) },
            zuruecknehmen: { ausnahme in
                Raum.shared.senden("ausnahme.loeschen", AusnahmeSchluessel(ausnahme))
                Haptik.leicht()
            },
            treffen: treffen
        )
    }
}

private struct KalenderBlaetter: ViewModifier {
    let tag: String
    @Binding var blatt: KalenderBlatt?

    func body(content: Content) -> some View {
        content.sheet(item: $blatt) { inhalt($0) }
    }

    @ViewBuilder
    private func inhalt(_ blatt: KalenderBlatt) -> some View {
        switch blatt {
        case .termin(let termin): TerminEditor(datum: tag, termin: termin)
        case .ausnahme(let ausnahme): AusnahmeEditor(datum: tag, ausnahme: ausnahme)
        case .arbeitszeit(let block): ArbeitszeitBlatt(datum: tag, block: block)
        case .zumIPhone(let termin): IPhoneKalenderExportBlatt(termin: termin)
        case .ausIPhone: IPhoneKalenderImport()
        }
    }
}

extension View {
    /// Hängt die Editor-Blätter für `tag` an.
    func kalenderBlaetter(tag: String, blatt: Binding<KalenderBlatt?>) -> some View {
        modifier(KalenderBlaetter(tag: tag, blatt: blatt))
    }
}

/// Das „+"-Menü, in Monat und Tag gleich: Termin anlegen, Ausnahme setzen, aus iPhone-Kalender holen.
struct KalenderPlusMenue: View {
    let waehle: (KalenderBlatt) -> Void

    var body: some View {
        Menu {
            Button("Termin anlegen", systemImage: "calendar.badge.plus") { waehle(.termin(nil)) }
            Button("Ausnahme setzen", systemImage: "calendar.badge.exclamationmark") { waehle(.ausnahme(nil)) }
            Button("Aus iPhone-Kalender holen", systemImage: "square.and.arrow.down") { waehle(.ausIPhone) }
        } label: {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Hinzufügen")
    }
}
