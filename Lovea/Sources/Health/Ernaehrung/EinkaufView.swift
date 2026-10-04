import SwiftUI
import TipKit

// Einkaufsliste wie YAZIO Pro, aber gemeinsam für Ahmed und Annika. Übersicht der Listen, darin
// Einträge mit rundem Abhaken, Eingabefeld oben, Wischen löscht, Tippen ändert Text/Menge.

/// Übersicht der Einkaufslisten. Wird in einen bestehenden `NavigationStack` gepusht.
struct EinkaufView: View {
    @State private var neueListeOffen = false
    @State private var neueListeName = ""
    @State private var umbenennen: EinkaufListe?
    @State private var umbenennenName = ""
    @State private var loeschen: EinkaufListe?

    private var modell: EinkaufModell { EinkaufModell.shared }

    var body: some View {
        List {
            ForEach(modell.listen) { liste in
                NavigationLink(value: liste) {
                    Text(liste.name).fontDesign(.rounded)
                }
                .swipeActions {
                    Button("Löschen", systemImage: "trash", role: .destructive) { loeschen = liste }
                    Button("Umbenennen", systemImage: "pencil") {
                        umbenennenName = liste.name
                        umbenennen = liste
                    }
                    .tint(.blue)
                }
            }
        }
        .navigationTitle("Einkaufslisten")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: EinkaufListe.self) { EinkaufListeView(liste: $0) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Neue Liste", systemImage: "plus") { neueListeOffen = true }
            }
        }
        .task { modell.standardlisteSicherstellen() }
        .alert("Neue Liste", isPresented: $neueListeOffen) {
            TextField("Name", text: $neueListeName)
            Button("Abbrechen", role: .cancel) { neueListeName = "" }
            Button("Anlegen") {
                let name = neueListeName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { modell.listeAnlegen(name) }
                neueListeName = ""
            }
        }
        .alert("Liste umbenennen", isPresented: Binding(get: { umbenennen != nil }, set: { if !$0 { umbenennen = nil } })) {
            TextField("Name", text: $umbenennenName)
            Button("Abbrechen", role: .cancel) {}
            Button("Sichern") {
                guard let l = umbenennen else { return }
                let name = umbenennenName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { modell.listeUmbenennen(l, name: name) }
            }
        }
        .confirmationDialog("Liste löschen?", isPresented: Binding(get: { loeschen != nil }, set: { if !$0 { loeschen = nil } }),
                            titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                if let l = loeschen { modell.listeLoeschen(l) }
                loeschen = nil
            }
        }
    }
}

/// Eine geöffnete Liste: Eingabefeld oben, Einträge mit rundem Abhaken.
struct EinkaufListeView: View {
    let liste: EinkaufListe

    @Environment(\.dismiss) private var dismiss
    @State private var neuerText = ""
    @FocusState private var eingabeFokus: Bool
    @State private var bearbeite: EinkaufEintrag?
    @State private var umbenennenOffen = false
    @State private var umbenennenName = ""
    @State private var loeschenFragen = false

    private var modell: EinkaufModell { EinkaufModell.shared }
    private var eintraege: [EinkaufEintrag] { modell.eintraege(liste.id) }

    var body: some View {
        List {
            Section {
                TextField("Hinzufügen", text: $neuerText)
                    .fontDesign(.rounded)
                    .focused($eingabeFokus)
                    .submitLabel(.done)
                    .onSubmit { hinzufuegen() }
            }
            ForEach(eintraege) { e in
                eintragZeile(e)
                    .swipeActions {
                        Button("Löschen", systemImage: "trash", role: .destructive) { modell.eintragLoeschen(e) }
                    }
            }
        }
        .navigationTitle(liste.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Erledigte löschen", systemImage: "checkmark.circle") { modell.erledigteLoeschen(liste.id) }
                    Button("Liste umbenennen", systemImage: "pencil") {
                        umbenennenName = liste.name
                        umbenennenOffen = true
                    }
                    Button("Liste löschen", systemImage: "trash", role: .destructive) { loeschenFragen = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .popoverTip(EinkaufListeMehrTip())
            }
        }
        .sheet(item: $bearbeite) { e in EinkaufEintragEditor(eintrag: e) }
        .alert("Liste umbenennen", isPresented: $umbenennenOffen) {
            TextField("Name", text: $umbenennenName)
            Button("Abbrechen", role: .cancel) {}
            Button("Sichern") {
                let name = umbenennenName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { modell.listeUmbenennen(liste, name: name) }
            }
        }
        .confirmationDialog("Liste löschen?", isPresented: $loeschenFragen, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                modell.listeLoeschen(liste)
                dismiss()
            }
        }
    }

    private func eintragZeile(_ e: EinkaufEintrag) -> some View {
        HStack(spacing: 12) {
            Button {
                modell.erledigtSetzen(e, !e.erledigt)
                Haptik.erfolg()
            } label: {
                Image(systemName: e.erledigt ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(e.erledigt ? ErnaehrungStil.akzent : .secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(e.text)
                    .fontDesign(.rounded)
                    .strikethrough(e.erledigt)
                    .foregroundStyle(e.erledigt ? .secondary : .primary)
                if let von = modell.erstelltVon(e.id), von != modell.ich {
                    Text(von.name).font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if let menge = e.menge, !menge.isEmpty {
                Text(menge).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { bearbeite = e }
    }

    private func hinzufuegen() {
        let t = neuerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        modell.hinzufuegen(t, an: liste.id)
        neuerText = ""
        eingabeFokus = true
    }
}

/// Text und Menge eines Eintrags ändern.
private struct EinkaufEintragEditor: View {
    let eintrag: EinkaufEintrag

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var menge: String

    init(eintrag: EinkaufEintrag) {
        self.eintrag = eintrag
        _text = State(initialValue: eintrag.text)
        _menge = State(initialValue: eintrag.menge ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Text", text: $text)
                TextField("Menge", text: $menge)
            }
            .navigationTitle("Eintrag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { sichern() }
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func sichern() {
        var neu = eintrag
        neu.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let m = menge.trimmingCharacters(in: .whitespacesAndNewlines)
        neu.menge = m.isEmpty ? nil : m
        EinkaufModell.shared.aendern(neu)
        dismiss()
    }
}

/// Liste wählen, um Zutaten (etwa eines Rezepts) draufzulegen. Genutzt vom `RezeptEditor`.
struct EinkaufListeWahlBlatt: View {
    let zutaten: [Zutat]
    var fertig: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    private var modell: EinkaufModell { EinkaufModell.shared }

    var body: some View {
        NavigationStack {
            List(modell.listen) { liste in
                Button(liste.name) {
                    modell.zutatenHinzufuegen(zutaten, an: liste.id)
                    Haptik.erfolg()
                    dismiss()
                    fertig()
                }
                .foregroundStyle(.primary)
            }
            .navigationTitle("Liste wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
            .task { modell.standardlisteSicherstellen() }
        }
        .presentationDetents([.medium])
    }
}
