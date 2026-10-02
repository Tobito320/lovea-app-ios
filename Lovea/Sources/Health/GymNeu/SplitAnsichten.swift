import SwiftUI

// Split-Bibliothek, Vorschau und geführtes Erstellen (Entwurf `Lovea-bilder/gym-entwurf.html`, Liste A).
// Wählen schreibt den Plan über `planSichern` (`gym.plan`), kein neuer Op.

/// Kapsel für Filter, Tage und Wochentage: gewählt = gefüllt.
struct GymChip: View {
    let text: String
    var an = false

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .foregroundStyle(an ? Color(uiColor: .systemBackground) : Color.secondary)
            .background(an ? Color.primary : Color(uiColor: .tertiarySystemFill), in: Capsule())
            .frame(minHeight: 44)
            .contentShape(.rect)
    }
}

/// Sieben kurze Striche Mo bis So: an = Trainingstag.
struct SplitWochenbild: View {
    let tage: [Bool]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(tage.enumerated()), id: \.offset) { _, an in
                Capsule().fill(an ? Color.primary : Color(uiColor: .tertiarySystemFill)).frame(height: 4)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Zeile mit Titel, Unterzeile und Pfeil.
struct GymPfeilZeile<Zusatz: View>: View {
    let titel: String
    let unter: String
    @ViewBuilder var zusatz: Zusatz

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(titel).font(.body.weight(.semibold)).foregroundStyle(Color.primary)
                Text(unter).font(.footnote).foregroundStyle(.secondary)
                zusatz
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .frame(minHeight: 52)
        .padding(.vertical, 4)
        .contentShape(.rect)
    }
}

extension GymPfeilZeile where Zusatz == EmptyView {
    init(titel: String, unter: String) {
        self.init(titel: titel, unter: unter) { EmptyView() }
    }
}

/// Reiner Inhalt der Bibliothek (Render-Tafel).
struct SplitBibliothekInhalt: View {
    let person: Person
    let splits: [SplitVorlage]
    let planLeer: Bool
    var filter: Int? = nil
    var filtern: (Int?) -> Void = { _ in }
    var gefuehrt: () -> Void = {}
    var selbst: () -> Void = {}
    var waehlen: (SplitVorlage) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: gefuehrt) { GymPfeilZeile(titel: "Geführt erstellen", unter: "Drei Fragen, dann ein Vorschlag") }.buttonStyle(.plain)
            Divider()
            Button(action: selbst) {
                GymPfeilZeile(titel: planLeer ? "Leer anfangen" : "Meinen Plan anpassen", unter: "Tage und Übungen selbst anlegen")
            }
            .buttonStyle(.plain)
            Text("FERTIGE SPLITS FÜR \(person.name.uppercased())").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 22)
            chips
            liste
        }
    }

    private var chips: some View {
        HStack(spacing: 6) {
            Button { filtern(nil) } label: { GymChip(text: "Alle", an: filter == nil) }.buttonStyle(.plain)
            ForEach(SplitLogik.tageWahl, id: \.self) { n in
                Button { filtern(n) } label: { GymChip(text: "\(n)", an: filter == n) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(n) Tage")
                    .accessibilityAddTraits(filter == n ? .isSelected : [])
            }
            Text("Tage").font(.footnote).foregroundStyle(.secondary).padding(.leading, 4)
        }
    }

    @ViewBuilder
    private var liste: some View {
        let treffer = splits.filter { filter == nil || $0.tage == filter }
        if treffer.isEmpty {
            Text("Kein Split mit so vielen Tagen.").font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 14)
        }
        ForEach(Array(treffer.enumerated()), id: \.element.id) { i, v in
            if i > 0 { Divider() }
            Button { waehlen(v) } label: {
                GymPfeilZeile(titel: v.name, unter: SplitLogik.unterzeile(v)) {
                    SplitWochenbild(tage: SplitLogik.wochenbild(v)).frame(width: 150).padding(.top, 6)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

private enum SplitZiel: Hashable {
    case gefuehrt, editor
    case vorschau(String)
}

struct SplitBibliothekView: View {
    let person: Person
    /// Nach dem Übernehmen: zurück zur Gym-Seite.
    var fertig: () -> Void = {}

    @State private var filter: Int?
    @State private var ziel: SplitZiel?

    var body: some View {
        ScrollView {
            SplitBibliothekInhalt(
                person: person, splits: SplitLogik.fuer(person), planLeer: TrainingModell.shared.plan(person).tage.isEmpty, filter: filter,
                filtern: { n in
                    Haptik.auswahl()
                    withAnimation(Feder.schnell) { filter = n }
                },
                gefuehrt: { ziel = .gefuehrt }, selbst: { ziel = .editor }, waehlen: { ziel = .vorschau($0.id) }
            )
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .navigationTitle("Splits")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $ziel) { seite($0) }
    }

    @ViewBuilder
    private func seite(_ z: SplitZiel) -> some View {
        switch z {
        case .gefuehrt: SplitGefuehrtView(person: person, fertig: fertig)
        case .editor: SplitEditorView(start: nil)
        case .vorschau(let id):
            if let v = SplitKatalog.alle.first(where: { $0.id == id }) { SplitVorschauView(vorlage: v, fertig: fertig) }
        }
    }
}

/// Reiner Inhalt der Vorschau (Render-Tafel): Wochenbild, dann jede Einheit mit ihren Übungen.
struct SplitVorschauInhalt: View {
    let vorlage: SplitVorlage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(SplitLogik.unterzeile(vorlage)).font(.subheadline).foregroundStyle(.secondary)
            SplitWochenbild(tage: SplitLogik.wochenbild(vorlage)).padding(.top, 12)
            HStack(spacing: 4) {
                ForEach(HabitLogik.wochentagKuerzel, id: \.self) { Text($0).frame(maxWidth: .infinity) }
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
            ForEach(Array(vorlage.einheiten.enumerated()), id: \.offset) { _, e in einheit(e) }
        }
    }

    private func einheit(_ e: SplitVorlage.Einheit) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(e.name).font(.title3.bold())
                Spacer()
                Text(TrainingLogik.wochentageText(e.wochentage)).font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 4)
            ForEach(Array(e.uebungen.enumerated()), id: \.offset) { i, z in
                if i > 0 { Divider() }
                HStack {
                    Text(UebungsKatalog.nachId[z.uebung]?.name ?? "Übung").font(.body)
                    Spacer(minLength: 12)
                    Text(SplitLogik.wdhText(z)).font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                }
                .frame(minHeight: 44)
            }
        }
    }
}

struct SplitVorschauView: View {
    let vorlage: SplitVorlage
    var fertig: () -> Void = {}

    @State private var frage = false
    private var modell: TrainingModell { TrainingModell.shared }
    private var ich: Person { Raum.shared.ich ?? .ahmed }

    var body: some View {
        ScrollView {
            SplitVorschauInhalt(vorlage: vorlage)
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
        }
        .navigationTitle(vorlage.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Übernehmen") {
                    if modell.plan(ich).tage.isEmpty { uebernehmen() } else { frage = true }
                }
                .fontWeight(.semibold)
            }
        }
        .confirmationDialog("Dein jetziger Plan wird ersetzt.", isPresented: $frage, titleVisibility: .visible) {
            Button("Plan ersetzen", role: .destructive) { uebernehmen() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Deine bisherigen Trainingstage und Gewichte im Plan gehen verloren. Der Verlauf bleibt.")
        }
    }

    private func uebernehmen() {
        modell.planSichern(SplitLogik.alsPlan(vorlage))
        Haptik.erfolg()
        fertig()
    }
}

/// Drei Fragen, dann ein Vorschlag aus der Bibliothek.
struct SplitGefuehrtView: View {
    let person: Person
    var fertig: () -> Void = {}

    @State private var schritt = 0
    @State private var tage = 4
    @State private var ziel = "muskeln"
    @State private var geraet = "studio"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                fortschritt
                inhalt
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .navigationTitle(schritt < 3 ? "Geführt erstellen" : "Dein Vorschlag")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if schritt > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zurück") { withAnimation(Feder.schnell) { schritt -= 1 } }
                }
            }
        }
    }

    private var fortschritt: some View {
        HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { i in
                Capsule().fill(i <= schritt ? Color.primary : Color(uiColor: .tertiarySystemFill)).frame(height: 3)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 20)
        .accessibilityLabel("Schritt \(schritt + 1) von 4")
    }

    @ViewBuilder
    private var inhalt: some View {
        switch schritt {
        case 0:
            frage("Wie oft pro Woche?", SplitLogik.tageWahl.map { "\($0) Tage" }, gewaehlt: SplitLogik.tageWahl.firstIndex(of: tage)) { tage = SplitLogik.tageWahl[$0] }
        case 1:
            frage("Was ist dein Ziel?", SplitLogik.ziele.map { $0.text }, gewaehlt: SplitLogik.ziele.firstIndex { $0.id == ziel }) { ziel = SplitLogik.ziele[$0].id }
        case 2:
            frage("Was steht dir zur Verfügung?", SplitLogik.geraete.map { $0.text }, gewaehlt: SplitLogik.geraete.firstIndex { $0.id == geraet }) { geraet = SplitLogik.geraete[$0].id }
        default:
            vorschlag
        }
    }

    private func frage(_ titel: String, _ texte: [String], gewaehlt: Int?, _ setzen: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(titel).font(.title2.bold()).padding(.bottom, 10)
            ForEach(Array(texte.enumerated()), id: \.offset) { i, text in
                if i > 0 { Divider() }
                Button {
                    setzen(i)
                    Haptik.auswahl()
                    withAnimation(Feder.schnell) { schritt += 1 }
                } label: {
                    frageZeile(text, an: i == gewaehlt)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(i == gewaehlt ? .isSelected : [])
            }
        }
    }

    private func frageZeile(_ text: String, an: Bool) -> some View {
        HStack {
            Text(text).font(.body.weight(.semibold)).foregroundStyle(Color.primary)
            Spacer()
            Image(systemName: an ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(an ? Color.primary : Color.secondary)
        }
        .frame(minHeight: 52)
        .contentShape(.rect)
    }

    @ViewBuilder
    private var vorschlag: some View {
        if let v = SplitLogik.vorschlag(person, tage: tage, ziel: ziel, geraet: geraet) {
            Text("Passt zu deinen Antworten").font(.footnote).foregroundStyle(.secondary)
            Text(v.name).font(.largeTitle.bold()).padding(.bottom, 6)
            SplitVorschauInhalt(vorlage: v)
            NavigationLink {
                SplitVorschauView(vorlage: v, fertig: fertig)
            } label: {
                Text("Ansehen und übernehmen")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 40)
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .background(Color.primary, in: Capsule())
            }
            .buttonStyle(.federnd)
            .padding(.top, 24)
        } else {
            Text("Dafür gibt es noch keinen fertigen Split. Leg ihn selbst an.").font(.subheadline).foregroundStyle(.secondary)
        }
    }
}
