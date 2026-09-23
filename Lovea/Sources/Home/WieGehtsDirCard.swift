import SwiftUI

/// Spec 8.1 Nr. 2: Stimmung (gut/mittel/schlecht) und „brauche" (Nähe/Worte/Ruhe) mit optionalem
/// Satz. Beide sehen sich gegenseitig; die eigene Auswahl ist nur für die eigene Person editierbar.
struct WieGehtsDirCard: View {
    let kalender = KalenderModell.shared
    @State private var satz = ""

    private var ich: Person { Raum.shared.ich ?? .ahmed }
    private var heute: String { Datum.text(Date()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Wie geht's dir heute")
                .font(.headline)

            HStack(spacing: 20) {
                ForEach(Person.allCases, id: \.self) { person in
                    VStack(spacing: 4) {
                        Text(person.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let stimmung = kalender.zustand.stimmungen[heute]?[person] {
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
                    .frame(maxWidth: .infinity)
                }
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    stimmungKnopf("gut", "sun.max.fill", "Gut")
                    stimmungKnopf("mittel", "cloud.fill", "Mittel")
                    stimmungKnopf("schlecht", "cloud.rain.fill", "Schlecht")
                }
                HStack(spacing: 8) {
                    brauchKnopf("naehe", "Nähe")
                    brauchKnopf("worte", "Worte")
                    brauchKnopf("ruhe", "Ruhe")
                }
                TextField("Ein Satz dazu (optional)", text: $satz)
                    .textFieldStyle(.roundedBorder)
                    .font(.footnote)
                    .onSubmit {
                        guard let stimmung = kalender.zustand.stimmungen[heute]?[ich]?.stimmung else { return }
                        senden(stimmung: stimmung, brauche: kalender.zustand.stimmungen[heute]?[ich]?.brauche)
                    }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func stimmungKnopf(_ wert: String, _ symbol: String, _ titel: String) -> some View {
        let aktiv = kalender.zustand.stimmungen[heute]?[ich]?.stimmung == wert
        return Button {
            senden(stimmung: wert, brauche: kalender.zustand.stimmungen[heute]?[ich]?.brauche)
        } label: {
            Label(titel, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.bordered)
        .tint(aktiv ? Color.loveaRose : .gray)
    }

    private func brauchKnopf(_ wert: String, _ titel: String) -> some View {
        let aktiv = kalender.zustand.stimmungen[heute]?[ich]?.brauche == wert
        return Button(titel) {
            guard let stimmung = kalender.zustand.stimmungen[heute]?[ich]?.stimmung else { return }
            senden(stimmung: stimmung, brauche: aktiv ? nil : wert)
        }
        .font(.caption.weight(.semibold))
        .frame(maxWidth: .infinity, minHeight: 32)
        .buttonStyle(.bordered)
        .tint(aktiv ? Color.loveaRose : .gray)
    }

    private func senden(stimmung: String, brauche: String?) {
        Raum.shared.senden("stimmung.setzen", StimmungOp(datum: heute, stimmung: stimmung, brauche: brauche, satz: satz.isEmpty ? nil : satz))
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

    private func brauchText(_ brauche: String) -> String {
        switch brauche {
        case "naehe": "braucht Nähe"
        case "worte": "braucht Worte"
        case "ruhe": "braucht Ruhe"
        default: brauche
        }
    }
}

private struct StimmungOp: Codable { var datum: String; var stimmung: String; var brauche: String?; var satz: String? }
