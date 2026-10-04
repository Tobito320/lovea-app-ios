import SwiftUI

/// Blatt für eine Idee: Titel, Kategorie, Notiz, Erledigt, Löschen. Neue Idee: `idee == nil`.
/// Ort (Suche, Karte) und Link-Chips ändert das Blatt erst mit "Fertig".
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
    @State private var ort: PunktOrt?
    @State private var links: [DateLink]
    @FocusState private var titelFokus: Bool

    init(idee: DateIdee?, vorKategorie: DateKategorie? = nil, beiGeloescht: @escaping (DateIdee) -> Void) {
        self.idee = idee
        self.vorKategorie = vorKategorie
        self.beiGeloescht = beiGeloescht
        _titel = State(initialValue: idee?.titel ?? "")
        _kategorie = State(initialValue: idee?.kategorie ?? vorKategorie ?? .essen)
        _erledigt = State(initialValue: idee?.erledigt ?? false)
        _notiz = State(initialValue: idee?.notiz ?? "")
        _ort = State(initialValue: idee?.ort)
        _links = State(initialValue: idee?.links ?? [])
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
                    DateOrtAbschnitt(ort: $ort)
                    DateLinkAbschnitt(links: $links)
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

    private func speichern() {
        guard !titelText.isEmpty else { return }
        DateIdeeBearbeitung.speichern(
            .init(titel: titel, kategorie: kategorie, erledigt: erledigt, notiz: notiz, ort: ort, links: links),
            idee: idee, in: speicher
        )
        dismiss()
    }
}
