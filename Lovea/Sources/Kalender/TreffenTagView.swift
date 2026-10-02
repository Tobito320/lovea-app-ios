import SwiftUI

/// Treffen-Tag als dünne Hülle um zwei Ansichten: lesen (`TreffenLesenInhalt`, Standard) und bearbeiten
/// (`TreffenBearbeitenInhalt`, Menü „Bearbeiten"). Gesendet wird im Bearbeiten-Modus erst mit „Fertig":
/// `treffen.setzen` für Titel und von bis, die Punkte über `TreffenPunktSender`. Die alten Notizen
/// stehen weiter im Log, werden aber nicht mehr angezeigt.
struct TreffenTagView: View {
    let datum: String
    let kalender = KalenderModell.shared
    let geheim = TreffenGeheimModell.shared
    @Environment(\.dismiss) private var dismiss

    @State private var bearbeiten = false
    @State private var treffen = TreffenBearbeitung(titel: "", von: nil, bis: nil)
    /// Stand beim Öffnen des Bearbeiten-Modus, siehe `TreffenBearbeitung.op`.
    @State private var basis = TreffenBearbeitung(titel: "", von: nil, bis: nil)
    @State private var punkte: [PunktBearbeitung] = []
    @State private var ursprung: [PunktBearbeitung] = []
    @State private var offen: String?
    @State private var neueAufgabe = ""
    @State private var zeigtExport = false
    @State private var fragtAbsage = false

    private var ich: Person { Raum.shared.ich ?? .ahmed }
    private var eintrag: KalenderModell.TreffenEintrag? { kalender.zustand.treffenText[datum] }
    private var checkliste: [KalenderModell.ChecklistEintrag] { kalender.zustand.checklisten[datum] ?? [] }
    private var gespeichert: Treffen {
        kalender.zustand.daten.treffen.last { $0.datum == datum } ?? Treffen(datum: datum, uhrzeit: nil, wasMachenWir: nil, bis: nil)
    }

    var body: some View {
        let jetzt = Date()
        let alle = treffenPunkte(datum: datum, ich: ich, jetzt: jetzt)
        let zeit = TreffenLogik.zeitraum(treffen: gespeichert, punkte: alle)
        ScrollView {
            if bearbeiten {
                TreffenBearbeitenInhalt(
                    datum: datum, partner: ich.partner, jetzt: jetzt, treffen: $treffen, punkte: $punkte, offen: $offen,
                    checkliste: checkliste, neueAufgabe: $neueAufgabe,
                    abhaken: abhaken, aufgabeLoeschen: aufgabeLoeschen, aufgabeHinzufuegen: aufgabeHinzufuegen,
                    jetztFreigeben: { TreffenPunktSender.jetztFreigeben(id: $0) }
                )
                .padding(.top, 8)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            } else {
                TreffenLesenInhalt(
                    datum: datum, titel: gespeichert.wasMachenWir ?? "", von: zeit.von, bis: zeit.bis,
                    punkte: alle, ich: ich, jetzt: jetzt, vorherige: eintrag?.vorherige,
                    checkliste: checkliste, abhaken: abhaken
                )
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(bearbeiten ? "Bearbeiten" : "")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(bearbeiten)
        .toolbar {
            if bearbeiten {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { bearbeiten = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig", action: fertig)
                        .fontWeight(.semibold)
                }
            } else {
                ToolbarItem(placement: .primaryAction) { mehr }
            }
        }
        .sheet(isPresented: $zeigtExport) { exportBlatt }
        .confirmationDialog("Treffen absagen?", isPresented: $fragtAbsage, titleVisibility: .visible) {
            Button("Treffen absagen", role: .destructive, action: absagen)
        } message: {
            Text("Das Herz verschwindet für euch beide aus dem Kalender.")
        }
    }

    private var mehr: some View {
        Menu {
            Button("Bearbeiten", systemImage: "pencil", action: beginneBearbeiten)
            Button("Zum iPhone-Kalender", systemImage: "calendar.badge.plus") { zeigtExport = true }
            if eintrag != nil {
                Button("Treffen absagen", systemImage: "heart.slash", role: .destructive) { fragtAbsage = true }
            }
        } label: {
            Label("Mehr", systemImage: "ellipsis.circle")
                .frame(minWidth: 44, minHeight: 44)
        }
    }

    private var exportBlatt: some View {
        let z = TreffenLogik.zeitraum(treffen: gespeichert, punkte: treffenPunkte(datum: datum, ich: ich, jetzt: Date()))
        let start = IPhoneKalenderDatum.kombiniert(datum, z.von)
        let ende = TreffenAnsichtWerte.exportEnde(start: start, bis: z.bis.map { IPhoneKalenderDatum.kombiniert(datum, $0) })
        let titel = gespeichert.wasMachenWir ?? ""
        return IPhoneKalenderExportBlatt(titel: titel.isEmpty ? "Treffen" : titel, start: start, ende: ende)
    }

    // MARK: - Bearbeiten

    private func beginneBearbeiten() {
        let jetzt = Date()
        let t = gespeichert
        treffen = TreffenBearbeitung(titel: t.wasMachenWir ?? "", von: t.uhrzeit, bis: t.bis)
        basis = treffen
        punkte = treffenPunkte(datum: datum, ich: ich, jetzt: jetzt).map {
            PunktBearbeitung($0, ansicht: TreffenLogik.ansicht($0, ich: ich, jetzt: jetzt), geheim: geheim.punkte[$0.id])
        }
        ursprung = punkte
        offen = nil
        bearbeiten = true
    }

    private func fertig() {
        if let d = treffen.op(datum: datum, seit: basis) { Raum.shared.senden("treffen.setzen", d) }
        let aenderung = PunktAenderung.berechnen(ursprung: ursprung, jetzt: punkte)
        for p in aenderung.speichern { TreffenPunktSender.speichern(p.entwurf(datum: datum)) }
        for id in aenderung.loeschen { TreffenPunktSender.loeschen(datum: datum, id: id) }
        Haptik.erfolg()
        bearbeiten = false
    }

    private func absagen() {
        Raum.shared.senden("treffen.loeschen", ["datum": datum])
        Haptik.leicht()
        dismiss()
    }

    // MARK: - Checkliste

    private func abhaken(_ aufgabe: KalenderModell.ChecklistEintrag) {
        if !aufgabe.erledigt { Haptik.erfolg() }
        Raum.shared.senden("checkliste.setzen", CheckOp(datum: datum, id: aufgabe.id, text: aufgabe.text, erledigt: !aufgabe.erledigt))
    }

    private func aufgabeLoeschen(_ aufgabe: KalenderModell.ChecklistEintrag) {
        Raum.shared.senden("checkliste.loeschen", ["datum": datum, "id": aufgabe.id])
    }

    private func aufgabeHinzufuegen() {
        let text = neueAufgabe.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        Raum.shared.senden("checkliste.setzen", CheckOp(datum: datum, id: UUID().uuidString, text: text, erledigt: false))
        Haptik.leicht()
        neueAufgabe = ""
    }
}

private struct CheckOp: Codable { var datum: String; var id: String; var text: String; var erledigt: Bool }
