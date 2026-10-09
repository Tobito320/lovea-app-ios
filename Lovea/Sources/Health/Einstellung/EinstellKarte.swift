import SwiftUI

/// "So geht's": Kurz-Anleitung, Einstell-Tipp und Fehlerquelle zu einer Übung. Reines SwiftUI,
/// ohne TextFields, damit `ImageRenderer` es zeichnen kann.
struct SoGehtsKarte: View {
    let hinweis: EinstellHinweis
    let studio: GymStudio
    @State private var offen: Bool

    init(hinweis: EinstellHinweis, studio: GymStudio, offen: Bool = false) {
        self.hinweis = hinweis
        self.studio = studio
        _offen = State(initialValue: offen)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { withAnimation(.snappy) { offen.toggle() } } label: {
                HStack {
                    Label("So geht's", systemImage: "questionmark.circle.fill").font(.headline)
                    Spacer(minLength: 0)
                    Image(systemName: offen ? "chevron.up" : "chevron.down").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            if offen {
                block("Ablauf", hinweis.anleitung)
                block("Einstellen", hinweis.einstellung)
                block("Typischer Fehler", hinweis.fehler)
                ForEach(hinweis.tipps(fuer: studio), id: \.text) { t in
                    block(studio.name, t.text)
                    if t.unsicher { unsicherZeile }
                }
                if hinweis.unsicher { unsicherZeile }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthKarte(HabitFarbe.himmel.farbe)
    }

    private func block(_ titel: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titel).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var unsicherZeile: some View {
        Label("Unsicher, selbst prüfen", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(HabitFarbe.amber.farbe)
    }
}

/// "Meine Einstellung": was beim letzten Mal an diesem Gerät eingestellt war. Tippen ändert.
struct MeineEinstellungKarte: View {
    let werte: EinstellWerte?
    let studio: GymStudio
    var aendern: () -> Void = {}

    var body: some View {
        Button(action: aendern) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Meine Einstellung", systemImage: "slider.horizontal.3").font(.headline)
                    Spacer(minLength: 0)
                    Text(werte == nil ? "Eintragen" : "Ändern").font(.subheadline.weight(.medium)).foregroundStyle(HabitFarbe.himmel.farbe)
                }
                Text(studio.name).font(.caption).foregroundStyle(.secondary)
                if let w = werte, !w.istLeer {
                    HStack(spacing: 8) {
                        chip("Bank", w.bankstufe)
                        chip("Sitz", w.sitzhoehe)
                        chip("Polster", w.polster)
                    }
                    if !w.notiz.isEmpty { Text(w.notiz).font(.subheadline).fixedSize(horizontal: false, vertical: true) }
                } else {
                    Text("Noch nichts gespeichert. Stell das Gerät ein und trag es hier ein, beim nächsten Mal steht es da.")
                        .font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .healthKarte(HabitFarbe.mint.farbe)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func chip(_ titel: String, _ wert: Int?) -> some View {
        if let wert {
            HStack(spacing: 4) {
                Text(titel).font(.caption).foregroundStyle(.secondary)
                Text("\(wert)").font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(HabitFarbe.mint.farbe.opacity(0.18)))
        }
    }
}
