import SwiftUI
import UIKit

/// Date-Ideen nach Entwurf A "Verzeichnis": große Zahl mit Lineal, Filter-Chips, Abschnitte je Kategorie.
/// Haken per Tap, Swipe nach rechts löscht mit Undo-Leiste, "+" und Tap auf die Zeile öffnen das Blatt.
struct DatesView: View {
    let speicher = DateSpeicher.shared
    @State private var filter = DateFilter()
    @State private var blatt: DatesBlattZiel?
    @State private var undo: DatesUndo?
    @State private var gewuerfelt: DatesWuerfelEintrag?
    @State private var letzteGezogene: [String] = []
    @State private var wuerfelDreht = false
    @State private var zeigtMachenWir = false
    @State private var zeigtListe = false

    var body: some View {
        let ideen = speicher.ideen
        let fortschritt = DateLogik.fortschritt(ideen)
        let abschnitte = DatesAnsichtLogik.abschnitte(ideen, filter: filter)
        List {
            DatesKopf(erledigt: fortschritt.erledigt, gesamt: fortschritt.gesamt)
                .listRow()
            wuerfelKarte(ideen: ideen).listRow()
            filterLeiste(ortNamen: DateLogik.ortNamen(ideen))
                .listRow()
            if abschnitte.isEmpty {
                leer.listRow()
            }
            ForEach(abschnitte) { abschnitt in
                DatesAbschnittKopf(abschnitt: abschnitt).listRow()
                ForEach(abschnitt.ideen) { idee in
                    DatesZeileInhalt(
                        idee: idee,
                        beiHaken: { haken(idee) },
                        beiOeffnen: { blatt = DatesBlattZiel(idee: idee) }
                    )
                    .listRow()
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button(role: .destructive) { loeschen(idee) } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                        .tint(.red)
                        .accessibilityLabel("Idee \(idee.titel) löschen")
                    }
                }
            }
            Color.clear.frame(height: 90).listRow()
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("Date-Ideen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { zeigtListe = true } label: { Image(systemName: "list.bullet") }
                    .accessibilityLabel("Unsere Liste")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { blatt = DatesBlattZiel(idee: nil) } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Neue Idee")
            }
        }
        .tint(Color.loveaRose)
        .overlay(alignment: .bottom) {
            if let undo {
                DatesUndoAnzeige(undo: undo, beiRueckgaengig: { rueckgaengig(undo) })
                    .id(undo.beginn)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task(id: undo) {
            guard undo != nil else { return }
            try? await Task.sleep(for: .seconds(DatesUndo.dauer))
            if !Task.isCancelled { withAnimation(.easeOut(duration: 0.2)) { undo = nil } }
        }
        .sheet(item: $blatt) { ziel in
            DateIdeeBlatt(idee: ziel.idee, vorKategorie: filter.kategorie, beiGeloescht: loeschen)
        }
        .sheet(isPresented: $zeigtMachenWir) {
            if let gewuerfelt { MachenWirBlatt(text: gewuerfelt.text) }
        }
        .sheet(isPresented: $zeigtListe) { ListenBlatt() }
    }

    // MARK: - Würfel

    private func wuerfelKarte(ideen: [DateIdee]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let gewuerfelt {
                Text(gewuerfelt.text)
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Keine Idee im Kopf? Würfel eine aus eurer Liste.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Button { wuerfeln(ideen) } label: {
                    Label("Würfeln", systemImage: "die.face.5.fill")
                        .rotationEffect(.degrees(wuerfelDreht ? 360 : 0))
                }
                .buttonStyle(.bordered)
                if gewuerfelt != nil {
                    Button("Machen wir") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        zeigtMachenWir = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.loveaRose)
                }
            }
            .frame(minHeight: 44)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private func wuerfeln(_ ideen: [DateIdee]) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeInOut(duration: 0.4)) { wuerfelDreht.toggle() }
        let wuensche = WirModell.shared.zustand.liste.filter { !$0.geschafft }.map { (id: $0.id, text: $0.text) }
        guard let treffer = DatesWuerfel.pool(ideen: ideen, wuensche: wuensche, letzte: letzteGezogene).randomElement() else { return }
        gewuerfelt = treffer
        letzteGezogene = Array((letzteGezogene + [treffer.id]).suffix(5))
    }

    // MARK: - Filter

    private func filterLeiste(ortNamen: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    Button("Alle Kategorien") { filter.kategorie = nil }
                    ForEach(DateKategorie.allCases, id: \.self) { kategorie in
                        Button { filter.kategorie = kategorie } label: {
                            if filter.kategorie == kategorie {
                                Label(kategorie.titel, systemImage: "checkmark")
                            } else {
                                Text(kategorie.titel)
                            }
                        }
                    }
                } label: {
                    DatesChip(titel: filter.kategorie?.titel ?? "Kategorie", pfeil: true, aktiv: filter.kategorie != nil)
                }
                Button { filter = DatesAnsichtLogik.umschalten(filter, status: .offen) } label: {
                    DatesChip(titel: "Offen", aktiv: filter.status == .offen)
                }
                .accessibilityAddTraits(filter.status == .offen ? .isSelected : [])
                Button { filter = DatesAnsichtLogik.umschalten(filter, status: .erledigt) } label: {
                    DatesChip(titel: "Erledigt", aktiv: filter.status == .erledigt)
                }
                .accessibilityAddTraits(filter.status == .erledigt ? .isSelected : [])
                Menu {
                    Button("Alle Orte") { filter.ort = nil }
                    ForEach(ortNamen, id: \.self) { name in
                        Button { filter.ort = name } label: {
                            if filter.ort.map(DateLogik.falten) == DateLogik.falten(name) {
                                Label(name, systemImage: "checkmark")
                            } else {
                                Text(name)
                            }
                        }
                    }
                } label: {
                    DatesChip(titel: filter.ort ?? "Ort", symbol: "mappin", pfeil: true, aktiv: filter.ort != nil)
                }
                .disabled(ortNamen.isEmpty && filter.ort == nil)
            }
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 2)
    }

    private var leer: some View {
        VStack(spacing: 8) {
            Text("Keine Ideen für diesen Filter.").font(.subheadline).foregroundStyle(.secondary)
            if DatesAnsichtLogik.istGefiltert(filter) {
                Button("Filter zurücksetzen") { filter = DateFilter() }.font(.subheadline.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Aktionen

    private func haken(_ idee: DateIdee) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        speicher.abhaken(idee.id, erledigt: !idee.erledigt)
    }

    private func loeschen(_ idee: DateIdee) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        speicher.loeschen(idee.id)
        withAnimation(.easeOut(duration: 0.2)) { undo = DatesUndo(ideeID: idee.id, titel: idee.titel, beginn: Date()) }
    }

    private func rueckgaengig(_ eintrag: DatesUndo) {
        guard eintrag.istOffen(Date()) else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        speicher.rueckgaengig(eintrag.ideeID)
        withAnimation(.easeOut(duration: 0.2)) { undo = nil }
    }
}

/// Die Leiste läuft von selbst in `DatesUndo.dauer` Sekunden leer; `.id` startet sie bei jeder neuen Löschung neu.
private struct DatesUndoAnzeige: View {
    let undo: DatesUndo
    let beiRueckgaengig: () -> Void
    @State private var rest = 1.0

    var body: some View {
        DatesUndoLeiste(titel: undo.titel, rest: rest, beiRueckgaengig: beiRueckgaengig)
            .onAppear { withAnimation(.linear(duration: DatesUndo.dauer)) { rest = 0 } }
    }
}

struct DatesBlattZiel: Identifiable {
    let id = UUID()
    /// nil = neue Idee.
    let idee: DateIdee?
}

private extension View {
    /// Zeile ohne Rand, Trennlinie und Hintergrund: Haarlinien zeichnen die Zeilen selbst.
    func listRow() -> some View {
        self
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}
