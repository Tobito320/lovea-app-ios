import SwiftUI

/// Der Bildschirm für die Render-Tafel: gleiche Bausteine wie `DatesView`, aber ohne List, Swipe, Menu
/// und TextField (ImageRenderer zeichnet die nicht).
struct DatesRenderInhalt: View {
    let ideen: [DateIdee]
    var filter = DateFilter()
    var undo: DatesUndo?
    var undoRest = 0.6
    var hoehe: CGFloat = 780

    var body: some View {
        let fortschritt = DateLogik.fortschritt(ideen)
        let abschnitte = DatesAnsichtLogik.abschnitte(ideen, filter: filter)
        VStack(spacing: 0) {
            navigation
            DatesKopf(erledigt: fortschritt.erledigt, gesamt: fortschritt.gesamt)
            chips
            VStack(spacing: 0) {
                ForEach(abschnitte) { abschnitt in
                    DatesAbschnittKopf(abschnitt: abschnitt)
                    ForEach(abschnitt.ideen) { DatesZeileInhalt(idee: $0) }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(width: 393, height: hoehe, alignment: .top)
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .bottom) {
            if let undo { DatesUndoLeiste(titel: undo.titel, rest: undoRest).padding(.bottom, 26) }
        }
        .clipped()
    }

    private var navigation: some View {
        HStack {
            HStack(spacing: 2) {
                Image(systemName: "chevron.left").font(.body.weight(.semibold))
                Text("Wir")
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.loveaRose)
            Spacer()
            Text("Date-Ideen").font(.body.weight(.bold))
            Spacer()
            Image(systemName: "plus").font(.body.weight(.semibold)).foregroundStyle(Color.loveaRose)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    private var chips: some View {
        HStack(spacing: 6) {
            DatesChip(titel: filter.kategorie?.titel ?? "Kategorie", pfeil: true, aktiv: filter.kategorie != nil)
            DatesChip(titel: "Offen", aktiv: filter.status == .offen)
            DatesChip(titel: "Erledigt", aktiv: filter.status == .erledigt)
            DatesChip(titel: filter.ort ?? "Ort", symbol: "mappin", pfeil: true, aktiv: filter.ort != nil)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 2)
    }
}
