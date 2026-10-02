import SwiftUI

/// Treffen bearbeiten: Titel, von bis des Treffens, die Liste der Punkte (einer zugleich aufgeklappt),
/// darunter die Checkliste. Arbeitet nur auf den Bindings; gesendet wird erst mit „Fertig"
/// (`TreffenTagView`), über `TreffenPunktSender`.
struct TreffenBearbeitenInhalt: View {
    let datum: String
    let partner: Person
    let jetzt: Date
    @Binding var treffen: TreffenBearbeitung
    @Binding var punkte: [PunktBearbeitung]
    @Binding var offen: String?
    let checkliste: [KalenderModell.ChecklistEintrag]
    @Binding var neueAufgabe: String
    var abhaken: (KalenderModell.ChecklistEintrag) -> Void = { _ in }
    var aufgabeLoeschen: (KalenderModell.ChecklistEintrag) -> Void = { _ in }
    var aufgabeHinzufuegen: () -> Void = {}
    var jetztFreigeben: (String) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Titel", text: $treffen.titel)
                .font(.title.weight(.bold))
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            Divider()
            treffenZeile("Von", zeit: $treffen.von, standard: "12:00")
            Divider().padding(.leading, 20)
            treffenZeile("Bis", zeit: $treffen.bis, standard: Datum.uhrzeit(treffen.von ?? "12:00", plus: 120))
            Divider()
            programmKopf
            ForEach($punkte) { $punkt in
                if offen == punkt.id, !punkt.gesperrt {
                    PunktEditor(
                        datum: datum, partner: partner, punkt: $punkt, jetzt: jetzt,
                        einklappen: { offen = nil },
                        loeschen: { entfernen(punkt.id) },
                        jetztFreigeben: {
                            jetztFreigeben(punkt.id)
                            punkt.schonSichtbar = true
                            punkt.ueberraschung = nil
                        }
                    )
                } else {
                    kurzZeile(punkt)
                }
            }
            Divider()
            ChecklistAbschnitt(
                eintraege: checkliste, abhaken: abhaken, loeschen: aufgabeLoeschen,
                neu: $neueAufgabe, hinzufuegen: aufgabeHinzufuegen
            )
            .padding(.horizontal, 20)
        }
        .animation(Feder.schnell, value: offen)
    }

    private func treffenZeile(_ titel: String, zeit: Binding<String?>, standard: String) -> some View {
        HStack(spacing: 8) {
            Text(titel)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(TreffenAnsichtWerte.kurzDatum(datum))
                .font(.callout.weight(.semibold))
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
            ZeitPille(datum: datum, zeit: zeit, standard: standard)
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 20)
    }

    private var programmKopf: some View {
        HStack {
            Text("Programm · \(punkte.count) \(punkte.count == 1 ? "Punkt" : "Punkte")")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
            Button(action: punktHinzufuegen) {
                Label("Punkt", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.loveaRose)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Punkt hinzufügen")
        }
        .padding(.horizontal, 20)
    }

    private func kurzZeile(_ punkt: PunktBearbeitung) -> some View {
        let inhalt = HStack(spacing: 12) {
            Text(punkt.start ?? "–")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .frame(width: 52, alignment: .leading)
            Text(punkt.gesperrt ? "Überraschung von \(partner.name)" : (punkt.titel.isEmpty ? "Neuer Punkt" : punkt.titel))
                .lineLimit(1)
                .foregroundStyle(punkt.gesperrt ? .secondary : .primary)
            Spacer(minLength: 8)
            Image(systemName: punkt.gesperrt ? "lock.fill" : "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 20)
        .contentShape(Rectangle())
        return VStack(spacing: 0) {
            if punkt.gesperrt {
                inhalt
                    .accessibilityElement(children: .combine)
            } else {
                Button { offen = punkt.id } label: { inhalt }
                    .buttonStyle(.plain)
            }
            Divider().padding(.leading, 20)
        }
    }

    private func punktHinzufuegen() {
        let neu = PunktBearbeitung(neuAm: punkte.last(where: { !$0.gesperrt })?.ende ?? treffen.von)
        punkte.append(neu)
        offen = neu.id
    }

    private func entfernen(_ id: String) {
        offen = nil
        punkte.removeAll { $0.id == id }
    }
}
