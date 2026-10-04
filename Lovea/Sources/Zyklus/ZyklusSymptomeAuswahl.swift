import SwiftUI

extension Blutung {
    var eintragTitel: String {
        switch self {
        case .schmierblutung: "Schmier"
        case .leicht: "Leicht"
        case .mittel: "Mittel"
        case .stark: "Stark"
        }
    }
}

extension Symptom {
    var eintragTitel: String {
        switch self {
        case .kopfschmerzen: "Kopf"
        case .kraempfe: "Krämpfe"
        case .rueckenschmerzen: "Rücken"
        case .brustspannen: "Brust"
        case .uebelkeit: "Übelkeit"
        case .blaehbauch: "Blähbauch"
        case .akne: "Akne"
        case .muedigkeit: "Müdigkeit"
        case .heisshunger: "Heißhunger"
        case .schwindel: "Schwindel"
        case .verstopfung: "Verstopfung"
        case .durchfall: "Durchfall"
        }
    }
}

extension Stimmung {
    var eintragTitel: String {
        switch self {
        case .froehlich: "Fröhlich"
        case .ruhig: "Ruhig"
        case .energiegeladen: "Voller Energie"
        case .empfindlich: "Empfindlich"
        case .gereizt: "Gereizt"
        case .traurig: "Traurig"
        case .aengstlich: "Ängstlich"
        case .gestresst: "Gestresst"
        }
    }
}

extension Ausfluss {
    var eintragTitel: String {
        switch self {
        case .keiner: "Keiner"
        case .klebrig: "Klebrig"
        case .cremig: "Cremig"
        case .waessrig: "Wässrig"
        case .eiweissartig: "Eiweißartig"
        }
    }
}

extension TestErgebnis {
    var eintragTitel: String {
        switch self {
        case .negativ: "Negativ"
        case .positiv: "Positiv"
        }
    }
}

extension SexEintrag {
    var eintragTitel: String {
        switch self {
        case .geschuetzt: "Geschützt"
        case .ungeschuetzt: "Ungeschützt"
        }
    }
}

struct ZyklusAuswahlOption<Wert: Hashable>: Identifiable {
    var wert: Wert
    var titel: String
    var id: Wert { wert }
}

/// Bricht Chips in Zeilen um. Eigenes Layout, damit auch ImageRenderer es zeichnet (Lazy-Raster zeichnet er nicht).
struct ZyklusFlussLayout: Layout {
    var abstand: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        anordnen(proposal.width ?? 320, subviews).groesse
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let ergebnis = anordnen(bounds.width, subviews)
        for (index, punkt) in ergebnis.punkte.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + punkt.x, y: bounds.minY + punkt.y), proposal: .unspecified)
        }
    }

    private func anordnen(_ breite: CGFloat, _ subviews: Subviews) -> (punkte: [CGPoint], groesse: CGSize) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var zeile: CGFloat = 0
        var maxX: CGFloat = 0
        var punkte: [CGPoint] = []
        for teil in subviews {
            let groesse = teil.sizeThatFits(.unspecified)
            if x > 0, x + groesse.width > breite {
                x = 0
                y += zeile + abstand
                zeile = 0
            }
            punkte.append(CGPoint(x: x, y: y))
            x += groesse.width + abstand
            zeile = max(zeile, groesse.height)
            maxX = max(maxX, x - abstand)
        }
        return (punkte, CGSize(width: maxX, height: y + zeile))
    }
}

/// Chips zum Antippen, Mehrfachwahl.
struct ZyklusMehrfachAuswahl<Wert: Hashable>: View {
    var optionen: [ZyklusAuswahlOption<Wert>]
    @Binding var gewaehlt: Set<Wert>

    var body: some View {
        ZyklusFlussLayout {
            ForEach(optionen) { option in
                let an = gewaehlt.contains(option.wert)
                Button {
                    if an { gewaehlt.remove(option.wert) } else { gewaehlt.insert(option.wert) }
                } label: {
                    ZyklusChip(titel: option.titel, gewaehlt: an)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.titel)
            }
        }
    }
}

/// Chips zum Antippen, Einzelwahl. Ein zweiter Tipp nimmt die Wahl zurück.
struct ZyklusEinzelAuswahl<Wert: Hashable>: View {
    var optionen: [ZyklusAuswahlOption<Wert>]
    @Binding var gewaehlt: Wert?

    var body: some View {
        ZyklusFlussLayout {
            ForEach(optionen) { option in
                let an = gewaehlt == option.wert
                Button {
                    gewaehlt = an ? nil : option.wert
                } label: {
                    ZyklusChip(titel: option.titel, gewaehlt: an)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.titel)
            }
        }
    }
}

/// Alle Symptome als Chip-Raster.
struct ZyklusSymptomeAuswahl: View {
    @Binding var gewaehlt: Set<Symptom>

    var body: some View {
        ZyklusMehrfachAuswahl(
            optionen: Symptom.allCases.map { ZyklusAuswahlOption(wert: $0, titel: $0.eintragTitel) },
            gewaehlt: $gewaehlt
        )
    }
}
