import SwiftUI

/// Kinderwunsch: fruchtbares Fenster, Tests, kurzes Tagebuch (Notiz von heute).
struct ZyklusKinderwunschView: View {
    let speicher: any ZyklusSpeicher
    var heute: String = Datum.text(Date())
    var scrollt = true

    @Environment(\.colorScheme) private var schema
    @State private var notiz = ""

    private var stand: ZyklusModiLogik.KinderwunschStand {
        ZyklusModiLogik.kinderwunschStand(logik: speicher.logik(heute: heute), tage: Array(speicher.tage.values), heute: heute)
    }

    var body: some View {
        ZStack {
            ZyklusHintergrund()
            if scrollt { ScrollView { inhalt } } else { inhalt }
        }
        .onAppear { notiz = speicher.tage[heute]?.notiz ?? "" }
    }

    private var inhalt: some View {
        let s = stand
        return VStack(spacing: 16) {
            ZyklusRing(fortschritt: fortschritt(s), phase: s.lage == .eisprung ? .eisprung : .fruchtbar,
                       titel: titel(s.lage), untertitel: untertitel(s))
            ZyklusKarte(akzent: ZyklusPhasenTon.eisprung.farbe(schema)) {
                kopf("Tests in diesem Zyklus", symbol: "testtube.2")
                Text("\(s.positiveTests) positiv, \(s.negativeTests) negativ")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(ZyklusFarbe.tinteLeise(schema))
                HStack(spacing: 8) {
                    testKnopf("Eisprungtest +", .positiv)
                    testKnopf("Eisprungtest −", .negativ)
                }
            }
            ZyklusKarte {
                kopf("Tagebuch", symbol: "book.fill")
                TextField("Was war heute wichtig?", text: $notiz, axis: .vertical)
                    .lineLimit(2...5)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(ZyklusFarbe.tinte(schema))
                ZyklusKnopf(titel: "Speichern", symbol: "checkmark", leise: true, aktion: notizSpeichern)
            }
        }
        .padding(16)
    }

    private func titel(_ lage: ZyklusModiLogik.KinderwunschStand.Lage) -> String {
        switch lage {
        case .eisprung: "Eisprung"
        case .fruchtbar: "Fruchtbar"
        case .bald(let t): t == 1 ? "Morgen" : "In \(t) Tagen"
        case .vorbei: "Geschafft"
        case .unbekannt: "Hallo"
        }
    }

    private func untertitel(_ s: ZyklusModiLogik.KinderwunschStand) -> String {
        guard let f = s.fenster else { return "Trag deine erste Periode ein" }
        if s.lage == .vorbei { return "Das Fenster ist zu" }
        return "\(Datum.anzeige(f.lowerBound)) bis \(Datum.anzeige(f.upperBound))"
    }

    private func fortschritt(_ s: ZyklusModiLogik.KinderwunschStand) -> Double {
        guard let f = s.fenster else { return 0 }
        if heute < f.lowerBound { return 0 }
        if heute > f.upperBound { return 1 }
        let gesamt = Double(Datum.tageZwischen(f.lowerBound, f.upperBound) + 1)
        return Double(Datum.tageZwischen(f.lowerBound, heute) + 1) / gesamt
    }

    private func testKnopf(_ titel: String, _ ergebnis: TestErgebnis) -> some View {
        let gewaehlt = speicher.tage[heute]?.eisprungTest == ergebnis
        return Button {
            var tag = speicher.tage[heute] ?? ZyklusTag(id: heute)
            tag.eisprungTest = gewaehlt ? nil : ergebnis
            speicher.setze(tag)
        } label: { ZyklusChip(titel: titel, gewaehlt: gewaehlt) }
            .buttonStyle(.plain)
    }

    private func notizSpeichern() {
        var tag = speicher.tage[heute] ?? ZyklusTag(id: heute)
        tag.notiz = notiz.isEmpty ? nil : notiz
        speicher.setze(tag)
    }

    private func kopf(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(.headline, design: .rounded).weight(.bold))
            .foregroundStyle(ZyklusFarbe.tinte(schema))
    }
}
