import SwiftUI
import UIKit

/// Die sechs „brauche"-Werte. Rohwerte gehen unverändert über die Op (`stimmung.setzen`, Feld
/// `brauche`); der Server prüft sie nicht, ältere Apps zeigen unbekannte Werte als Rohtext.
/// Neu (Annikas Wunsch): Aufmerksamkeit, Freiraum, Keine Probleme heute.
enum Brauch: String, CaseIterable {
    case naehe, worte, ruhe, aufmerksamkeit, freiraum, keineProbleme

    /// Beschriftung des Knopfs.
    var titel: String {
        switch self {
        case .naehe: "Nähe"
        case .worte: "Worte"
        case .ruhe: "Ruhe"
        case .aufmerksamkeit: "Aufmerksamkeit"
        case .freiraum: "Freiraum"
        case .keineProbleme: "Keine Probleme heute"
        }
    }

    /// Anzeige unter dem Namen der Person.
    var anzeige: String {
        switch self {
        case .naehe: "braucht Nähe"
        case .worte: "braucht Worte"
        case .ruhe: "braucht Ruhe"
        case .aufmerksamkeit: "möchte Aufmerksamkeit"
        case .freiraum: "braucht Freiraum"
        case .keineProbleme: "keine Probleme heute"
        }
    }

    /// Unbekannter Rohwert (neuere App, ältere App): als Text durchreichen statt zu verschwinden.
    static func anzeige(fuer roh: String) -> String { Brauch(rawValue: roh)?.anzeige ?? roh }
}

/// Spec 8.1 Nr. 2: Stimmung (gut/mittel/schlecht) und „brauche" (`Brauch`, 2x3), pro Tag
/// gespeichert und jederzeit erneut änderbar. Beide sehen sich gegenseitig; die eigene Auswahl ist
/// nur für die eigene Person editierbar. Z-19.3 hatte „brauche" aus der Oberfläche entfernt, hier
/// wieder da (Ahmed, 04.10.2026).
struct WieGehtsDirCard: View {
    let kalender = KalenderModell.shared
    @Environment(\.dynamicTypeSize) private var schrift

    private var ich: Person { Raum.shared.ich ?? .ahmed }
    private var heute: String { Datum.text(Date()) }
    private var meineStimmung: KalenderModell.Stimmung? { kalender.zustand.stimmungen[heute]?[ich] }

    var body: some View {
        // Drei Knöpfe nebeneinander schneiden ab AX-Größen ab, dann untereinander.
        let spalten = Array(repeating: GridItem(.flexible(), spacing: 8), count: schrift.isAccessibilitySize ? 1 : 3)
        let reihe = schrift.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        VStack(alignment: .leading, spacing: 14) {
            Text("Wie geht's dir heute")
                .font(.headline)

            HStack(alignment: .top, spacing: 20) {
                ForEach(Person.allCases, id: \.self) { person in
                    personSpalte(person)
                        .frame(maxWidth: .infinity)
                }
            }

            VStack(spacing: 8) {
                reihe {
                    stimmungKnopf("gut", "sun.max.fill", "Gut")
                    stimmungKnopf("mittel", "cloud.fill", "Mittel")
                    stimmungKnopf("schlecht", "cloud.rain.fill", "Schlecht")
                }
                LazyVGrid(columns: spalten, spacing: 8) {
                    ForEach(Brauch.allCases, id: \.self) { brauchKnopf($0) }
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func personSpalte(_ person: Person) -> some View {
        let stimmung = kalender.zustand.stimmungen[heute]?[person]
        return VStack(spacing: 4) {
            Text(person.name)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let stimmung {
                Image(systemName: symbol(stimmung.stimmung))
                    .font(.title)
                    .foregroundStyle(Color.person(person))
                if let brauche = stimmung.brauche {
                    Text(brauchText(brauche))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "questionmark.circle")
                    .font(.title)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(person.name)
        .accessibilityValue(vorleseText(stimmung))
    }

    private func vorleseText(_ stimmung: KalenderModell.Stimmung?) -> String {
        guard let stimmung else { return "noch keine Angabe" }
        var teile = [stimmungText(stimmung.stimmung)]
        if let brauche = stimmung.brauche { teile.append(brauchText(brauche)) }
        return teile.joined(separator: ", ")
    }

    private func stimmungKnopf(_ wert: String, _ symbol: String, _ titel: String) -> some View {
        let aktiv = meineStimmung?.stimmung == wert
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            senden(stimmung: wert, brauche: meineStimmung?.brauche)
        } label: {
            Label(titel, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(aktiv ? Color.loveaRose : .gray)
        .accessibilityAddTraits(aktiv ? .isSelected : [])
    }

    private func brauchKnopf(_ brauch: Brauch) -> some View {
        let wert = brauch.rawValue
        let aktiv = meineStimmung?.brauche == wert
        return Button {
            guard let stimmung = meineStimmung?.stimmung else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            senden(stimmung: stimmung, brauche: aktiv ? nil : wert)
        } label: {
            Text(brauch.titel)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(aktiv ? Color.loveaRose : .gray)
        // „Brauche" hängt an einer Stimmung, ohne sie würde der Knopf nichts tun.
        .disabled(meineStimmung == nil)
        .accessibilityAddTraits(aktiv ? .isSelected : [])
    }

    private func senden(stimmung: String, brauche: String?) {
        Raum.shared.senden("stimmung.setzen", StimmungOp(datum: heute, stimmung: stimmung, brauche: brauche, satz: nil))
        // Nur ein Hinweis für die Figur — Block 7 besitzt die endgültige Zustandsfaltung.
        let haupt: FigurZustand = brauche.flatMap(FigurZustand.init(rawValue:)) ?? FigurZustand(rawValue: stimmung) ?? .ruhig
        FigurenModell.shared.zustandSenden(.init(haupt: haupt))
    }

    private func symbol(_ stimmung: String) -> String {
        switch stimmung {
        case "gut": "sun.max.fill"
        case "schlecht": "cloud.rain.fill"
        default: "cloud.fill"
        }
    }

    private func stimmungText(_ stimmung: String) -> String {
        switch stimmung {
        case "gut": "gut"
        case "schlecht": "schlecht"
        default: "mittel"
        }
    }

    private func brauchText(_ brauche: String) -> String {
        Brauch.anzeige(fuer: brauche)
    }
}

/// Feldnamen unverändert aus Runde 1 (`schnittstellen.md`) – `satz` bleibt optional/unversendet,
/// es gibt kein Kurzsatz-Feld mehr in dieser Karte.
private struct StimmungOp: Codable { var datum: String; var stimmung: String; var brauche: String?; var satz: String? }
