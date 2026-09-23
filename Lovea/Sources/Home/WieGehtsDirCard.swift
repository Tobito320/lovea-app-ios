import SwiftUI
import UIKit

/// Z-19.3 (Spec 8.1 Nr. 2): nur noch Stimmung (gut/mittel/schlecht). Kein „brauche", kein Satz mehr
/// in der Oberfläche – alte `stimmung.setzen`-Ops mit diesen Feldern bleiben decodierbar
/// (`StimmungOp`/`KalenderModell.Stimmung`), sie werden nur nicht mehr angezeigt oder gesendet.
/// Beide sehen sich gegenseitig; die eigene Auswahl ist nur für die eigene Person editierbar.
struct WieGehtsDirCard: View {
    let kalender = KalenderModell.shared
    @Environment(\.dynamicTypeSize) private var schrift

    private var ich: Person { Raum.shared.ich ?? .ahmed }
    private var heute: String { Datum.text(Date()) }
    private var meineStimmung: KalenderModell.Stimmung? { kalender.zustand.stimmungen[heute]?[ich] }

    var body: some View {
        // Drei Knöpfe nebeneinander schneiden ab AX-Größen ab, dann untereinander.
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

            reihe {
                stimmungKnopf("gut", "sun.max.fill", "Gut")
                stimmungKnopf("mittel", "cloud.fill", "Mittel")
                stimmungKnopf("schlecht", "cloud.rain.fill", "Schlecht")
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
            } else {
                Image(systemName: "questionmark.circle")
                    .font(.title)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(person.name)
        .accessibilityValue(stimmung.map { stimmungText($0.stimmung) } ?? "noch keine Angabe")
    }

    private func stimmungKnopf(_ wert: String, _ symbol: String, _ titel: String) -> some View {
        let aktiv = meineStimmung?.stimmung == wert
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            senden(stimmung: wert)
        } label: {
            Label(titel, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(aktiv ? Color.loveaRose : .gray)
        .accessibilityAddTraits(aktiv ? .isSelected : [])
    }

    private func senden(stimmung: String) {
        Raum.shared.senden("stimmung.setzen", StimmungOp(datum: heute, stimmung: stimmung, brauche: nil, satz: nil))
        // Nur ein Hinweis für die Figur — Block 7 besitzt die endgültige Zustandsfaltung.
        FigurenModell.shared.zustandSenden(.init(haupt: FigurZustand(rawValue: stimmung) ?? .ruhig))
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
}

/// Feldnamen unverändert aus Runde 1 (`schnittstellen.md`) – `brauche`/`satz` bleiben optional, damit
/// alte Ops weiter decodieren, werden von dieser Karte aber nicht mehr gesetzt oder angezeigt.
private struct StimmungOp: Codable { var datum: String; var stimmung: String; var brauche: String?; var satz: String? }
