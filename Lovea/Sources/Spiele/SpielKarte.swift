import SwiftUI

/// The chat card for a message with `spiel` (Z-14.1): the invitation with "Annehmen" and a
/// countdown, then "Läuft", then "XO · 3× gespielt · Annika 2 : Ahmed 1". An invitation that
/// expired unanswered renders nothing; skip the whole row with `SpieleModell.shared.sichtbar(id)`.
struct SpielKarte: View {
    let nachricht: ChatModell.Nachricht
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var modell: SpieleModell { .shared }

    var body: some View {
        if let spielId = nachricht.spiel?.id {
            if let spiel = modell.spiele[spielId] {
                if spiel.wartet() {
                    TimelineView(.periodic(from: .now, by: 1)) { kontext in
                        if spiel.wartet(jetzt: kontext.date) { karte(spiel, jetzt: kontext.date) }
                    }
                } else if spiel.sichtbar() {
                    karte(spiel, jetzt: Date())
                }
            } else {
                rahmen {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Spiel wird geladen …").foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func karte(_ spiel: SpieleModell.Spiel, jetzt: Date) -> some View {
        let ich = Raum.shared.ich
        let eingeladen = spiel.von != ich
        let partner = ich?.partner.name ?? ""
        // At accessibility text sizes the row stacks, so "Annehmen" can't squeeze the title to nothing (Z-16.3).
        let zeile = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 12))
        return rahmen {
            VStack(alignment: .leading, spacing: 10) {
                zeile {
                    Image(systemName: spiel.art.symbol)
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(RoundedRectangle(cornerRadius: 13).fill(Color.loveaRose.gradient))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(titel(spiel)).font(.headline)
                        Text(untertitel(spiel, eingeladen: eingeladen, partner: partner, jetzt: jetzt))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 6)
                    if spiel.wartet(jetzt: jetzt) {
                        if eingeladen {
                            Button("Annehmen") { modell.annehmen(spiel.id) }
                                .buttonStyle(.borderedProminent)
                                .tint(.loveaRose)
                        }
                    } else if spiel.angenommen {
                        Button(spiel.ergebnis == nil ? "Öffnen" : "Weiter") { modell.offen = OffenesSpiel(id: spiel.id) }
                            .buttonStyle(.bordered)
                            .tint(.loveaRose)
                    }
                }
                if spiel.art == .duell, let bilder = letzteBilder(spiel), !bilder.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(bilder, id: \.self) { id in
                                SpielBild(medienId: id)
                                    .frame(width: 64, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
            }
        }
    }

    private func titel(_ spiel: SpieleModell.Spiel) -> String {
        guard let e = spiel.ergebnis else { return spiel.art.titel }
        return "\(spiel.art.titel) · \(e.gespielt)× gespielt"
    }

    private func untertitel(_ spiel: SpieleModell.Spiel, eingeladen: Bool, partner: String, jetzt: Date) -> String {
        if spiel.wartet(jetzt: jetzt) {
            let rest = max(0, Int((spiel.bis ?? jetzt).timeIntervalSince(jetzt)))
            let uhr = "\(rest / 60):\(rest % 60 < 10 ? "0" : "")\(rest % 60)"
            return eingeladen ? "\(spiel.von.name) fordert dich heraus · \(uhr)" : "Warte auf \(partner) · \(uhr)"
        }
        if let e = spiel.ergebnis { return e.punkte.text }
        return "Läuft gerade"
    }

    /// Duell: the pictures of the most recent round set ("Ergebnis in den Chat").
    private func letzteBilder(_ spiel: SpieleModell.Spiel) -> [String]? {
        guard spiel.ergebnis != nil, let letzte = spiel.bilder.keys.max() else { return nil }
        let partie = letzte / 10
        return spiel.bilder.keys.filter { $0 / 10 == partie }.sorted().flatMap { r in
            [Person.ahmed, .annika].compactMap { spiel.bilder[r]?[$0] }
        }
    }

    private func rahmen<Inhalt: View>(@ViewBuilder _ inhalt: () -> Inhalt) -> some View {
        inhalt()
            .padding(14)
            .frame(maxWidth: 340, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22).fill(Color(.secondarySystemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.loveaRose.opacity(0.35), lineWidth: 1))
    }
}

