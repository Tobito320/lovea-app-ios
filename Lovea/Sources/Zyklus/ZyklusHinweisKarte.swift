import SwiftUI

extension ZyklusPhasenTon {
    init(_ phase: Phase) {
        switch phase {
        case .periode: self = .periode
        case .follikel: self = .follikel
        case .fruchtbar: self = .fruchtbar
        case .eisprung: self = .eisprung
        case .luteal: self = .luteal
        }
    }
}

/// Süße Karte: Phase, Training und drei kurze Hinweise. Reines SwiftUI, nimmt nur Werte.
struct ZyklusHinweisKarte: View {
    let hinweis: ZyklusHinweis
    @Environment(\.colorScheme) private var schema

    var body: some View {
        let ton = ZyklusPhasenTon(hinweis.phase)
        ZyklusKarte(akzent: ton.farbe(schema)) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Dein Zyklus: \(ton.name)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(ton.farbe(schema))
                Text(hinweis.training)
                    .font(.headline)
                    .foregroundStyle(ZyklusFarbe.tinte(schema))
                zeile("bolt.heart", hinweis.energie)
                zeile("moon.stars", hinweis.schlaf)
                zeile("drop", hinweis.wasser)
                zeile("leaf", hinweis.ernaehrung)
                zeile("figure.walk", hinweis.schritte)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func zeile(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.subheadline)
            .foregroundStyle(ZyklusFarbe.tinteLeise(schema))
    }
}

/// Die eine Zeile für HeuteView und TrainingsPlanView. Zeigt nichts, solange der Schalter aus ist
/// (Standard), bei Ahmed oder bei Demo-Daten.
struct ZyklusHinweisEinhang: View {
    let person: Person
    var tag: String = Datum.text(Date())
    @AppStorage(ZyklusSchalter.imTraining) private var an = false

    var body: some View {
        if person == .annika, an,
           case let speicher = ZyklusSpeicherWahl.fuer(person: person),
           ZyklusVerknuepfung.zeigen(person: person, schalter: an, quelle: speicher.quelle),
           let h = ZyklusVerknuepfung.hinweis(logik: speicher.logik(heute: tag), am: tag) {
            ZyklusHinweisKarte(hinweis: h)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
        }
    }
}
