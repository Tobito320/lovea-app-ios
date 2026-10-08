import SwiftUI

/// Die sechs Gefühle zur Wahl; tippt man das gesetzte noch einmal, verschwindet die Blase.
struct StimmungWahlBlatt: View {
    private let speicher = SignaleSpeicher.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let aktuell = speicher.ich.flatMap { speicher.stimmung(von: $0) }
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    ForEach(Gefuehl.allCases, id: \.self) { s in
                        Button {
                            Haptik.auswahl()
                            speicher.stimmungSetzen(s == aktuell ? nil : s)
                            dismiss()
                        } label: {
                            VStack(spacing: 6) {
                                SignaleBild { SignaleZeichnung.gesicht($0, s) }
                                    .frame(width: 56, height: 56)
                                Text(s.name)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .padding(.vertical, 10)
                            .background(s == aktuell ? Color.loveaRose.opacity(0.16) : Color(uiColor: .secondarySystemBackground),
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(s.name)
                        .accessibilityAddTraits(s == aktuell ? .isSelected : [])
                    }
                }
                .padding()
                if aktuell != nil {
                    Button("Blase wegnehmen", role: .destructive) {
                        speicher.stimmungSetzen(nil)
                        dismiss()
                    }
                    .frame(minHeight: 44)
                }
            }
            .navigationTitle("Wie geht es dir?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}

/// Ein kurzer Liebesbrief: ein ganz normaler Brief (`BriefeSpeicher`), der beim Gegenüber als Umschlag
/// auf dem Tisch liegt. Darunter der Weg in den ganzen Briefstapel.
struct LiebesbriefBlatt: View {
    private let briefe = BriefeSpeicher.shared
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    private var name: String { briefe.ich?.partner.name ?? "dem Schatz" }
    private var kurz: String? { SignaleLogik.kurz(text, hoechstens: SignaleLogik.liebesbriefMaxZeichen) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ein paar liebe Worte", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                        .onChange(of: text) { _, neu in
                            if neu.count > SignaleLogik.liebesbriefMaxZeichen { text = String(neu.prefix(SignaleLogik.liebesbriefMaxZeichen)) }
                        }
                } header: {
                    Text("Liebesbrief für \(name)")
                } footer: {
                    Text("Er liegt als Umschlag auf dem Tisch von \(name) und öffnet sich erst beim Antippen.")
                }
                Section {
                    NavigationLink("Briefstapel") { BriefeView() }
                        .frame(minHeight: 44)
                }
            }
            .navigationTitle("Liebesbrief")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Hinlegen", action: hinlegen).disabled(kurz == nil) }
            }
        }
    }

    private func hinlegen() {
        guard let kurz, briefe.schreiben(titel: SignaleLogik.liebesbriefTitel, text: kurz, frei: true) != nil else { return }
        Haptik.erfolg()
        dismiss()
    }
}

/// Der Zettel an der Wand ist die Frage des Tages der Nähe-Seite (`FrageDesTagesView`): eine Frage am
/// Tag, die Antwort der anderen Person bleibt verdeckt, bis man selbst geantwortet hat.
struct ZettelBlatt: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            FrageDesTagesView()
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
    }
}

/// Die Geschenkbox unter dem Bett: Ideen für die andere Person. Jede Idee liegt nur auf dem Gerät
/// und in der Box der Person, die sie angelegt hat, der Server gibt sie nie weiter.
struct GeschenkBoxBlatt: View {
    private let speicher = SignaleSpeicher.shared
    @Environment(\.dismiss) private var dismiss
    @State private var neu = ""
    @FocusState private var fokus: Bool

    private var name: String { speicher.ich?.partner.name ?? "dem Schatz" }

    var body: some View {
        NavigationStack {
            let ideen = speicher.geschenke
            List {
                Section {
                    HStack {
                        TextField("Geschenkidee", text: $neu)
                            .focused($fokus)
                            .submitLabel(.done)
                            .onSubmit(merken)
                        Button("Merken", action: merken)
                            .disabled(SignaleLogik.kurz(neu, hoechstens: SignaleLogik.geschenkMaxZeichen) == nil)
                    }
                } footer: {
                    Text("Nur du siehst diese Box. \(name) bekommt nie etwas davon.")
                }
                if !ideen.isEmpty {
                    Section("Ideen") {
                        ForEach(ideen) { g in
                            Button { Haptik.auswahl(); speicher.geschenkAbhaken(g) } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: g.erledigt ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(g.erledigt ? Color.loveaRose : .secondary)
                                        .accessibilityHidden(true)
                                    Text(g.text)
                                        .strikethrough(g.erledigt)
                                        .foregroundStyle(g.erledigt ? .secondary : .primary)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                }
                                .frame(minHeight: 44)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityValue(g.erledigt ? "geschenkt" : "offen")
                            .swipeActions { Button("Löschen", role: .destructive) { speicher.geschenkLoeschen(g) } }
                        }
                    }
                }
            }
            .navigationTitle("Geschenkbox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
    }

    private func merken() {
        guard speicher.geschenkMerken(neu) else { return }
        Haptik.erfolg()
        neu = ""
        fokus = true
    }
}
