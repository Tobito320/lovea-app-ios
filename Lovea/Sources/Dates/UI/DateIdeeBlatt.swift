import SwiftUI

/// Blatt für eine Idee: Titel, Kategorie, Notiz, Erledigt, Löschen. Neue Idee: `idee == nil`.
/// Ort und Link sind nur Platzhalterzeilen, die baut Punkt D4.
struct DateIdeeBlatt: View {
    let idee: DateIdee?
    var vorKategorie: DateKategorie?
    let beiGeloescht: (DateIdee) -> Void

    let speicher = DateSpeicher.shared
    @Environment(\.dismiss) private var dismiss
    @State private var titel: String
    @State private var kategorie: DateKategorie
    @State private var erledigt: Bool
    @State private var notiz: String
    @FocusState private var titelFokus: Bool

    init(idee: DateIdee?, vorKategorie: DateKategorie? = nil, beiGeloescht: @escaping (DateIdee) -> Void) {
        self.idee = idee
        self.vorKategorie = vorKategorie
        self.beiGeloescht = beiGeloescht
        _titel = State(initialValue: idee?.titel ?? "")
        _kategorie = State(initialValue: idee?.kategorie ?? vorKategorie ?? .essen)
        _erledigt = State(initialValue: idee?.erledigt ?? false)
        _notiz = State(initialValue: idee?.notiz ?? "")
    }

    private var titelText: String { titel.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TextField("Titel", text: $titel)
                        .font(.title.weight(.bold))
                        .focused($titelFokus)
                        .submitLabel(.done)
                    kategorien
                    ortZeile
                    linkZeile
                    VStack(spacing: 0) {
                        DatesHaarlinie()
                        Toggle("Erledigt", isOn: $erledigt)
                            .font(.body.weight(.semibold))
                            .frame(minHeight: 52)
                            .tint(Color.loveaRose)
                        DatesHaarlinie()
                        HStack(alignment: .firstTextBaseline) {
                            Text("Notiz").font(.body.weight(.semibold))
                            TextField("Hinzufügen", text: $notiz, axis: .vertical)
                                .multilineTextAlignment(.trailing)
                                .lineLimit(1...6)
                        }
                        .frame(minHeight: 52)
                        DatesHaarlinie()
                    }
                    if let idee {
                        Button(role: .destructive) {
                            beiGeloescht(idee)
                            dismiss()
                        } label: {
                            Label("Idee löschen", systemImage: "trash").font(.body.weight(.semibold))
                        }
                        .foregroundStyle(.red)
                        .frame(minHeight: 44)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(uiColor: .secondarySystemBackground))
            .navigationTitle("Idee")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { speichern() }.fontWeight(.semibold).disabled(titelText.isEmpty)
                }
            }
        }
        .tint(Color.loveaRose)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { if idee == nil { titelFokus = true } }
    }

    private var kategorien: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DateKategorie.allCases, id: \.self) { art in
                    Button { kategorie = art } label: { DatesChip(titel: art.titel, aktiv: kategorie == art) }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(kategorie == art ? .isSelected : [])
                }
            }
        }
    }

    private var ortZeile: some View {
        VStack(alignment: .leading, spacing: 8) {
            abschnittsTitel("Ort")
            HStack {
                if let ort = idee?.ort {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(ort.name).font(.body.weight(.semibold))
                        if let adresse = ort.adresse { Text(adresse).font(.subheadline).foregroundStyle(.secondary) }
                    }
                }
                Spacer(minLength: 8)
                platzhalter("Ort suchen", symbol: "magnifyingglass")
            }
        }
    }

    private var linkZeile: some View {
        VStack(alignment: .leading, spacing: 8) {
            abschnittsTitel("Links")
            platzhalter("Link", symbol: "plus")
        }
    }

    private func abschnittsTitel(_ text: String) -> some View {
        Text(text.uppercased()).font(.caption.weight(.bold)).tracking(1).foregroundStyle(DatesStil.grau)
    }

    /// Ohne Funktion bis D4.
    private func platzhalter(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.loveaRose.opacity(0.6))
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.loveaRose.opacity(0.4), lineWidth: 1))
            .accessibilityHint("Folgt in einer späteren Version")
    }

    private func speichern() {
        guard !titelText.isEmpty else { return }
        let text = notiz.trimmingCharacters(in: .whitespacesAndNewlines)
        let notizWert: String? = text.isEmpty ? nil : text
        if let idee {
            if titelText != idee.titel || kategorie != idee.kategorie || notizWert != idee.notiz {
                speicher.aendern(idee.id) {
                    $0.titel = titelText
                    $0.kategorie = kategorie
                    $0.notiz = notizWert
                }
            }
            speicher.abhaken(idee.id, erledigt: erledigt)
        } else if let neu = speicher.anlegen(titel: titelText, kategorie: kategorie, notiz: notizWert), erledigt {
            speicher.abhaken(neu.id, erledigt: true)
        }
        dismiss()
    }
}
