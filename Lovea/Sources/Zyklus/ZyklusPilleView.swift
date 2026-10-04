import SwiftUI

/// Pille: Einnahme heute, Pausentage, Erinnerung. `packungStart` setzt den ersten Tag der Packung;
/// die Erinnerung kommt als Wert und Closure von außen (Planer), diese Ansicht kennt keine fremden Views.
struct ZyklusPilleView: View {
    let speicher: any ZyklusSpeicher
    var packung: ZyklusModiLogik.Packung = .einundzwanzig
    var packungStart: String?
    var heute: String = Datum.text(Date())
    var erinnerungAn = false
    var erinnerungUmschalten: (Bool) -> Void = { _ in }
    var scrollt = true

    @Environment(\.colorScheme) private var schema

    private var stand: ZyklusModiLogik.PillenStand? {
        let start = ZyklusModiLogik.pillenStart(gesetzt: packungStart, logik: speicher.logik(heute: heute), tage: Array(speicher.tage.values))
        return start.flatMap { ZyklusModiLogik.pillenStand(start: $0, packung: packung, heute: heute) }
    }

    var body: some View {
        ZStack {
            ZyklusHintergrund()
            if scrollt { ScrollView { inhalt } } else { inhalt }
        }
    }

    private var inhalt: some View {
        let genommen = ZyklusModiLogik.pilleGenommen(tage: speicher.tage, heute: heute)
        let s = stand
        return VStack(spacing: 16) {
            ZyklusRing(fortschritt: Double(s?.tagInPackung ?? 0) / Double(ZyklusModiLogik.packungsTage),
                       phase: s?.pause == true ? .periode : .follikel,
                       titel: s.map { "Tag \($0.tagInPackung)" } ?? "Hallo",
                       untertitel: untertitel(s))
            ZyklusKarte {
                kopf("Heute", symbol: "pills.fill")
                if s?.nehmen == false {
                    leise("Pausentag. Heute keine Tablette.")
                } else {
                    leise(genommen ? "Genommen. Fein gemacht." : "Noch nicht genommen.")
                    ZyklusKnopf(titel: genommen ? "Zurücknehmen" : "Genommen", symbol: genommen ? "arrow.uturn.backward" : "checkmark", leise: genommen, aktion: umschalten)
                }
                let serie = ZyklusModiLogik.pillenSerie(tage: speicher.tage, heute: heute)
                if serie > 1 { leise("\(serie) Tage in Folge.") }
            }
            ZyklusKarte(akzent: ZyklusFarbe.pfirsich.farbe(schema)) {
                Toggle(isOn: Binding(get: { erinnerungAn }, set: erinnerungUmschalten)) {
                    Label("Tägliche Erinnerung", systemImage: "bell.fill")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(ZyklusFarbe.tinte(schema))
                }
                .tint(ZyklusFarbe.himbeere.farbe(schema))
            }
        }
        .padding(16)
    }

    private func untertitel(_ s: ZyklusModiLogik.PillenStand?) -> String {
        guard let s else { return "Trag deinen ersten Pillentag ein" }
        if s.pause { return s.nehmen ? "Platzhalter" : "Pause" }
        return s.tageBisPause == 1 ? "Morgen beginnt die Pause" : "Noch \(s.tageBisPause) Tage bis zur Pause"
    }

    private func umschalten() {
        var tag = speicher.tage[heute] ?? ZyklusTag(id: heute)
        tag.pille = ZyklusModiLogik.pilleGenommen(tage: speicher.tage, heute: heute) ? nil : true
        speicher.setze(tag)
    }

    private func kopf(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(.headline, design: .rounded).weight(.bold))
            .foregroundStyle(ZyklusFarbe.tinte(schema))
    }

    private func leise(_ text: String) -> some View {
        Text(text)
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(ZyklusFarbe.tinteLeise(schema))
    }
}
