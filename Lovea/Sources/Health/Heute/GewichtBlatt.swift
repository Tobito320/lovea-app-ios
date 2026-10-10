import Charts
import SwiftUI

/// Gewicht eintragen, ein Eintrag je Tag. Mit `tagWaehlbar` wählt man den Tag (nie in der Zukunft) und ändert oder
/// löscht den Eintrag dieses Tages; unten steht der Tageslog. Oben der letzte Wert groß mit der Änderung zur Messung davor, dann das Feld (mit dem letzten
/// Wert vorbelegt) mit Plus und Minus in 0,1 kg, unten die Kurve. "78,4" wird als 784 Zehntel-kg gespeichert
/// (`GewichtText`). Akku: kein Timer und kein Netz, Halten wiederholt der Button selbst.
struct GewichtBlatt: View {
    let werte: [String: Int]
    let tagWaehlbar: Bool
    let speichern: (String, Int) -> Void
    @State private var tag: String
    @State private var text: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var fokus: Bool

    /// Nur heute (Heute-Kachel).
    init(werte: [String: Int], speichern: @escaping (Int) -> Void) {
        self.init(werte: werte, tag: Datum.text(Date()), tagWaehlbar: false) { speichern($1) }
    }

    init(werte: [String: Int], tag: String, tagWaehlbar: Bool, speichern: @escaping (String, Int) -> Void) {
        self.werte = werte
        self.tagWaehlbar = tagWaehlbar
        self.speichern = speichern
        _tag = State(initialValue: tag)
        _text = State(initialValue: GewichtLogik.startFeld(werte, tag: tag))
    }

    private var zehntel: Int? { GewichtText.zehntel(text) }

    var body: some View {
        let punkte = MessLogik.punkte(werte)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let letzter = punkte.last { stand(letzter) }
                    if tagWaehlbar { tagWahl }
                    eingabe
                    if (werte[tag] ?? 0) > 0 { loeschenKnopf }
                    if punkte.count > 1 { kurve(punkte) }
                    if tagWaehlbar, !punkte.isEmpty { log }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear { if text.isEmpty { fokus = true } }
            .navigationTitle("Gewicht")
            .tastaturFertig()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        if let zehntel { speichern(tag, zehntel) }
                        dismiss()
                    }
                    .disabled(zehntel == nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func stand(_ letzter: MessPunkt) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(GewichtText.feld(letzter.zehntel)).font(.largeTitle.bold().monospacedDigit())
                Text("kg").font(.title3).foregroundStyle(.secondary)
            }
            if let a = GewichtLogik.aenderung(werte) {
                Text(GewichtText.aenderung(a.zehntel, seit: a.seit)).font(.title3.weight(.medium).monospacedDigit())
            }
            Text(Datum.anzeige(letzter.tag)).font(.subheadline).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var tagWahl: some View {
        DatePicker("Tag", selection: Binding(get: { Datum.datum(tag) }, set: { tag = Datum.text($0) }), in: ...Date(), displayedComponents: .date)
            .onChange(of: tag) { _, neu in text = GewichtLogik.startFeld(werte, tag: neu) }
    }

    private var loeschenKnopf: some View {
        Button("Eintrag vom \(Datum.anzeige(tag)) löschen", role: .destructive) {
            speichern(tag, 0)
            dismiss()
        }
        .frame(minHeight: 44)
    }

    /// Tageslog, neueste zuerst; Tippen lädt den Tag ins Feld. Die Kurve darüber zeigt den Verlauf.
    private var log: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Einträge").font(.headline).padding(.bottom, 8)
            ForEach(GewichtLogik.log(werte).prefix(30)) { p in
                Button { tag = p.tag } label: {
                    HStack {
                        Text(Datum.anzeige(p.tag)).foregroundStyle(p.tag == tag ? Color.accentColor : Color.primary)
                        Spacer()
                        Text(GewichtText.anzeige(p.zehntel)).monospacedDigit().foregroundStyle(.secondary)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(Datum.anzeige(p.tag)), \(GewichtText.anzeige(p.zehntel))")
                .accessibilityHint("Zum Ändern antippen")
            }
        }
    }

    private var eingabe: some View {
        HStack(spacing: 12) {
            knopf("minus", "Weniger", -1)
            TextField("Gewicht in kg", text: $text)
                .keyboardType(.decimalPad)
                .focused($fokus)
                .multilineTextAlignment(.center)
                .font(.title.bold().monospacedDigit())
                .frame(minHeight: 44)
                .accessibilityLabel("Gewicht in Kilogramm")
            knopf("plus", "Mehr", 1)
        }
    }

    /// 52 pt Tippfläche. `buttonRepeatBehavior`: Halten zählt weiter, ohne eigenen Timer.
    private func knopf(_ symbol: String, _ name: String, _ delta: Int) -> some View {
        Button {
            if let neu = GewichtLogik.schritt(text, delta) {
                text = neu
                Haptik.auswahl()
            }
        } label: {
            Image(systemName: symbol).font(.title2.weight(.semibold)).frame(width: 52, height: 52)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .buttonRepeatBehavior(.enabled)
        .disabled(zehntel == nil)
        .accessibilityLabel("\(name), 0,1 Kilogramm")
    }

    /// Glatte Linie = Schnitt der 7 Tage bis zum Messtag, kleine graue Punkte = die einzelnen Messungen.
    private func kurve(_ punkte: [MessPunkt]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Chart {
                ForEach(punkte) { p in
                    PointMark(x: .value("Tag", Datum.datum(p.tag)), y: .value("kg", Double(p.zehntel) / 10))
                        .symbolSize(18)
                        .foregroundStyle(.secondary)
                }
                ForEach(GewichtLogik.mittelReihe(werte)) { m in
                    LineMark(x: .value("Tag", Datum.datum(m.tag)), y: .value("Schnitt kg", m.kg))
                        .interpolationMethod(.catmullRom)
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 180)
            .accessibilityLabel("Gewicht über die Zeit, Linie ist der Schnitt der letzten 7 Tage")
            Text("Linie: Schnitt der letzten 7 Tage. Punkte: einzelne Messungen.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
