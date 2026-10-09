import SwiftUI

typealias RDaten = ZimmerRitualeDaten
typealias RLogik = ZimmerRitualeLogik

/// Glückskeks: heutige Frage, eigene Antwort, die des Partners erst, wenn beide geantwortet haben.
struct ZimmerKeksBlatt: View {
    @Environment(\.dismiss) private var dismiss
    @State private var eingabe = ""
    @State private var gespeichert = 0
    private let modell = EinstellungenModell.shared

    private var ich: Person { RDaten.ich }
    private var meine: String? { RDaten.keksAntwort(von: ich) }
    private var partner: String? { RDaten.keksAntwort(von: ich.partner) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Frage von heute") {
                    Text(ZimmerRitualeFragen.frage(tag: RDaten.heute)).font(.headline)
                }
                Section("Deine Antwort") {
                    if let meine {
                        Text(meine)
                    } else {
                        TextField("Schreib kurz auf", text: $eingabe, axis: .vertical)
                            .lineLimit(1...4)
                            .onChange(of: eingabe) { _, neu in
                                if neu.count > RLogik.antwortMaximum { eingabe = String(neu.prefix(RLogik.antwortMaximum)) }
                            }
                        Button("Antwort verstecken") { speichern() }
                            .disabled(RLogik.bereinigt(eingabe, maximal: RLogik.antwortMaximum) == nil)
                            .accessibilityLabel("Antwort speichern")
                    }
                }
                Section("Antwort von \(ich.partner.name)") {
                    if RLogik.antwortenOffen(meine: meine, partner: partner), let partner {
                        Text(partner)
                    } else if meine == nil {
                        Text("Erst du, dann siehst du die Antwort.").foregroundStyle(.secondary)
                    } else if partner == nil {
                        Text("\(ich.partner.name) hat noch nicht geantwortet. Kein Stress.").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Glückskeks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .sensoryFeedback(.success, trigger: gespeichert)
        .presentationDetents([.medium, .large])
    }

    private func speichern() {
        guard let text = RLogik.bereinigt(eingabe, maximal: RLogik.antwortMaximum) else { return }
        RDaten.schreiben(RDaten.keks, RDaten.KeksAntwort(tag: RDaten.heute, antwort: text))
        gespeichert += 1
    }
}

/// Wunschglas: eigene Wünsche aufschreiben, die des Partners lesen und heimlich als erfüllt markieren.
struct ZimmerWunschBlatt: View {
    @Environment(\.dismiss) private var dismiss
    @State private var eingabe = ""
    @State private var tipp = 0
    private let modell = EinstellungenModell.shared

    private var ich: Person { RDaten.ich }

    var body: some View {
        let meine = RDaten.meineWuensche()
        let partner = RDaten.partnerWuensche()
        let meinErfuellt = RDaten.erfuellteIds(von: ich.partner) // vom Partner für meine Wünsche gesetzt
        let partnerErfuellt = RDaten.erfuellteIds(von: ich) // von mir für seine Wünsche gesetzt
        NavigationStack {
            Form {
                Section("Meine Wünsche") {
                    ForEach(meine) { w in
                        HStack {
                            Image(systemName: meinErfuellt.contains(w.id) ? "star.fill" : "star")
                                .foregroundStyle(meinErfuellt.contains(w.id) ? ZimmerRitualeZeichnung.gold : Color.secondary)
                            Text(w.text)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(meinErfuellt.contains(w.id) ? "\(w.text), erfüllt" : w.text)
                    }
                    .onDelete { idx in
                        RDaten.schreiben(RDaten.wuensche, meine.enumerated().filter { !idx.contains($0.offset) }.map(\.element))
                    }
                    if meine.count < RLogik.wuenscheMaximum {
                        HStack {
                            TextField("Neuer Wunsch", text: $eingabe)
                                .onChange(of: eingabe) { _, neu in
                                    if neu.count > RLogik.wunschMaximum { eingabe = String(neu.prefix(RLogik.wunschMaximum)) }
                                }
                                .onSubmit { hinzu(meine) }
                            Button { hinzu(meine) } label: { Image(systemName: "plus.circle.fill") }
                                .disabled(RLogik.bereinigt(eingabe, maximal: RLogik.wunschMaximum) == nil)
                                .accessibilityLabel("Wunsch ins Glas legen")
                        }
                    } else {
                        Text("Das Glas ist voll.").foregroundStyle(.secondary)
                    }
                }
                Section("Wünsche von \(ich.partner.name)") {
                    if partner.isEmpty { Text("Noch nichts im Glas.").foregroundStyle(.secondary) }
                    ForEach(partner) { w in
                        let fertig = partnerErfuellt.contains(w.id)
                        Button {
                            tipp += 1
                            RDaten.schreiben(RDaten.erfuellt, RLogik.umschalten(partnerErfuellt, id: w.id))
                        } label: {
                            HStack {
                                Text(w.text).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: fertig ? "star.fill" : "star")
                                    .foregroundStyle(fertig ? ZimmerRitualeZeichnung.gold : Color.secondary)
                            }
                        }
                        .accessibilityLabel(w.text)
                        .accessibilityValue(fertig ? "heimlich erfüllt" : "noch offen")
                        .accessibilityHint("Doppeltippen, um heimlich als erfüllt zu markieren. \(ich.partner.name) sieht den goldenen Stern.")
                    }
                }
            }
            .navigationTitle("Wunschglas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .sensoryFeedback(.success, trigger: tipp)
        .presentationDetents([.medium, .large])
    }

    private func hinzu(_ meine: [RLogik.Wunsch]) {
        let neu = RLogik.wunschHinzu(meine, text: eingabe, id: UUID().uuidString)
        guard neu != meine else { return }
        RDaten.schreiben(RDaten.wuensche, neu)
        eingabe = ""
        tipp += 1
    }
}
